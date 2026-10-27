# frozen_string_literal: true

require "test_helper"

# CMMS dispatch: idempotency, honest adapter surfacing and database-allocated
# external order numbers
class CmmsDispatchTest < ActionDispatch::IntegrationTest
  # Mutation coverage: the dispatch orchestrator's idempotency, validation and
  # adapter surfacing are driven end to end here.
  cover "Refineguard::CmmsDispatchService"

  setup do
    setup_runtime
    @incident = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, failure_mode: @failure_mode,
      incident_code: "INC-DISPATCH", status: "Active", severity_level: "High",
      health_state: "Trip", detected_at: 1.day.ago
    )
    @advisory = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-DISPATCH",
      recommended_action: "Replace the outboard bearing pair.",
      parts_required_json: { "bearings" => [ "SKF 7314 BECBM Pair" ] },
      status: "Ready for Dispatch"
    )
  end

  test "dispatching twice creates one work order and refuses the second with 409" do
    dispatch(@advisory)
    assert_response :created
    assert_equal 1, work_orders_for(@advisory).count

    dispatch(@advisory)
    assert_response :conflict
    assert_equal 1, work_orders_for(@advisory).count,
                 "the second dispatch must not create a duplicate work order"
  end

  test "two concurrent dispatches of the same advisory produce exactly one work order" do
    # Two in-memory handles on the same row, both read while it is still "Ready
    # for Dispatch" — exactly the state two concurrent requests each hold when
    # they run the "already dispatched?" check. Without the row lock in the
    # service, both pass the check and each writes a work order.
    first = PrescriptiveAdvisory.find(@advisory.id)
    second = PrescriptiveAdvisory.find(@advisory.id)

    first_result = Refineguard::CmmsDispatchService.dispatch(
      advisory: first, user: @planner, priority: "Priority 2 - Urgent (Within 7 Days)"
    )
    second_result = Refineguard::CmmsDispatchService.dispatch(
      advisory: second, user: @planner, priority: "Priority 2 - Urgent (Within 7 Days)"
    )

    assert first_result.success
    assert second_result.conflict, "the racing dispatch must be refused as a conflict"
    assert_equal 1, work_orders_for(@advisory).count
    assert_equal PrescriptiveAdvisory::STATUS_DISPATCHED, @advisory.reload.status
  end

  test "the simulated adapter is surfaced and never confirms the work order" do
    dispatch(@advisory)
    assert_response :created

    body = JSON.parse(response.body)
    assert body["success"]
    assert body["simulated"], "the response must flag the simulated adapter"
    assert_equal "simulated", body["adapter"]
    assert_nil body["budget_ms"], "no network call is timed, so there is no budget claim"
    assert_nil body["work_order"]["confirmed_at"], "a simulated dispatch must not confirm"
    assert_equal CmmsWorkOrder::SYNC_DISPATCHED, body["work_order"]["sync_status"]
  end

  test "external order numbers are allocated by the database sequence" do
    second = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-DISPATCH-2",
      recommended_action: "Rebalance the impeller.", status: "Ready for Dispatch"
    )

    dispatch(@advisory)
    dispatch(second)

    numbers = CmmsWorkOrder.pluck(:external_order_number)
    assert_equal numbers.length, numbers.uniq.length, "sequence numbers must be unique"
    assert(numbers.all? { |number| number.match?(/\ASAP-WO-\d{6}\z/) },
           "unexpected order numbers: #{numbers.inspect}")
  end

  private

  def dispatch(advisory)
    post "/api/demo-org/prescriptive_advisories/#{advisory.id}/dispatch_work_order",
         params: { priority: "Priority 2 - Urgent (Within 7 Days)", cmms_type: "SAP PM" }.to_json,
         headers: json_headers(@planner)
  end

  def work_orders_for(advisory)
    CmmsWorkOrder.where(prescriptive_advisory: advisory)
  end
end
