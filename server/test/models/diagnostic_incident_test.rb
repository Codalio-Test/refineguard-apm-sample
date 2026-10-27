# frozen_string_literal: true

require "test_helper"

# the persisted incident transitions.
class DiagnosticIncidentModelTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "inc-org", name: "Incident Org")
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Pump A",
                           health_state: "Trip", health_index: 28.0)
    @user = User.create!(name: "Marcus", email: "marcus@example.com", password: "password")
    @incident = DiagnosticIncident.create!(
      organization: @org, asset: @asset, incident_code: "INC-24018",
      status: "Active", severity_level: "High", health_state: "Trip",
      rul_days_estimate: 8.5, rul_window_low_days: 6.0, rul_window_high_days: 11.0,
      rul_confidence_pct: 90.0, pf_interval_days: 21.0, detected_at: 3.days.ago
    )
  end

  test "acknowledge! persists the Under Investigation transition with actor and timestamp" do
    # the prototype's local toggle becomes a real update.
    @incident.acknowledge!(@user)
    @incident.reload

    assert_equal "Under Investigation", @incident.status
    assert_equal @user.id, @incident.acknowledged_by_id
    assert_not_nil @incident.acknowledged_at
  end

  test "sign_off! stamps the finding and the signer" do
    # finding authoring with technical notes and sign-off.
    @incident.sign_off!(@user, {
      "root_cause" => "Stage 2 outer race spall",
      "evidence_summary" => "Discrete BPFO peaks with 1X sidebands",
      "failure_mechanism" => "Stage 2 Bearing Outer Race Spall",
      "finding_confidence" => 0.89
    })
    @incident.reload

    assert_equal "Signed off", @incident.finding_status
    assert_equal "Stage 2 outer race spall", @incident.root_cause
    assert_equal @user.id, @incident.signed_off_by_id
    assert_not_nil @incident.signed_off_at
  end

  test "severity is derived from the ISO health state" do
    assert_equal "critical", @incident.severity
    @incident.update!(health_state: "Alert")
    assert_equal "warning", @incident.severity
  end

  test "rul_window_label matches the prototype readout format" do
    # "6–11 d".
    assert_equal "6–11 d", @incident.rul_window_label
  end

  test "computed attributes expose the asset tag and finding" do
    json = @incident.rhino_computed_attributes
    assert_equal "P-204A", json["asset_tag"]
    assert_equal "New", json["sync_status"]
    @incident.acknowledge!(@user)
    assert_equal "Acknowledged", @incident.rhino_computed_attributes["sync_status"]
  end

  test "the status column default keeps new incidents Active" do
    # The migration's default is applied to new records, so an incident is
    # never left statusless by the classifier.
    record = DiagnosticIncident.new(organization: @org, asset: @asset, detected_at: Time.current)
    assert_equal "Active", record.status
    assert record.valid?
  end

  test "asset is required" do
    record = DiagnosticIncident.new(organization: @org, status: "Active", detected_at: Time.current)
    assert_not record.valid?
    assert_includes record.errors[:asset], "must exist"
  end
end
