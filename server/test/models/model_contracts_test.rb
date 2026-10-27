# frozen_string_literal: true

require "test_helper"

# Model read-path contracts: ISO severity mapping, derived labels, role-facing
# computed attributes and the soft-delete/audit helpers the UI depends on.
class ModelContractsTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Contracts Org")
  end

  def asset(attrs = {})
    Asset.create!({ organization: @org, asset_tag: "P-#{SecureRandom.hex(3)}", asset_name: "Pump",
                    monitored: true }.merge(attrs))
  end

  # ---- Organization --------------------------------------------------------

  test "an organization derives its slug from the name when none is given" do
    assert_equal "contracts-org", @org.slug
    assert_equal "explicit", Organization.create!(name: "Other", slug: "explicit").slug
  end

  # ---- Severity ------------------------------------------------------------

  test "the severity vocabulary maps every ISO state to its badge" do
    { "Trip" => "critical", "Alarm" => "critical", "Alert" => "warning",
      "Normal" => "healthy", "info" => "info", nil => "info", "nonsense" => "info" }.each do |state, badge|
      assert_equal badge, Refineguard::Severity.badge(state)
    end
    assert_equal "warning", Refineguard::Severity.badge(nil, default: "warning")
    assert_equal "Critical", Refineguard::Severity.label("critical")
    assert_equal "Info", Refineguard::Severity.label("unknown")
    assert_equal 0, Refineguard::Severity.rank("critical")
    assert_equal 99, Refineguard::Severity.rank("unknown")
  end

  # ---- Asset ---------------------------------------------------------------

  test "the ISO 10816 category follows the vibration velocity" do
    assert_nil asset(rms_velocity_mms: nil).iso_severity_category
    assert_equal "Good", asset(rms_velocity_mms: 1.0).iso_severity_category
    assert_equal "Satisfactory", asset(rms_velocity_mms: 4.0).iso_severity_category
    assert_equal "Unsatisfactory", asset(rms_velocity_mms: 9.0).iso_severity_category
    assert_equal "Unacceptable", asset(rms_velocity_mms: 20.0).iso_severity_category
  end

  test "the sample age label switches between seconds, minutes and hours" do
    assert_nil asset(last_sample_at: nil).sample_age_label
    assert_equal "30 s", asset(last_sample_at: 30.seconds.ago).sample_age_label
    assert_equal "5 min", asset(last_sample_at: 5.minutes.ago).sample_age_label
    assert_equal "3 h", asset(last_sample_at: 3.hours.ago).sample_age_label
  end

  test "the asset payload exposes the tag as its display id" do
    record = asset(asset_tag: "P-900", health_state: "Alert", health_index: 61.0,
                   rms_velocity_mms: 3.2, bearing_temp_c: 71.4, estimated_rul_window: "12 d")
    payload = record.rhino_computed_attributes

    assert_equal "P-900", payload["id"]
    assert_equal record.id, payload["record_id"]
    assert_equal "warning", payload["severity"]
    assert_equal "Advisory", payload["status"]
    assert_equal "Satisfactory", payload["iso_severity_category"]
    assert_equal "3.20", payload["rms"]
    assert_equal "71", payload["temp"]
  end

  # ---- PrescriptiveAdvisory ------------------------------------------------

  test "the advisory urgency vocabulary falls back to the raw value" do
    incident = DiagnosticIncident.create!(organization: @org, asset: asset, status: "Active",
                                          detected_at: Time.current, incident_code: "INC-1")
    advisory = PrescriptiveAdvisory.new(organization: @org, diagnostic_incident: incident,
                                        status: "Ready for Dispatch")

    # The incident's health state defaults to Normal, so the urgency vocabulary
    # only drives the badge when the incident carries no state of its own.
    incident.update_column(:health_state, nil)
    advisory.urgency = "Urgent Action Required"
    assert_equal "Alarm", advisory.urgency_state
    assert_equal "critical", advisory.severity
    advisory.urgency = "Routine"
    assert_equal "Normal", advisory.urgency_state
    advisory.urgency = "Watch closely"
    assert_equal "Watch closely", advisory.urgency_state
  end

  test "the advisory RUL window prefers the incident band and falls back" do
    incident = DiagnosticIncident.create!(organization: @org, asset: asset, status: "Active",
                                          detected_at: Time.current, incident_code: "INC-2",
                                          rul_window_low_days: 6.0, rul_window_high_days: 11.0)
    advisory = PrescriptiveAdvisory.create!(organization: @org, diagnostic_incident: incident,
                                            status: "Ready for Dispatch", advisory_code: "ADV-2",
                                            recommended_action: "Replace the bearing pair.")

    assert_equal "6–11 d", advisory.rul_window_label
    payload = advisory.rhino_computed_attributes
    assert_equal "Replace the bearing pair.", payload["recommendation"]
    assert_equal incident.asset.asset_tag, payload["asset_tag"]
    assert_equal advisory.severity, payload["severity"]
  end

  # ---- DiagnosticIncident --------------------------------------------------

  test "the incident RUL label falls back to the estimate and then to nothing" do
    incident = DiagnosticIncident.create!(organization: @org, asset: asset, status: "Active",
                                          detected_at: Time.current, incident_code: "INC-3")
    assert_nil incident.rul_window_label

    incident.update!(rul_days_estimate: 9.0)
    assert_equal "9 d", incident.rul_window_label

    incident.update!(rul_window_low_days: 4.0, rul_window_high_days: 8.0)
    assert_equal "4–8 d", incident.rul_window_label
  end

  test "acknowledging and signing off persist the transition" do
    incident = DiagnosticIncident.create!(organization: @org, asset: asset, status: "Active",
                                          detected_at: Time.current, incident_code: "INC-4")
    incident.acknowledge!(nil)
    assert_equal "Under Investigation", incident.status
    assert_nil incident.acknowledged_by_id
    assert_not_nil incident.acknowledged_at
    assert_equal "Acknowledged", incident.rhino_computed_attributes["sync_status"]

    incident.sign_off!(nil, { "root_cause" => "Outer race spall", "unknown" => "ignored" })
    assert_equal "Signed off", incident.finding_status
    assert_equal "Outer race spall", incident.root_cause
  end

  # ---- HistorianTag --------------------------------------------------------

  test "tag staleness prefers the measured column and falls back to the clock" do
    measured = HistorianTag.create!(organization: @org, historian_type: "OSIsoft_PI",
                                    source_tag_name: "T1", tag_path: "PI:T1", stale_seconds: 900)
    assert_equal 900, measured.computed_stale_seconds
    assert measured.stale?

    live = HistorianTag.create!(organization: @org, historian_type: "OSIsoft_PI",
                                source_tag_name: "T2", tag_path: "PI:T2",
                                last_validated_at: 5.minutes.ago)
    assert_operator live.computed_stale_seconds, :>=, 299
    assert live.stale?
    assert_not live.healthy?

    never = HistorianTag.create!(organization: @org, historian_type: "OSIsoft_PI",
                                 source_tag_name: "T3", tag_path: "PI:T3")
    assert_nil never.computed_stale_seconds
    assert_not never.stale?
    assert never.healthy?
    assert_equal "healthy", never.rhino_computed_attributes["severity"]
  end

  # ---- AssetHealthIndex ----------------------------------------------------

  test "the health index attribution normalises weighted and scalar factors" do
    index = AssetHealthIndex.new(organization: @org, asset: asset, calculated_at: Time.current,
                                 health_score: 28.0, health_state: "Alert",
                                 contributing_factors_json: {
                                   "vib_de_env" => { "weight" => 0.45, "z_score" => 3.8, "status" => "severe" },
                                   "brg_nde_temp" => 0.15
                                 })
    attribution = index.attribution

    assert_equal %w[vib_de_env brg_nde_temp], attribution.map { |row| row["label"] }
    assert_in_delta 75.0, attribution.first["percent"], 0.1
    assert_equal 3.8, attribution.first["z_score"]
    assert_nil attribution.last["z_score"]

    flat = AssetHealthIndex.new(organization: @org, asset: asset, calculated_at: Time.current,
                                health_score: 90.0, contributing_factors_json: [ 1, 2 ])
    assert_equal [], flat.attribution
    assert_equal "warning", index.severity
  end

  # ---- CmmsWorkOrder -------------------------------------------------------

  test "a work order derives its asset tag and severity from the advisory" do
    incident = DiagnosticIncident.create!(organization: @org, asset: asset, status: "Active",
                                          detected_at: Time.current, incident_code: "INC-5",
                                          health_state: "Trip")
    advisory = PrescriptiveAdvisory.create!(organization: @org, diagnostic_incident: incident,
                                            status: "Ready for Dispatch")
    order = CmmsWorkOrder.create!(organization: @org, prescriptive_advisory: advisory,
                                  cmms_type: "SAP PM", sync_status: CmmsWorkOrder::SYNC_PENDING)
    payload = order.rhino_computed_attributes

    assert_equal incident.asset.asset_tag, payload["asset_tag"]
    assert_equal "critical", payload["severity"]
    assert_nil payload["dispatched_by_name"]

    order.discard!
    assert order.discarded?
    assert_includes CmmsWorkOrder.with_discarded, order
  end

  # ---- SecurityAuditEvent --------------------------------------------------

  test "the audit chain hash detects tampering" do
    event = SecurityAuditEvent.new(organization: @org, action_type: "AUTH_LOGIN",
                                   recorded_at: Time.current, actor_name: "Ada")
    event.tamper_proof_hash = event.expected_hash
    event.save!

    assert event.tamper_proof?
    assert event.rhino_computed_attributes["tamper_proof"]

    event.update_column(:actor_name, "Someone Else")
    assert_not event.reload.tamper_proof?
  end

  # ---- Small payload contracts --------------------------------------------

  test "telemetry, component, baseline, work-order and shift-log payloads" do
    tag = HistorianTag.create!(organization: @org, historian_type: "OSIsoft_PI",
                               source_tag_name: "T9", tag_path: "PI:T9", asset: asset)
    reading = TelemetryRecord.create!(organization: @org, historian_tag: tag,
                                      recorded_at: Time.current, recorded_value: 1.5,
                                      data_quality_flag: "Good")
    assert_equal "PI:T9", reading.rhino_computed_attributes["tag_path"]

    component = AssetComponent.create!(organization: @org, asset: asset,
                                       component_name: "Drive end bearing", health_state: "Alarm")
    assert_equal "critical", component.severity
    assert_equal "critical", component.rhino_computed_attributes["severity"]

    baseline = ModelBaseline.new(organization: @org, asset: asset, model_version: "v1",
                                 gates_json: { "accuracy" => true, "precision" => "true" })
    assert baseline.gates_satisfied?
    baseline.gates_json = {}
    assert_not baseline.gates_satisfied?
    baseline.gates_json = { "accuracy" => false }
    assert_not baseline.gates_satisfied?
    baseline.gates_json = "nope"
    assert_not baseline.gates_satisfied?
  end

  test "a baseline window cannot end before it starts" do
    window = BaselineWindow.new(organization: @org, asset: asset, label: "Window",
                                window_start: Time.current, window_end: 1.hour.ago)
    assert_not window.valid?
    assert window.errors[:window_end].any?

    window.window_end = 1.hour.from_now
    assert window.valid?
  end

  test "a shift log entry exposes its severity badge" do
    entry = ShiftLogEntry.create!(organization: @org, occurred_at: Time.current,
                                  event_type: "Derate approval", severity: "warning",
                                  message: "Throttle to 70%.")
    assert_equal "warning", entry.severity_badge
    assert entry.rhino_computed_attributes.key?("severity")
  end

  test "a failure mode assessment maps its probability onto the ISO state" do
    mode = FailureMode.create!(organization: @org, iso_code: "ISO-X", failure_name: "Outer race",
                               equipment_category: "Centrifugal Pump", severity_weight: 0.8)
    assessment = FailureModeAssessment.create!(organization: @org, asset: asset, failure_mode: mode,
                                               probability: 80.0, assessed_at: Time.current)
    assert_equal "Alarm", assessment.severity_from_probability
    assert_equal "critical", assessment.rhino_computed_attributes["severity"]

    assessment.probability = 50.0
    assert_equal "Alert", assessment.severity_from_probability
    assessment.probability = 10.0
    assert_equal "Normal", assessment.severity_from_probability
    assessment.probability = nil
    assert_equal "Normal", assessment.severity_from_probability
  end
end
