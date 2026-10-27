# frozen_string_literal: true

require "test_helper"

# The projections and label helpers every screen reads.
#
# A row the API returns can be partially populated: an association the caller may
# not read, an optional column nobody filled in, or a record that has not been
# saved yet. Both sides of every one of those fallbacks is exercised here, because
# a fallback that only ever runs one way is a branch nobody has ever seen work.
class BranchFallbacksTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Branch Org", slug: "branch-org")
    @unit = PlantUnit.create!(organization: @org, unit_code: "CDU-1", unit_name: "CDU 1",
                              rate_percent: 92.0)
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Pump",
                           plant_unit: @unit, health_state: "Alarm", health_index: 30.0,
                           monitored: true)
    @approver = User.create!(email: "approver@example.com", name: "Ada Approver",
                             password: "password", approved: true)
  end

  def incident(attrs = {})
    DiagnosticIncident.create!({ organization: @org, asset: @asset, status: "Active",
                                 detected_at: 3.days.ago, incident_code: "INC-BRANCH" }
                                 .merge(attrs))
  end

  def advisory(inc, attrs = {})
    PrescriptiveAdvisory.create!({ organization: @org, diagnostic_incident: inc,
                                   status: PrescriptiveAdvisory::STATUS_READY }
                                 .merge(attrs))
  end

  # ---- PrescriptiveAdvisory ------------------------------------------------

  test "an advisory with no incident projects every association as absent" do
    unsaved = PrescriptiveAdvisory.new(urgency: "Routine")

    assert_nil unsaved.health_state
    assert_nil unsaved.rul_window_label
    # health_state is unknown, so the badge falls back to the urgency vocabulary
    assert_equal "healthy", unsaved.severity

    attrs = unsaved.rhino_computed_attributes
    assert_nil attrs["asset_tag"]
    assert_nil attrs["asset_id"]
    assert_nil attrs["rul_window"]
    assert_nil attrs["standby_asset_tag"]
    assert_nil attrs["derate_approved_by_name"]
  end

  test "the finding falls back to the failure mechanism when the mode is unknown" do
    inc = incident(failure_mode: nil, failure_mechanism: "Bearing outer race spall")
    assert_equal "Bearing outer race spall",
                 advisory(inc).rhino_computed_attributes["finding"]
  end

  test "the projection reports the approving superintendent and the standby twin" do
    inc = incident
    standby = Asset.create!(organization: @org, asset_tag: "P-204B", asset_name: "Pump B")
    attrs = advisory(inc, standby_asset: standby, derate_approved_by: @approver)
            .rhino_computed_attributes

    assert_equal "P-204B", attrs["standby_asset_tag"]
    assert_equal "Ada Approver", attrs["derate_approved_by_name"]
  end

  # ---- DiagnosticIncidentSerializer ----------------------------------------

  test "the incident serializer emits fallbacks for a record with no rows behind it" do
    unsaved = DiagnosticIncident.new
    serializer = Refineguard::Serializers::DiagnosticIncidentSerializer.new(unsaved)

    row = serializer.anomaly_row
    assert_nil row["id"]
    assert_nil row["asset_tag"]
    assert_nil row["asset_tag_label"]
    assert_nil row["detected_at"]
    assert_equal "Degradation detected", row["issue"]

    assert_nil serializer.acknowledgement[:acknowledged_at]
    assert_nil serializer.sign_off(propagated_advisories: [])[:signed_off_at]
  end

  test "the incident serializer ages a detection in minutes, hours and days" do
    minutes = DiagnosticIncident.new(detected_at: 30.minutes.ago)
    hours = DiagnosticIncident.new(detected_at: 5.hours.ago)
    days = DiagnosticIncident.new(detected_at: 3.days.ago)

    assert_equal "30 min", Refineguard::Serializers::DiagnosticIncidentSerializer
                           .new(minutes).anomaly_row["age"]
    assert_equal "5 h", Refineguard::Serializers::DiagnosticIncidentSerializer
                        .new(hours).anomaly_row["age"]
    assert_equal "3 d", Refineguard::Serializers::DiagnosticIncidentSerializer
                        .new(days).anomaly_row["age"]
  end

  # ---- PrognosticsService --------------------------------------------------

  test "the regime classifier falls back to medium for mid-range data completeness" do
    mid = Asset.create!(organization: @org, asset_tag: "P-300A", asset_name: "Pump C",
                        data_completeness_pct: 96.0, monitored: true)
    inc = incident(asset: mid, regime: nil)
    result = Refineguard::PrognosticsService.recalculate(inc)

    assert_equal "medium", result[:regime]
    assert_equal 96.0, result[:regime_confidence_pct]
    # No health-index history and no delta: the baseline is zero, not a guess.
    assert_equal 0.0, result[:load_spike_percent]
  end

  test "the regime classifier reaches the heavy and light bands" do
    heavy = Asset.create!(organization: @org, asset_tag: "P-400A", asset_name: "Pump D",
                          data_completeness_pct: 50.0, monitored: true)
    light = Asset.create!(organization: @org, asset_tag: "P-401A", asset_name: "Pump E",
                          data_completeness_pct: 99.0, monitored: true)

    assert_equal "heavy",
                 Refineguard::PrognosticsService.recalculate(incident(asset: heavy))[:regime]
    assert_equal "light",
                 Refineguard::PrognosticsService.recalculate(incident(asset: light))[:regime]
    # A record with no completeness reading at all is mid-range, not light.
    blank = Asset.create!(organization: @org, asset_tag: "P-402A", asset_name: "Pump F")
    assert_equal "medium",
                 Refineguard::PrognosticsService.recalculate(incident(asset: blank))[:regime]
  end

  # ---- CmmsWorkOrder -------------------------------------------------------

  test "a work order with no advisory behind it projects an empty context" do
    attrs = CmmsWorkOrder.new.rhino_computed_attributes

    assert_nil attrs["asset_tag"]
    assert_equal "info", attrs["severity"]
    assert_nil attrs["dispatched_by_name"]
  end

  # ---- TelemetryRecord -----------------------------------------------------

  test "a telemetry row with no tag behind it projects an empty context" do
    attrs = TelemetryRecord.new.rhino_computed_attributes

    assert_nil attrs["tag_path"]
    assert_nil attrs["asset_tag"]
  end

  # ---- SecurityAuditEvent --------------------------------------------------

  test "an audit row without a clock still hashes and projects" do
    event = SecurityAuditEvent.new(action_type: "AUTH_LOGIN", tamper_proof_hash: "abc")
    attrs = event.rhino_computed_attributes

    assert_nil attrs["timestamp"]
    refute event.tamper_proof?
    refute_nil event.expected_hash
  end

  # ---- HistorianConnector --------------------------------------------------

  test "connector severity covers buffering, latency, and the known states" do
    assert_equal "warning", HistorianConnector.new(buffer_depth: 4).severity
    assert_equal "warning", HistorianConnector.new(poll_latency_ms: 1500).severity
    assert_equal "healthy", HistorianConnector.new(status: "Connected").severity
    assert_equal "warning", HistorianConnector.new(status: "Degraded").severity
    assert_equal "critical", HistorianConnector.new(status: "Disconnected").severity
    assert_equal "info", HistorianConnector.new(status: "Unknown").severity
  end

  test "the connector projects its endpoint fallback and latency label" do
    assert_equal "—", HistorianConnector.new.latency_label
    assert_equal "380ms", HistorianConnector.new(poll_latency_ms: 380).latency_label
    assert_equal "10.0.0.1",
                 HistorianConnector.new(server_address: "10.0.0.1").rhino_computed_attributes["endpoint"]
    assert_equal "https://pi.local",
                 HistorianConnector.new(endpoint_url: "https://pi.local",
                                        server_address: "10.0.0.1").rhino_computed_attributes["endpoint"]
  end
end
