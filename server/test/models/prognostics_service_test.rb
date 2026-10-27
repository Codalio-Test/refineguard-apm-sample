# frozen_string_literal: true

require "test_helper"

# multi-operating-regime prognostic sensitivity and RUL escalation.
#
# regime detection from flow / suction pressure / VFD speed
# feed-slate switch recalculates the P-F slope without resetting damage
# regime confidence + continuous-duty vs accelerated-wear zone
# recalculation when load / vibration RMS exceeds the rolling 7-day
#          average by more than 15 %
# RUL <= 14 days escalates the advisory to 'Urgent Action Required'
# the escalation also raises a high-priority alert (audit event)
class PrognosticsServiceTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "prognostics-org", name: "Prognostics Org")
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Crude charge pump A",
                           health_state: "Alert", health_index: 28.0, health_index_delta: 20.0,
                           data_completeness_pct: 99.0)
    @incident = DiagnosticIncident.create!(
      organization: @org, asset: @asset, incident_code: "INC-1", status: "Active",
      severity_level: "High", health_state: "Alert", rul_days_estimate: 10.0,
      pf_interval_days: 21.0, finding_confidence: 0.2, detected_at: 3.days.ago
    )
  end

  def health_index_row(score)
    AssetHealthIndex.create!(organization: @org, asset: @asset, calculated_at: 1.day.ago,
                             health_score: score, health_state: "Alert", reconstruction_error: 0.12,
                             threshold_p99: 0.09)
  end

  # the regime classifier labels the operating envelope and reports
  # its confidence; the label maps to a duty / wear zone the UI prints.
  test "the regime is detected and mapped to a duty or wear zone" do
    result = Refineguard::PrognosticsService.recalculate(@incident)

    assert_equal "light", result[:regime]
    assert_equal 99.0, result[:regime_confidence_pct]
    assert_equal 99.0, @incident.reload.regime_confidence_pct

    assert_match(/continuous duty/, Refineguard::PrognosticsService::REGIMES["light"])
    assert_match(/accelerated wear zone/, Refineguard::PrognosticsService::REGIMES["heavy"])

    # Degraded data quality lands in the accelerated-wear envelope.
    @asset.update!(data_completeness_pct: 90.0)
    @incident.update!(regime: nil) # re-detect instead of reusing the stored label
    assert_equal "heavy", Refineguard::PrognosticsService.recalculate(@incident.reload)[:regime]
  end

  # a feed-slate transition is detected by the observed load moving outside
  # the tolerance band, and the recalculation keeps the accumulated damage.
  test "a feed-slate switch recalculates without resetting accumulated damage" do
    @incident.update!(regime: "light")

    assert Refineguard::PrognosticsService.feed_slate_transition?(@incident, observed_load_percent: 98.0)
    assert_not Refineguard::PrognosticsService.feed_slate_transition?(@incident,
                                                                     observed_load_percent: 81.0)

    before = @incident.reload.finding_confidence
    result = Refineguard::PrognosticsService.recalculate(@incident, force_regime: "heavy")

    assert_equal "heavy", result[:regime]
    assert_equal "heavy", @incident.reload.regime
    # The damage proxy is carried forward, never zeroed by the regime switch.
    assert_operator result[:damage_preserved], :>=, before
    assert_operator @incident.reload.finding_confidence, :>=, before
    # The P-F interval is recomputed within the same synchronous pass (<5 min SLA).
    assert_not_equal 21.0, @incident.reload.pf_interval_days
  end

  # the trajectory is recalculated when load exceeds the rolling 7-day
  # average by more than 15 %.
  test "a load spike over the rolling 7-day average triggers recalculation" do
    @incident.update!(regime: "light", rul_days_estimate: 200.0, finding_confidence: 0.02)
    3.times { health_index_row(10.0) } # rolling average = 10

    @asset.update!(health_index_delta: 20.0) # 100 % over the rolling average
    spiked = Refineguard::PrognosticsService.recalculate(@incident.reload)
    assert_operator spiked[:load_spike_percent], :>, 15.0
    assert_not spiked[:escalated]

    @asset.update!(health_index_delta: 5.0) # well inside the band
    calm = Refineguard::PrognosticsService.recalculate(@incident.reload)
    assert_operator calm[:load_spike_percent], :<=, 15.0
    assert_not calm[:escalated]
  end

  # RUL at or below 14 days escalates the advisory and raises a
  # high-priority alert.
  test "RUL at or below 14 days escalates the advisory and alerts" do
    advisory = PrescriptiveAdvisory.create!(
      organization: @org, diagnostic_incident: @incident, advisory_code: "ADV-1",
      urgency: "Routine", status: "Ready for Dispatch", due_within_days: 30
    )
    @incident.update!(regime: "medium", rul_days_estimate: 10.0, finding_confidence: 0.2)

    result = Refineguard::PrognosticsService.recalculate(@incident)

    assert_operator result[:rul_days_estimate], :<=, 14.0
    assert result[:escalated]

    advisory.reload
    assert_equal "Urgent Action Required", advisory.urgency
    assert_operator advisory.due_within_days, :<=, 14

    assert SecurityAuditEvent.where(organization: @org, action_type: "RUL_ESCALATION",
                                    severity: "critical").exists?,
           "the escalation must raise a high-priority alert in the audit trail"
  end

  # no escalation while the estimate is comfortably above the threshold.
  test "a healthy RUL does not escalate the advisory" do
    advisory = PrescriptiveAdvisory.create!(
      organization: @org, diagnostic_incident: @incident, advisory_code: "ADV-2",
      urgency: "Routine", status: "Ready for Dispatch", due_within_days: 45
    )
    @asset.update!(health_index: 99.0)
    @incident.update!(regime: "light", rul_days_estimate: 60.0, finding_confidence: 0.05)

    result = Refineguard::PrognosticsService.recalculate(@incident)

    assert_operator result[:rul_days_estimate], :>, 14.0
    assert_not result[:escalated]
    assert_equal "Routine", advisory.reload.urgency
  end
end
