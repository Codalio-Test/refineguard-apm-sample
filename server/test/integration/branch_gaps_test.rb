# frozen_string_literal: true

require "test_helper"

# The defensive half of every custom endpoint.
#
# Each of these exercises a condition the happy path never reaches: a record the
# caller can no longer see because its parent was withdrawn, an optional
# association that was never populated, a field the client omitted, or an adapter
# that refuses the transmission. Every assertion is about the documented response,
# not about how the code got there.
class BranchGapsTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  # Mutation coverage: the refused / accepted transmit paths and the missing-input
  # validation of the dispatch orchestrator are driven here.
  cover "Refineguard::CmmsDispatchService"

  # A real (non-simulated) adapter that refuses the hand-off.
  class RefusingAdapter < Refineguard::Cmms::Adapter
    def simulated?
      false
    end

    def budget_ms
      12
    end

    def transmit(_payload)
      Refineguard::Cmms::Transmission.new(transmitted: false, error: "connector refused")
    end
  end

  # A real (non-simulated) adapter that accepts the hand-off.
  class AcceptingAdapter < Refineguard::Cmms::Adapter
    def simulated?
      false
    end

    def budget_ms
      8
    end

    def transmit(_payload)
      Refineguard::Cmms::Transmission.new(transmitted: true, confirmed: false,
                                          confirmation: { "order" => "SAP-1" })
    end
  end

  setup do
    setup_runtime
    @incident = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, failure_mode: @failure_mode,
      incident_code: "INC-GAP", status: "Active", severity_level: "High",
      health_state: "Trip", detected_at: 1.day.ago, failure_mechanism: "Outer race spall"
    )
    @advisory = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-GAP",
      recommended_action: "Replace the outboard bearing pair.",
      status: PrescriptiveAdvisory::STATUS_READY, throttle_percentage: 70.0
    )
  end

  # ---- CMMS dispatch -------------------------------------------------------

  test "a refused transmission is reported and recorded as a failure" do
    with_adapter(RefusingAdapter.new) { dispatch(@advisory) }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal [ "connector refused" ], body["errors"]
    assert_equal "http", body["adapter"], "a real adapter must never be reported as simulated"
    assert_equal "Pending Sync", body["work_order"]["sync_status"],
                 "a failed transmit is not left looking dispatched"
    assert_nil body["work_order"]["confirmed_at"]
    assert_equal "connector refused", body["work_order"]["error_message"]
    assert_equal PrescriptiveAdvisory::STATUS_READY, @advisory.reload.status
  end

  test "a dispatch accepted by a real adapter is reported as http" do
    with_adapter(AcceptingAdapter.new) { dispatch(@advisory) }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "http", body["adapter"]
    refute body["simulated"]
    assert_equal 8, body["budget_ms"], "a timed adapter reports its measured budget"
  end

  test "a dispatch without a priority is refused before anything is transmitted" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/dispatch_work_order",
         params: {}.to_json, headers: json_headers(@planner)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"], "A maintenance priority is required"
    assert_equal 0, CmmsWorkOrder.where(prescriptive_advisory: @advisory).count
  end

  test "a dispatch on an advisory whose incident was withdrawn is refused" do
    @incident.discard

    dispatch(@advisory)

    assert_response :unprocessable_entity
    errors = JSON.parse(response.body)["errors"]
    assert_includes errors, "The advisory has no linked diagnostic incident"
    assert_includes errors, "The advisory has no linked asset"
  end

  test "a dispatch on an advisory whose asset was withdrawn is refused" do
    @asset.discard

    dispatch(@advisory)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"], "The advisory has no linked asset"
  end

  # ---- Derate approval -----------------------------------------------------

  test "approving a derate with no throttle keeps the recorded percentage" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
         params: {}.to_json, headers: json_headers(@superintendent)

    assert_response :success
    assert_equal 70.0, @advisory.reload.throttle_percentage
    assert_equal PrescriptiveAdvisory::STATUS_READY, @advisory.status
  end

  test "approving a derate on an advisory whose asset was withdrawn still logs the handover" do
    @asset.discard

    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
         params: { throttle_percentage: 65 }.to_json, headers: json_headers(@superintendent)

    assert_response :success
    assert_equal 65.0, @advisory.reload.throttle_percentage

    entry = ShiftLogEntry.order(:id).last
    assert_nil entry.asset_id
    assert_nil entry.plant_unit_id
    assert_match(/throttle to 65% flow/, entry.message)
  end

  test "the derate handover names the night shift before 06:00" do
    travel_to Time.zone.local(2026, 4, 2, 3, 0, 0) do
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
           params: { throttle_percentage: 60 }.to_json, headers: json_headers(@superintendent)
    end

    assert_response :success
    assert_equal "Night shift", ShiftLogEntry.order(:id).last.shift_label
  end

  test "the derate handover names the day shift before 18:00" do
    travel_to Time.zone.local(2026, 4, 2, 12, 0, 0) do
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
           params: { throttle_percentage: 60 }.to_json, headers: json_headers(@superintendent)
    end

    assert_response :success
    assert_equal "Day shift", ShiftLogEntry.order(:id).last.shift_label
  end

  # ---- Standby evaluation --------------------------------------------------

  test "a standby evaluation on an advisory whose incident was withdrawn is refused" do
    @incident.discard

    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/evaluate_standby",
         params: {}.to_json, headers: json_headers(@superintendent)

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"],
                    "Advisory has no linked diagnostic incident"
  end

  # ---- Diagnostic incidents ------------------------------------------------

  test "acknowledging a withdrawn incident answers 404" do
    @incident.discard

    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/acknowledge",
         params: {}.to_json, headers: json_headers(@engineer)

    assert_response :not_found
  end

  test "signing off a withdrawn incident answers 404" do
    @incident.discard

    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/sign_off",
         params: { finding: { root_cause: "x" } }.to_json, headers: json_headers(@specialist)

    assert_response :not_found
  end

  test "acknowledging an incident whose asset was withdrawn still records the transition" do
    @asset.discard
    incident = DiagnosticIncident.find(@incident.id)

    post "/api/demo-org/diagnostic_incidents/#{incident.id}/acknowledge",
         params: {}.to_json, headers: json_headers(@engineer)

    assert_response :success
    event = SecurityAuditEvent.where(action_type: "ACKNOWLEDGE").order(:id).last
    assert_nil event.details_json["asset_tag"]
    assert_equal DiagnosticIncident::STATUS_UNDER_INVESTIGATION, incident.reload.status
  end

  test "signing off propagates the finding to an advisory with no recommendation" do
    blank = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-BLANK",
      recommended_action: nil, status: PrescriptiveAdvisory::STATUS_READY
    )

    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/sign_off",
         params: { finding: { root_cause: "Outer race spall" } }.to_json,
         headers: json_headers(@specialist)

    assert_response :success
    assert_equal "Address Outer race spall on P-204A.", blank.reload.recommended_action
    assert_equal 2, JSON.parse(response.body)["propagated_advisories"].length
  end

  test "signing off still propagates when the asset was withdrawn" do
    blank = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-BLANK-2",
      recommended_action: nil, status: PrescriptiveAdvisory::STATUS_READY
    )
    @asset.discard

    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/sign_off",
         params: { finding: { root_cause: "Outer race spall" } }.to_json,
         headers: json_headers(@specialist)

    assert_response :success
    assert_equal "Address Outer race spall on .", blank.reload.recommended_action
  end

  # ---- System health -------------------------------------------------------

  test "the system health probe reports a degraded gateway and an unmeasured heartbeat" do
    HistorianConnector.create!(
      organization: @demo_org, connector_name: "PI Degraded", historian_type: "OSIsoft_PI",
      status: "Disconnected", connection_timeout_ms: 3000, polling_interval_seconds: 5
    )
    HistorianConnector.create!(
      organization: @demo_org, connector_name: "PHD Fresh", historian_type: "Honeywell_PHD",
      status: "Connected", connection_timeout_ms: 3000, polling_interval_seconds: 5,
      last_heartbeat: 2.minutes.ago
    )

    get "/api/demo-org/system_health", headers: json_headers(@admin)

    assert_response :success
    body = JSON.parse(response.body)

    gateway = body["services"].find { |service| service["name"] == "Ingestion gateway" }
    assert_equal "Degraded", gateway["status"]

    quiet = body["ingestion"]["connectors"].find { |row| row["name"] == "PI Degraded" }
    assert_nil quiet["last_heartbeat"]

    assert body["events"].any?, "the heartbeat that was recorded must appear in the event feed"
    refute_includes body["events"].join(" "), "PI Degraded"
  end

  test "the system health probe refuses a role with no connector access" do
    get "/api/demo-org/system_health", headers: json_headers(@planner)

    assert_response :forbidden
  end

  # ---- Dashboards ----------------------------------------------------------

  test "a tenant whose fleet is healthy averages above the attention band" do
    get "/api/runtime-other-org/dashboard/fleet_overview", headers: json_headers(@outsider)

    assert_response :success
    kpi = JSON.parse(response.body)["kpis"].find { |row| row["label"] == "Fleet health index" }
    assert_equal 91.0, kpi["value"]
    assert_equal "flat", kpi["direction"]
  end

  test "a tenant with no monitored assets reports no fleet average" do
    Asset.find_by!(asset_tag: "X-900A").discard

    get "/api/runtime-other-org/dashboard/fleet_overview", headers: json_headers(@outsider)

    assert_response :success
    kpi = JSON.parse(response.body)["kpis"].find { |row| row["label"] == "Fleet health index" }
    assert_nil kpi["value"]
    assert_equal "down", kpi["direction"]
  end

  # ---- Asset hierarchy -----------------------------------------------------

  test "an import with no file is refused before the importer runs" do
    post "/api/demo-org/assets/import", params: { import: "" }.to_json,
         headers: json_headers(@admin)

    assert_response :unprocessable_entity
    assert_equal [ "A CSV, JSON or XML file is required" ],
                 JSON.parse(response.body)["errors"]
  end

  test "a tenant with no assets publishes a valid hierarchy" do
    Asset.find_by!(asset_tag: "X-900A").discard

    post "/api/runtime-other-org/assets/validate_hierarchy", params: {}.to_json,
         headers: json_headers(@outsider)

    assert_response :success
    body = JSON.parse(response.body)
    assert body["valid"]
    assert body["published"]
    assert_empty body["errors"]

    event = SecurityAuditEvent.where(action_type: "ASSET_HIERARCHY_VALIDATE").order(:id).last
    assert_equal "info", event.severity
    assert_equal "Success", event.result
  end

  private

  # Minitest 6 ships no mocking library, so the adapter factory is swapped
  # explicitly and restored even when the request raises.
  def with_adapter(adapter)
    singleton = Refineguard::Cmms::Adapter.singleton_class
    singleton.alias_method :__configured_for, :for
    singleton.define_method(:for) { |*_args| adapter }
    yield
  ensure
    singleton.alias_method :for, :__configured_for
    singleton.remove_method :__configured_for
  end

  def dispatch(advisory)
    post "/api/demo-org/prescriptive_advisories/#{advisory.id}/dispatch_work_order",
         params: { priority: "Priority 2 - Urgent (Within 7 Days)" }.to_json,
         headers: json_headers(@planner)
  end
end
