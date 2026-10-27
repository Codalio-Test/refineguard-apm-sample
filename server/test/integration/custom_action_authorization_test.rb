# frozen_string_literal: true

require "test_helper"

# Authorization of every custom (non-CRUD) endpoint, in both directions
# Each role-specific action must gate on its OWN policy method rather than the
# generic `update?`, so a role that may edit an ordinary field does not silently
# inherit a dispatch/sign-off/derate capability. For each action this asserts
# a role that may perform it is NOT refused (never 403), and
# every other role IS refused (403)
class CustomActionAuthorizationTest < ActionDispatch::IntegrationTest
  # Mutation coverage: the deny/allow direction of every custom-action gate is
  # asserted here, role by role. AssetPolicy is included for its `import?` gate
  # (the asset-hierarchy import), which the endpoint tests below exercise.
  cover "AssetPolicy"
  cover "PrescriptiveAdvisoryPolicy"
  cover "DiagnosticIncidentPolicy"
  cover "HistorianConnectorPolicy"
  cover "CmmsWorkOrderPolicy"
  cover "SecurityAuditEventPolicy"

  setup do
    setup_runtime
    @actors = {
      "admin" => @admin,
      "reliability_engineer" => @engineer,
      "machinery_specialist" => @specialist,
      "maintenance_planner" => @planner,
      "operations_superintendent" => @superintendent
    }

    @connector = HistorianConnector.create!(
      organization: @demo_org, connector_name: "PI Primary", historian_type: "OSIsoft_PI",
      status: "Connected", connection_timeout_ms: 3000, polling_interval_seconds: 5,
      backfill_total: 10, backfill_committed: 10
    )
    @incident = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, failure_mode: @failure_mode,
      incident_code: "INC-AUTH", status: "Active", severity_level: "High",
      health_state: "Trip", detected_at: 1.day.ago
    )
    @advisory = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-AUTH",
      recommended_action: "Replace the outboard bearing pair.",
      parts_required_json: { "bearings" => [ "SKF 7314 BECBM Pair" ] },
      status: "Ready for Dispatch", urgency: "Routine", due_within_days: 5
    )
    @baseline = ModelBaseline.create!(
      organization: @demo_org, asset: @asset, model_version: "v9.9.9-AUTH",
      algorithm_type: "Deep Autoencoder", status: "Candidate"
    )
  end

  # Prescriptive advisories

  test "derate sign-off is limited to the operations superintendent" do
    assert_action_access("derate sign-off", %w[operations_superintendent]) do |user|
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
           params: { throttle_percentage: 70 }.to_json, headers: json_headers(user)
    end
  end

  test "work-order dispatch is limited to planning and reliability" do
    assert_action_access("work-order dispatch",
                         %w[admin maintenance_planner reliability_engineer]) do |user|
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/dispatch_work_order",
           params: { priority: "Priority 2 - Urgent (Within 7 Days)" }.to_json,
           headers: json_headers(user)
    end
  end

  test "standby evaluation is limited to operations and reliability" do
    assert_action_access("standby evaluation",
                         %w[admin reliability_engineer operations_superintendent]) do |user|
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/evaluate_standby",
           params: {}.to_json, headers: json_headers(user)
    end
  end

  # Diagnostic incidents

  test "acknowledgement is limited to the reliability engineer" do
    assert_action_access("acknowledgement", %w[admin reliability_engineer]) do |user|
      post "/api/demo-org/diagnostic_incidents/#{@incident.id}/acknowledge",
           params: {}.to_json, headers: json_headers(user)
    end
  end

  test "diagnostic finding sign-off is limited to the vibration specialist" do
    assert_action_access("finding sign-off", %w[admin machinery_specialist]) do |user|
      post "/api/demo-org/diagnostic_incidents/#{@incident.id}/sign_off",
           params: { finding: { root_cause: "Outer race spall",
                                evidence_summary: "Discrete BPFO peaks",
                                failure_mechanism: "Bearing Outer Race Spall",
                                finding_confidence: 0.9 } }.to_json,
           headers: json_headers(user)
    end
  end

  # Model lifecycle

  test "baseline training is limited to the vibration specialist" do
    assert_action_access("baseline training", %w[admin machinery_specialist]) do |user|
      post "/api/demo-org/model_baselines/#{@baseline.id}/train", params: {}.to_json,
           headers: json_headers(user)
    end
  end

  test "baseline promotion is limited to the vibration specialist" do
    assert_action_access("baseline promotion", %w[admin machinery_specialist]) do |user|
      post "/api/demo-org/model_baselines/#{@baseline.id}/promote", params: {}.to_json,
           headers: json_headers(user)
    end
  end

  # Ingestion

  test "historian connector probing is admin-only" do
    assert_action_access("connector probe", %w[admin]) do |user|
      post "/api/demo-org/historian_connectors/#{@connector.id}/test_connection",
           params: { simulated_latency_ms: 400 }.to_json, headers: json_headers(user)
    end
  end

  test "historian tag import is limited to the roles that may create tags" do
    csv = "historian_type,source_tag_name,engineering_unit,scan_rate_ms,deadband_val\n" \
          "OSIsoft_PI,AUTH.TAG,mm/s,1000,0.1\n"
    assert_action_access("historian tag import", %w[admin machinery_specialist]) do |user|
      post "/api/demo-org/historian_tags/import",
           params: { filename: "tags.csv", import: csv }.to_json, headers: json_headers(user)
    end
  end

  test "asset hierarchy import is limited to the roles that may create assets" do
    json = [ { asset_tag: "AUTH-1", unit_id: "CDU-1", equipment_class: "Centrifugal Pump",
              driver_type: "Electric Motor", bearing_de_model: "SKF 6314 C3",
              bearing_nde_model: "SKF 7314 BECBM", rated_rpm: 1795 } ].to_json
    assert_action_access("asset hierarchy import", %w[admin machinery_specialist]) do |user|
      post "/api/demo-org/assets/import",
           params: { filename: "assets.json", import: json }.to_json, headers: json_headers(user)
    end
  end

  test "the tag validation harness follows the tag read grant" do
    assert_action_access("tag validation harness",
                         %w[admin reliability_engineer machinery_specialist maintenance_planner]) do |user|
      post "/api/demo-org/historian_tags/validate_batch", params: {}.to_json,
           headers: json_headers(user)
    end
  end

  # Governance

  test "audit evidence export is admin-only" do
    assert_action_access("audit export", %w[admin]) do |user|
      get "/api/demo-org/security_audit_events/export?format=json", headers: auth_headers(user)
    end
  end

  # Idle session on a CUSTOM endpoint

  test "a token idle for two hours is rejected by a custom endpoint" do
    @admin.update_columns(token_last_used_at: 2.hours.ago)
    token = @admin.reload.api_token

    get "/api/demo-org/dashboard/fleet_overview",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
    # A custom endpoint answers even this 401 with the shared errors envelope.
    assert_equal [ "Session expired after 30 minutes of inactivity." ],
                 JSON.parse(response.body)["errors"]
  end

  private

  def assert_action_access(name, allowed)
    @actors.each do |role, user|
      yield user
      if allowed.include?(role)
        assert_not_equal 403, response.status,
                         "#{role} should pass the #{name} gate but got 403: #{response.body[0, 160]}"
      else
        assert_equal 403, response.status,
                     "#{role} should be refused the #{name} gate but got #{response.status}"
      end
    end
  end
end
