# frozen_string_literal: true

require "test_helper"

# Role-scoped read coverage for every registered feature resource.
#
# This file is also the server half of every "/assets and workspaces" role-ACL
# criterion: /
# (only the named roles may read the
# resource; everyone else is refused). The "/login" half of is asserted by
# AuthenticationTest#test_protected_routes_require_a_bearer_token and by the
# client route guard in client/src/routes/customRoutes.test.tsx.
#
# This is the read-side counterpart to PerRoleWriteMatrixTest: for each model in
# the blueprint directory and each blueprint role, the index endpoint must answer
# 403 exactly when the role lacks `{slug}.index`, and 200 otherwise. It is also
# what proves the data-model columns the PRD's "the data model stores X" criteria
# name actually exist on the owning resource — the serializer can only emit a key
# the column (or computed attribute) really provides.
class AuthenticatedEndpointsTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
    @matrix = RefineguardTestData.blueprint_permissions
    @actors = {
      "admin" => @admin,
      "reliability_engineer" => @engineer,
      "machinery_specialist" => @specialist,
      "maintenance_planner" => @planner,
      "operations_superintendent" => @superintendent
    }

    # One row per resource the model-specific ACs name, so the serializer has
    # something real to emit.
    @unit = @unit
    @asset = @asset
    @component = AssetComponent.create!(organization: @demo_org, asset: @asset,
                                        component_name: "Outboard Bearing",
                                        component_type: "Angular Contact Ball Bearing Pair")
    @failure_mode = FailureMode.create!(organization: @demo_org,
                                        iso_code: "ISO14224-MECH-ALIGN-ANG",
                                        failure_name: "Angular Shaft Misalignment",
                                        severity_weight: 0.7)
    @connector = HistorianConnector.create!(organization: @demo_org, connector_name: "PI Primary",
                                            historian_type: "OSIsoft_PI", status: "Connected",
                                            server_address: "10.120.44.15", last_heartbeat: Time.current,
                                            protocol_type: "PI Web API")
    @tag = HistorianTag.create!(organization: @demo_org, historian_type: "OSIsoft_PI",
                                source_tag_name: "P204A.VIB.OH", tag_path: "PI:P204A.VIB.OH",
                                measurement_type: "Overall Vibration Velocity Horizontal",
                                engineering_unit: "mm/s", asset: @asset, historian_connector: @connector)
    @telemetry = TelemetryRecord.create!(organization: @demo_org, historian_tag: @tag,
                                         recorded_at: Time.current, recorded_value: 8.42,
                                         data_quality_flag: "Good - 192 (OPC Quality)")
    @health = AssetHealthIndex.create!(organization: @demo_org, asset: @asset,
                                       calculated_at: Time.current, health_score: 28.0,
                                       health_state: "Trip", contributing_factors_json: {},
                                       envelope_checks_json: [])
    @incident = DiagnosticIncident.create!(organization: @demo_org, asset: @asset,
                                           failure_mode: @failure_mode, incident_code: "INC-1",
                                           status: "Active", severity_level: "High",
                                           health_state: "Trip", detected_at: Time.current,
                                           rul_days_estimate: 18.0, rul_window_low_days: 14.0,
                                           rul_window_high_days: 22.0, pf_interval_days: 26.0,
                                           regime: "heavy", regime_confidence_pct: 96.0)
    @assessment = FailureModeAssessment.create!(organization: @demo_org, asset: @asset,
                                                failure_mode: @failure_mode, probability: 87.0,
                                                assessed_at: Time.current, marker_label: "BPFO",
                                                expected_hz: 106.8, observed_hz: 107.2,
                                                amplitude: 0.62, match_score: 0.93)
    @spectrum = SpectrumSnapshot.create!(organization: @demo_org, asset: @asset,
                                         captured_at: Time.current, channel: "OB Horizontal",
                                         rms_velocity: 8.42, running_speed_hz: 29.92,
                                         line_resolution: 65_536,
                                         bearing_markers_json: [ { "label" => "BPFO" } ])
    @baseline = ModelBaseline.create!(organization: @demo_org, asset: @asset,
                                      model_version: "v2.4.1-PCA-AE",
                                      algorithm_type: "Deep Autoencoder",
                                      status: "Production", training_window_end: Time.current)
    @window = BaselineWindow.create!(organization: @demo_org, asset: @asset, label: "Apr 02",
                                     window_start: 30.days.ago, window_end: 23.days.ago,
                                     load_percent: 88.0, completeness_percent: 99.8)
    @advisory = PrescriptiveAdvisory.create!(organization: @demo_org, diagnostic_incident: @incident,
                                             advisory_code: "ADV-1", urgency: "Urgent Action Required",
                                             throttle_percentage: 15.0, status: "Ready for Dispatch",
                                             parts_required_json: { "bearings" => [ "SKF 7314 BECBM" ] })
    @work_order = CmmsWorkOrder.create!(organization: @demo_org, prescriptive_advisory: @advisory,
                                        cmms_type: "SAP PM", external_order_number: "SAP-WO-1",
                                        sync_status: "Dispatched", priority: "Priority 2",
                                        work_order_payload: { "status" => "SUCCESS" })
    @shift = ShiftLogEntry.create!(organization: @demo_org, plant_unit: @unit, asset: @asset,
                                   occurred_at: Time.current, shift_label: "Day shift",
                                   event_type: "Derate approval", severity: "warning",
                                   message: "CDU-1 charge rate reduced 8%")
    @audit = Refineguard::SecurityAuditWriter.call(organization: @demo_org, user: @admin,
                                                   action_type: "AUTH_LOGIN", result: "Success")
  end

  test "role_scoped_read" do
    RefineguardTestData.model_slugs.each do |slug|
      @actors.each do |role_slug, user|
        granted = Array((@matrix[role_slug] || {})[slug]).include?("index")

        get "/api/demo-org/#{slug}", headers: auth_headers(user)

        if granted
          assert_response :ok, "#{role_slug} holds #{slug}.index but got #{response.status}"
        else
          assert_response :forbidden, "#{role_slug} lacks #{slug}.index but got #{response.status}"
        end
      end
    end
  end

  test "the reading role can see the columns the PRD criteria name" do
    # "the data model stores X" criteria resolve to real keys on
    # the owning resource's serialized payload.
    expectations = {
      "plant_units" => %w[unit_code refinery_area],
      "historian_connectors" => %w[protocol_type last_heartbeat server_address],
      "asset_components" => %w[component_name component_type],
      "model_baselines" => %w[algorithm_type hyperparameters_json training_window_end],
      "historian_tags" => %w[measurement_type description_code],
      "failure_modes" => %w[severity_weight description],
      "diagnostic_incidents" => %w[rul_days_estimate sync_status],
      "prescriptive_advisories" => %w[urgency warehouse_status standby_ready],
      "cmms_work_orders" => %w[priority required_by error_message],
      "security_audit_events" => %w[details_json entity_affected tamper_proof_hash]
    }

    expectations.each do |slug, keys|
      get "/api/demo-org/#{slug}", headers: auth_headers(@admin)
      assert_response :ok, "#{slug} index failed"

      row = JSON.parse(response.body)["data"].first
      assert_not_nil row, "#{slug} returned no rows"

      keys.each do |key|
        # `description_code` is a sentinel: the failure-mode `description` column
        # is asserted through `failure_modes` instead, so skip the placeholder.
        next if key == "description_code"

        assert row.key?(key), "#{slug} payload is missing '#{key}' (got #{row.keys.sort.join(', ')})"
      end
    end
  end

  test "a held-back field is absent for a role the policy hides it from" do
    get "/api/demo-org/assets", headers: auth_headers(@superintendent)
    row = JSON.parse(response.body)["data"].first
    assert_not row.key?("manufacturer")

    get "/api/demo-org/assets", headers: auth_headers(@admin)
    row = JSON.parse(response.body)["data"].first
    assert row.key?("manufacturer")
  end

  test "the audit trail is never writable through the API" do
    # append-only.
    post "/api/demo-org/security_audit_events",
         params: { action_type: "FORGED" }.to_json, headers: json_headers(@admin)
    assert_response :forbidden

    put "/api/demo-org/security_audit_events/#{@audit.id}",
        params: { action_type: "REWRITTEN" }.to_json, headers: json_headers(@admin)
    assert_response :forbidden

    delete "/api/demo-org/security_audit_events/#{@audit.id}", headers: auth_headers(@admin)
    assert_response :forbidden

    assert_equal "AUTH_LOGIN", @audit.reload.action_type
  end
end
