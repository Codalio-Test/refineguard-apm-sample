# frozen_string_literal: true

require "test_helper"

# The single error envelope.
#
# Every custom endpoint — the 401/403/404 gates in `Api::BaseController` and the
# validation failures inside an action — answers with
# `{ "errors": ["message", ...] }` and the matching status, so a client never has
# to guess whether the failure arrived as `message` or `errors`.
class ErrorContractTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
    @incident = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, failure_mode: @failure_mode,
      incident_code: "INC-ERR", status: "Active", severity_level: "High",
      health_state: "Trip", detected_at: 1.day.ago
    )
    @advisory = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-ERR",
      recommended_action: "Replace the outboard bearing pair.", status: "Ready for Dispatch"
    )
  end

  test "an unauthenticated custom request is 401 with the errors envelope" do
    get "/api/demo-org/dashboard/fleet_overview"

    assert_response :unauthorized
    assert_equal [ "Unauthenticated." ], JSON.parse(response.body)["errors"]
  end

  test "a forbidden custom action is 403 with the errors envelope" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
         params: { throttle_percentage: 70 }.to_json, headers: json_headers(@planner)

    assert_response :forbidden
    assert_equal [ "This action is unauthorized." ], JSON.parse(response.body)["errors"]
  end

  test "a missing custom record is 404 with the errors envelope" do
    post "/api/demo-org/prescriptive_advisories/0/dispatch_work_order",
         params: { priority: "P2" }.to_json, headers: json_headers(@planner)

    assert_response :not_found
    assert_equal [ "Advisory not found" ], JSON.parse(response.body)["errors"]
  end

  test "an unknown organization is 404 with the errors envelope" do
    get "/api/no-such-org/dashboard/fleet_overview", headers: auth_headers(@admin)

    assert_response :not_found
    assert_equal [ "Organization not found" ], JSON.parse(response.body)["errors"]
  end

  test "a validation failure inside an action is 422 with the errors envelope" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
         params: { throttle_percentage: 250 }.to_json, headers: json_headers(@superintendent)

    assert_response :unprocessable_entity
    errors = JSON.parse(response.body)["errors"]
    assert_kind_of Array, errors
    assert errors.any? { |message| message.include?("Throttle percentage") }
  end

  # The import endpoints answer a missing upload with the SAME envelope, not a
  # per-field object: one shape for every custom endpoint means the client can
  # read `errors` without knowing which action failed.
  test "a missing import upload is 422 with the array errors envelope" do
    [
      [ "/api/demo-org/assets/import", "A CSV, JSON or XML file is required" ],
      [ "/api/demo-org/historian_tags/import", "A CSV or JSON file is required" ]
    ].each do |path, message|
      post path, params: { import: "" }.to_json, headers: json_headers(@admin)

      assert_response :unprocessable_entity
      assert_equal [ message ], JSON.parse(response.body)["errors"],
                   "#{path} must answer with the shared errors array"
    end
  end
end
