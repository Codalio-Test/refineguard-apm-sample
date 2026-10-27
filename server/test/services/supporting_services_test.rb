# frozen_string_literal: true

require "test_helper"

# The remaining RefineGuard services, exercised directly.
class SupportingServicesTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Support Org", slug: "support-org")
    @unit = PlantUnit.create!(organization: @org, unit_code: "CDU-1", unit_name: "CDU 1",
                              rate_percent: 92.0, exposure_usd_per_day: 418_000.0,
                              derate_recommendation: "Reduce charge rate by 8%.")
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Pump",
                           plant_unit: @unit, health_state: "Alarm", health_index: 30.0,
                           health_index_delta: 20.0, data_completeness_pct: 99.0,
                           monitored: true, last_sample_at: 5.minutes.ago)
  end

  def incident(attrs = {})
    DiagnosticIncident.create!({ organization: @org, asset: @asset, status: "Active",
                                 health_state: "Alarm", incident_code: "INC-1",
                                 detected_at: 3.days.ago }.merge(attrs))
  end

  def advisory(inc, attrs = {})
    PrescriptiveAdvisory.create!({ organization: @org, diagnostic_incident: inc,
                                   status: "Ready for Dispatch", due_within_days: 20,
                                   urgency: "Routine" }.merge(attrs))
  end

  # ---- PrognosticsService --------------------------------------------------

  test "the regime recalculates the RUL without resetting accumulated damage" do
    inc = incident(rul_days_estimate: 30.0, pf_interval_days: 21.0, finding_confidence: 0.2)
    result = Refineguard::PrognosticsService.recalculate(inc)

    assert_equal "light", result[:regime]
    assert_equal 99.0, result[:regime_confidence_pct]
    # 30 d / rate 1.0 * (1 - 0.7 accumulated damage * 0.15) = 26.9 d.
    assert_equal 26.9, result[:rul_days_estimate]
    assert_in_delta 0.7, result[:damage_preserved], 0.001
    assert_equal false, result[:escalated]
    assert_operator result[:pf_interval_days], :>, 0
  end

  test "a forced regime is honoured and a short RUL escalates the advisory" do
    inc = incident(rul_days_estimate: 2.0, pf_interval_days: 3.0)
    adv = advisory(inc, due_within_days: 20)
    result = Refineguard::PrognosticsService.recalculate(inc, force_regime: "heavy")

    assert_equal "heavy", result[:regime]
    assert result[:escalated]
    assert_equal "Urgent Action Required", adv.reload.urgency
    assert_equal 14, adv.due_within_days
    assert SecurityAuditEvent.where(organization: @org, action_type: "RUL_ESCALATION").exists?
  end

  test "a zero RUL estimate falls back to the P-F interval and then to the prior" do
    inc = incident(rul_days_estimate: 0.0, pf_interval_days: 100.0)
    Refineguard::PrognosticsService.recalculate(inc)
    assert_equal 53.7, inc.reload.rul_days_estimate

    inc.update_columns(rul_days_estimate: 0.0, pf_interval_days: 0.0)
    Refineguard::PrognosticsService.recalculate(inc)
    assert_equal 107.4, inc.reload.rul_days_estimate
  end

  test "the feed-slate transition only fires for a known regime outside the band" do
    inc = incident(regime: "light")
    assert Refineguard::PrognosticsService.feed_slate_transition?(inc, observed_load_percent: 60.0)
    assert_not Refineguard::PrognosticsService.feed_slate_transition?(inc, observed_load_percent: 80.0)

    inc.update_columns(regime: nil)
    assert_not Refineguard::PrognosticsService.feed_slate_transition?(inc, observed_load_percent: 10.0)

    inc.update_columns(regime: "exotic")
    assert_not Refineguard::PrognosticsService.feed_slate_transition?(inc, observed_load_percent: 10.0)
  end

  test "the regime detector and its confidence follow the data completeness" do
    { 0.0 => "medium", 99.0 => "light", 93.0 => "heavy" }.each do |completeness, expected|
      asset = Asset.create!(organization: @org, asset_tag: "P-C#{completeness}", asset_name: "P",
                            health_state: "Alarm", health_index: 30.0, health_index_delta: 20.0,
                            data_completeness_pct: completeness, monitored: true)
      inc = DiagnosticIncident.create!(organization: @org, asset: asset, status: "Active",
                                       health_state: "Alarm", incident_code: "INC-C#{completeness}",
                                       detected_at: 3.days.ago)

      result = Refineguard::PrognosticsService.recalculate(inc)
      assert_equal expected, result[:regime]
      assert_equal [ 60.0, completeness ].max, result[:regime_confidence_pct]
    end
  end

  # ---- StandbyCheckService -------------------------------------------------

  test "a standby twin that passed its checks produces a ready switchover advisory" do
    Asset.create!(organization: @org, asset_tag: "P-204B", asset_name: "Standby",
                  monitored: true, last_sample_at: 5.minutes.ago, data_completeness_pct: 99.0)

    adv = Refineguard::StandbyCheckService.evaluate(incident)

    assert adv.standby_ready
    assert_equal "Urgent Action Required", adv.urgency
    assert_equal 4, adv.standby_checks_json.length
    assert_equal 4, adv.action_steps_json.length
  end

  test "a standby twin that fails its checks still yields a routine advisory" do
    Asset.create!(organization: @org, asset_tag: "P-204C", asset_name: "Standby",
                  monitored: false, last_sample_at: 3.days.ago, data_completeness_pct: 50.0)

    adv = Refineguard::StandbyCheckService.evaluate(incident)

    assert_not adv.standby_ready
    assert_equal "Routine", adv.urgency
    assert_includes adv.standby_checks_json.map { |c| c["detail"] }, "Requires field verification"
  end

  test "no switchover evaluation without a breach or without a standby twin" do
    assert_nil Refineguard::StandbyCheckService.evaluate(incident(health_state: "Normal"))
    assert_nil Refineguard::StandbyCheckService.evaluate(incident)
    assert_nil Refineguard::StandbyCheckService.standby_for(Asset.new(asset_tag: nil))
  end

  # ---- UnitRiskMatrixBuilder ----------------------------------------------

  test "the risk matrix rolls up severity, exposure and the horizon cells" do
    Asset.create!(organization: @org, asset_tag: "P-101B", asset_name: "Healthy",
                  plant_unit: @unit, health_state: "Normal", health_index: 96.0, monitored: true)
    rows = Refineguard::UnitRiskMatrixBuilder.new(
      units: [ @unit ], assets: Asset.where(organization: @org).to_a,
      advisories: [ advisory(incident) ]
    ).rows

    row = rows.first
    assert_equal "CDU-1", row["unit"]
    assert_equal "$418k/day", row["exposure"]
    assert_equal "P-204A", row["critical_train"]
    assert_equal 4, row["risk_cells"].length
    # one non-healthy asset plus one open advisory in this unit
    assert_equal 2, row["risk_cells"].first["devices_at_risk"]
    assert_operator row["trend"].length, :>=, 1
  end

  test "a unit with no assets and no exposure reports the empty defaults" do
    bare = PlantUnit.create!(organization: @org, unit_code: "FCC-1", unit_name: "FCC 1")
    row = Refineguard::UnitRiskMatrixBuilder.new(units: [ bare ], assets: [], advisories: []).rows.first

    assert_nil row["exposure"]
    assert_equal "healthy", row["severity"]
    assert_equal [], row["trend"]
    assert_equal "3%", row["trip_probability"]
  end

  # ---- HealthStateService --------------------------------------------------

  test "three consecutive breaches transition the state and roll it up" do
    index = AssetHealthIndex.create!(organization: @org, asset: @asset, calculated_at: Time.current,
                                     health_score: 40.0, health_state: "Normal",
                                     reconstruction_error: 0.2, threshold_p99: 0.1,
                                     consecutive_breach_intervals: 0)

    assert_not Refineguard::HealthStateService.evaluate(index)[:transitioned]
    assert_not Refineguard::HealthStateService.evaluate(index)[:transitioned]
    third = Refineguard::HealthStateService.evaluate(index)

    assert third[:transitioned]
    assert_equal "Alert", third[:health_state]
    assert_equal "Alert", @asset.reload.health_state
  end

  test "a value inside the threshold resets the breach counter and never transitions" do
    index = AssetHealthIndex.create!(organization: @org, asset: @asset, calculated_at: Time.current,
                                     health_score: 90.0, health_state: "Normal",
                                     reconstruction_error: 0.01, threshold_p99: 0.1,
                                     consecutive_breach_intervals: 5)

    result = Refineguard::HealthStateService.evaluate(index)
    assert_not result[:breach]
    assert_equal 0, result[:consecutive_breach_intervals]
    assert_not result[:transitioned]

    assert_nil Refineguard::HealthStateService.roll_up(nil)
    assert_equal @asset.id, Refineguard::HealthStateService.roll_up(@asset, "Alert").id
  end

  test "a health index with no threshold never breaches" do
    index = AssetHealthIndex.create!(organization: @org, asset: @asset, calculated_at: Time.current,
                                     health_score: 50.0, health_state: "Normal")
    assert_not Refineguard::HealthStateService.evaluate(index)[:breach]
  end

  # ---- HistorianBufferService ---------------------------------------------

  test "an over-timeout probe buffers locally and a recovery replays it" do
    connector = HistorianConnector.create!(organization: @org, connector_name: "PI",
                                           historian_type: "OSIsoft_PI", status: "Connected",
                                           connection_timeout_ms: 3000, polling_interval_seconds: 5,
                                           ring_buffer_enabled: true, buffer_depth: 0,
                                           backfill_total: 0, backfill_committed: 0)

    buffered = Refineguard::HistorianBufferService.test_connection(
      connector, simulated_latency_ms: 9000, pending_points: 3
    )
    assert buffered[:buffering]
    assert_equal 3, buffered[:buffered]
    assert_equal "Buffering", buffered[:status]

    recovered = Refineguard::HistorianBufferService.test_connection(connector, simulated_latency_ms: 100)
    assert_not recovered[:buffering]
    assert_equal 3, recovered[:replayed]
    assert_equal "Connected", recovered[:status]
    assert_equal 0, connector.reload.buffer_depth
  end

  test "ingest commits when the ring buffer is off and buffers when the link is down" do
    connector = HistorianConnector.create!(organization: @org, connector_name: "PHD",
                                           historian_type: "Honeywell_PHD", status: "Connected",
                                           ring_buffer_enabled: false)
    assert_equal :committed, Refineguard::HistorianBufferService.ingest(connector)

    connector.update!(ring_buffer_enabled: true, status: "Buffering")
    assert_equal :buffered, Refineguard::HistorianBufferService.ingest(connector, points: 2)
    assert_equal 2, connector.reload.buffer_depth
  end

  test "the default pending-point estimate follows the polling interval" do
    connector = HistorianConnector.create!(organization: @org, connector_name: "EXA",
                                           historian_type: "Yokogawa_Exaquantum", status: "Connected",
                                           connection_timeout_ms: 3000, polling_interval_seconds: 1,
                                           ring_buffer_enabled: true, poll_latency_ms: 0)
    probe = Refineguard::HistorianBufferService.test_connection(connector, simulated_latency_ms: 9000)

    assert probe[:buffering]
    assert_operator probe[:buffered], :>=, 1
  end

  # ---- BaselineTrainingService --------------------------------------------

  test "training selects the golden windows and satisfies the gates" do
    baseline = ModelBaseline.create!(organization: @org, asset: @asset, model_version: "v1",
                                     algorithm_type: "Deep Autoencoder", status: "Candidate")
    BaselineWindow.create!(organization: @org, asset: @asset, model_baseline: baseline,
                           label: "Golden", window_start: 2.days.ago, window_end: 1.day.ago,
                           load_percent: 88.0, completeness_percent: 98.0,
                           selected: true, eligible: true)

    trained = Refineguard::BaselineTrainingService.train(baseline)

    assert_equal "Trained", trained.training_status
    assert_equal 100, trained.training_progress
    assert trained.gates_satisfied?
    assert_equal 1, trained.accuracy_metrics_json["windows_used"]
    refute_nil trained.training_window_start
  end

  test "training falls back to eligible windows and then to the latest window" do
    baseline = ModelBaseline.create!(organization: @org, asset: @asset, model_version: "v2",
                                     algorithm_type: "Deep Autoencoder", status: "Candidate")
    BaselineWindow.create!(organization: @org, asset: @asset, model_baseline: baseline,
                           label: "Eligible", window_start: 3.days.ago, window_end: 2.days.ago,
                           load_percent: 80.0, completeness_percent: 90.0, eligible: true)

    assert_equal "Trained", Refineguard::BaselineTrainingService.train(baseline).training_status

    empty = ModelBaseline.create!(organization: @org, asset: @asset, model_version: "v3",
                                  algorithm_type: "Deep Autoencoder", status: "Candidate")
    assert_equal "Trained", Refineguard::BaselineTrainingService.train(empty).training_status
  end

  test "promotion is gated on training status and the gates, then archives the previous" do
    previous = ModelBaseline.create!(organization: @org, asset: @asset, model_version: "old",
                                     algorithm_type: "Deep Autoencoder", is_active: true,
                                     status: "Production", training_status: "Trained")
    candidate = ModelBaseline.create!(organization: @org, asset: @asset, model_version: "new",
                                      algorithm_type: "Deep Autoencoder", status: "Candidate")

    assert_match(/Only a trained candidate/, Refineguard::BaselineTrainingService.promote(candidate, nil)[:errors].first)

    candidate.update!(training_status: "Trained", gates_json: { "accuracy" => false })
    assert_match(/Promotion gates/, Refineguard::BaselineTrainingService.promote(candidate, nil)[:errors].first)

    candidate.update!(gates_json: { "accuracy" => true })
    result = Refineguard::BaselineTrainingService.promote(candidate, nil)

    assert result[:promoted]
    assert_equal "Production", candidate.reload.status
    assert candidate.is_active
    assert_equal "Archived", previous.reload.status
    assert_not previous.is_active
  end
end
