# frozen_string_literal: true

require "test_helper"

# The DCS shift handover log.
#
# operations/shift-log lists active changeover, derate and lockout notices
# step-by-step standby start procedures check off and sync completion
# the shift-log read model (procedure steps, handover, acknowledgement)
# the check-off is an operations_superintendent / admin action (no
#          `console_operator` role is registered)
class ShiftLogEntryTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
    @changeover = ShiftLogEntry.create!(
      organization: @demo_org, plant_unit: @unit, asset: @asset, author: @superintendent,
      occurred_at: 2.hours.ago, shift_label: "Day shift", event_type: "Standby changeover",
      severity: "warning", message: "Start P-101B and take load off P-204A.",
      unit_status: "Running on standby train B",
      procedure_steps_json: [
        { "label" => "Verify lube oil level", "done" => true },
        { "label" => "Energise motor space heater", "done" => false },
        { "label" => "Crack open suction valve", "done" => false },
        { "label" => "Start pump and confirm discharge pressure", "done" => false },
        { "label" => "Close P-204A discharge and isolate", "done" => false }
      ],
      steps_completed: 1, steps_total: 5, incoming_ack: false
    )
    @derate = ShiftLogEntry.create!(
      organization: @demo_org, plant_unit: @unit, asset: @asset, author: @superintendent,
      occurred_at: 1.hour.ago, shift_label: "Day shift", event_type: "Derate approval",
      severity: "warning", message: "CDU-1 charge rate reduced 8%."
    )
    @lockout = ShiftLogEntry.create!(
      organization: @demo_org, plant_unit: @unit, asset: @asset, author: @superintendent,
      occurred_at: 30.minutes.ago, shift_label: "Day shift", event_type: "Maintenance lockout",
      severity: "critical", message: "P-204A mechanical lockout applied pending bearing work."
    )
  end

  def rows
    get "/api/demo-org/shift_log_entries", params: { sort: "-occurred_at" },
        headers: auth_headers(@superintendent)
    assert_response :ok
    JSON.parse(response.body)["data"]
  end

  # the incoming shift supervisor sees every active changeover, derate and
  # lockout notice, most recent first.
  test "the shift log lists active changeovers, derates and lockouts newest first" do
    body = rows

    event_types = body.map { |row| row["event_type"] }
    assert_includes event_types, "Standby changeover"
    assert_includes event_types, "Derate approval"
    assert_includes event_types, "Maintenance lockout"

    assert_equal "Maintenance lockout", event_types.first
    assert_equal "Standby changeover", event_types.last

    body.each do |row|
      assert row["timestamp"].present?, "every entry carries a sortable timestamp"
      assert row["severity"].present?
    end
  end

  # the read model the handover form binds to.
  test "shift log entries expose the procedure, step and handover columns" do
    row = rows.find { |candidate| candidate["event_type"] == "Standby changeover" }

    assert_equal 5, row["procedure_steps_json"].length
    assert_equal "Verify lube oil level", row["procedure_steps_json"].first["label"]
    assert_equal 1, row["steps_completed"]
    assert_equal 5, row["steps_total"]
    assert_equal 20, row["steps_percent"]
    assert_equal false, row["incoming_ack"]
    assert row.key?("handover_completed_at")
    assert_equal @asset.asset_tag, row["asset_tag"]
    assert_equal "CDU-1", row["unit"]
  end

  # checking off a standby start step persists and reports
  # completion back for /fleet-overview.
  test "step check-off persists and reports completion to the fleet view" do
    put "/api/demo-org/shift_log_entries/#{@changeover.id}",
        params: { steps_completed: 4 }.to_json, headers: json_headers(@superintendent)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 4, body["steps_completed"]
    assert_equal 80, body["steps_percent"]
    assert_equal 4, @changeover.reload.steps_completed
  end

  test "the handover acknowledgement and completion are writable" do
    put "/api/demo-org/shift_log_entries/#{@changeover.id}",
        params: { incoming_ack: true, handover_completed_at: Time.current.iso8601 }.to_json,
        headers: json_headers(@admin)

    assert_response :ok
    @changeover.reload
    assert_equal true, @changeover.incoming_ack
    assert_not_nil @changeover.handover_completed_at
  end

  # the route ACL: only the superintendent (and admin) may check steps off;
  # a read-only role is refused, and an anonymous caller is unauthenticated.
  test "step check-off is restricted to the superintendent and admin" do
    put "/api/demo-org/shift_log_entries/#{@changeover.id}",
        params: { steps_completed: 2 }.to_json, headers: json_headers(@specialist)
    assert_response :forbidden
    assert_equal 1, @changeover.reload.steps_completed

    put "/api/demo-org/shift_log_entries/#{@changeover.id}",
        params: { steps_completed: 2 }.to_json, headers: json_headers(@engineer)
    assert_response :forbidden

    put "/api/demo-org/shift_log_entries/#{@changeover.id}",
        params: { steps_completed: 2 }.to_json, headers: json_headers(@planner)
    assert_response :forbidden

    put "/api/demo-org/shift_log_entries/#{@changeover.id}",
        params: { steps_completed: 2 }.to_json, headers: json_headers
    assert_response :unauthorized
  end
end
