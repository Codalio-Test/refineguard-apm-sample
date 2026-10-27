# frozen_string_literal: true

require "test_helper"

# The non-CRUD endpoints, exercised end to end over the real HTTP surface.
class ExtrasEndpointsTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
    @connector = HistorianConnector.create!(
      organization: @demo_org, connector_name: "PI Primary", historian_type: "OSIsoft_PI",
      status: "Connected", poll_latency_ms: 380, connection_timeout_ms: 3000,
      polling_interval_seconds: 5, buffer_depth: 0, backfill_total: 100, backfill_committed: 100
    )
    @tag = HistorianTag.create!(
      organization: @demo_org, historian_type: "OSIsoft_PI", source_tag_name: "P204A.VIB.OH",
      tag_path: "PI:P204A.VIB.OH", engineering_unit: "mm/s", scan_rate_ms: 1000,
      deadband_val: 0.1, quality_status: "Good", stale_seconds: 8,
      last_value: 8.42, asset: @asset, historian_connector: @connector
    )
    @incident = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, failure_mode: @failure_mode,
      incident_code: "INC-24018", status: "Active", severity_level: "High",
      health_state: "Trip", rul_days_estimate: 8.5, rul_window_low_days: 6.0,
      rul_window_high_days: 11.0, pf_interval_days: 21.0, detected_at: 3.days.ago
    )
    @advisory = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-1",
      recommended_action: "Replace the outboard bearing pair.",
      parts_required_json: { "bearings" => [ "SKF 7314 BECBM Pair" ] },
      warehouse_status: "In stock", warehouse_bin: "C-14",
      status: "Ready for Dispatch", urgency: "Urgent Action Required", due_within_days: 6
    )
    AssetHealthIndex.create!(organization: @demo_org, asset: @asset, calculated_at: Time.current,
                             health_score: 28.0, health_state: "Trip", anomaly_confidence: 0.97,
                             reconstruction_error: 0.14, threshold_p99: 0.09,
                             contributing_factors_json: {
                               "vib_de_env" => { "status" => "severe_anomaly", "weight" => 0.45,
                                                 "z_score" => 3.82 },
                               "brg_nde_temp" => { "status" => "warning", "weight" => 0.30,
                                                   "z_score" => 2.45 }
                             })
  end

  # global KPI tallies + unit distribution.
  test "fleet overview returns the four prototype KPIs and the ISO tallies" do
    get "/api/demo-org/dashboard/fleet_overview", headers: auth_headers(@admin)
    assert_response :ok

    body = JSON.parse(response.body)
    labels = body["kpis"].map { |k| k["label"] }
    assert_equal [ "Monitored assets", "Requires attention", "Critical", "Fleet health index" ],
                 labels
    body["kpis"].each { |kpi| assert kpi.key?("value") && kpi.key?("note") && kpi.key?("direction") }

    assert_equal %w[Total\ Monitored Normal Alert Alarm Trip].sort,
                 body["totals"].keys.sort
    assert body["unit_risk"].any?
    assert_equal [ "CDU-1" ], body["unit_risk"].map { |u| u["name"] }
  end

  #
  test "active anomalies use the asset tag as the id for the locked navigation" do
    get "/api/demo-org/dashboard/active_anomalies", headers: auth_headers(@admin)
    assert_response :ok

    rows = JSON.parse(response.body)
    assert rows.any?
    row = rows.first
    assert_equal "P-204A", row["id"]
    assert_equal "critical", row["severity"]
    assert row.key?("issue") && row.key?("age")
  end

  # RUL x throughput across CDU/FCC/HCU/ALKY with the
  # verified derate advisory.
  test "the unit risk matrix returns rows, risk cells and a derate recommendation" do
    get "/api/demo-org/dashboard/unit_risk_matrix", headers: auth_headers(@admin)
    assert_response :ok

    body = JSON.parse(response.body)
    row = body["rows"].first
    %w[unit rate critical_train trip_probability derate exposure risk_cells derate_recommendation]
      .each { |key| assert row.key?(key), "row is missing #{key}" }
    assert_equal 4, body["risk_cells"].length
    assert_equal "Reduce charge rate by 8%.", body["derate_recommendation"]
  end

  # local DB/buffer/backup telemetry.
  test "system health reports measured metrics and labels the rest not measured" do
    @connector.update!(last_heartbeat: Time.current)

    get "/api/demo-org/system_health", headers: auth_headers(@admin)
    assert_response :ok

    body = JSON.parse(response.body)
    assert body["metrics"].any?
    assert body["services"].any?
    assert body["storage"].any?
    assert body["events"].any?
    assert body["ingestion"].key?("buffer_depth")
    assert body.key?("warnings")

    # Every metric declares whether it was measured, and an unmeasured metric
    # carries a null value rather than a synthesized number.
    body["metrics"].each do |metric|
      assert metric.key?("name") && metric.key?("status"), "metric is missing name/status"
      if metric["status"] == "not_measured"
        assert_nil metric["value"], "#{metric['name']} must not invent a value"
      else
        assert_equal "measured", metric["status"]
        assert metric["value"].present?
      end
    end
    assert_equal %w[Local\ DB API\ latency],
                 body["metrics"].select { |m| m["status"] == "measured" }.map { |m| m["name"] }

    # Nothing the process cannot observe is reported as measured.
    body["storage"].each do |volume|
      assert_equal "not_measured", volume["status"]
      assert_nil volume["percent"]
    end
    assert_equal "Not measured", body["backup"]["status"]
    assert_nil body["backup"]["last_run_at"]
    assert_equal "Not measured",
                 body["services"].find { |s| s["name"] == "Time-series database" }["status"]
  end

  # signed tamper-evident export in JSON and CSV.
  test "audit evidence exports as signed JSON and CSV" do
    Refineguard::SecurityAuditWriter.call(organization: @demo_org, user: @admin,
                                          action_type: "AUTH_LOGIN", result: "Success")

    get "/api/demo-org/security_audit_events/export?format=json", headers: auth_headers(@admin)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "sha256-over-ordered-hash-chain", body["signature_algorithm"]
    assert_equal "Chain verified", body["verification"]
    assert body["signature"].present?

    get "/api/demo-org/security_audit_events/export?format=csv", headers: auth_headers(@admin)
    assert_response :ok
    assert_match(/\A# RefineGuard APM tamper-evident audit export/, response.body)
    assert_match(/signature_sha256/, response.body)
  end

  # the trail is admin-only.
  test "only admin can export the audit trail" do
    get "/api/demo-org/security_audit_events/export?format=json", headers: auth_headers(@engineer)
    assert_response :forbidden
  end

  # the upload UI's import endpoint.
  test "historian tag mapping imports CSV and JSON and rejects bad rows" do
    csv = "historian_type,source_tag_name,engineering_unit,scan_rate_ms,deadband_val\n" \
          "OSIsoft_PI,NEW.TAG.1,mm/s,1000,0.1\n"
    post "/api/demo-org/historian_tags/import",
         params: { filename: "tags.csv", import: csv }.to_json, headers: json_headers(@admin)
    assert_response :created
    assert_equal 1, JSON.parse(response.body)["created"]
    assert HistorianTag.exists?(tag_path: "OSIsoft_PI:NEW.TAG.1")

    json = [ { historian_type: "Honeywell_PHD", source_tag_name: "NEW.TAG.2",
              tag_path: "PHD:NEW.TAG.2", engineering_unit: "degC", scan_rate_ms: 5000,
              deadband_val: 0.5 } ].to_json
    post "/api/demo-org/historian_tags/import",
         params: { filename: "tags.json", import: json }.to_json, headers: json_headers(@admin)
    assert_response :created

    bad = [ { historian_type: "Nope", source_tag_name: "", engineering_unit: "",
             scan_rate_ms: 0, deadband_val: "x" } ].to_json
    post "/api/demo-org/historian_tags/import",
         params: { filename: "bad.json", import: bad }.to_json, headers: json_headers(@admin)
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].length >= 4
  end

  # batch harness (<=50 tags inside the 2000 ms budget).
  test "the batch validation harness reports latency and per-tag outcomes" do
    post "/api/demo-org/historian_tags/validate_batch", params: {}.to_json,
         headers: json_headers(@admin)
    assert_response :ok

    body = JSON.parse(response.body)
    assert body["within_budget"]
    assert_operator body["duration_ms"], :<=, 2000
    assert_equal 1, body["passed"]
    assert body["results"].first.key?("value")
    assert body["results"].first.key?("latency_ms")
  end

  #
  test "the connector probe engages ring buffering and replays with zero loss" do
    post "/api/demo-org/historian_connectors/#{@connector.id}/test_connection",
         params: { simulated_latency_ms: 5000, pending_points: 3 }.to_json,
         headers: json_headers(@admin)
    assert_response :ok
    body = JSON.parse(response.body)
    assert body["ring_buffer_enabled"]
    assert_equal "Buffering", body["status"]
    assert_equal 3, body["buffered_points"]

    post "/api/demo-org/historian_connectors/#{@connector.id}/test_connection",
         params: { simulated_latency_ms: 300 }.to_json, headers: json_headers(@admin)
    body = JSON.parse(response.body)
    assert_equal "Connected", body["status"]
    assert_equal 3, body["replayed"]
    assert_equal 0, body["lost_points"]
  end

  # required taxonomy columns and the
  # duplicate/invalid-parent rejection that highlights the conflicting rows.
  test "asset hierarchy import accepts CSV/JSON/XML and rejects duplicates with row numbers" do
    xml = <<~XML
      <assets>
        <asset asset_tag="X-100" unit_id="CDU-1" equipment_class="Centrifugal Pump"
               driver_type="Electric Motor" bearing_de_model="SKF 6314 C3"
               bearing_nde_model="SKF 7314 BECBM" rated_rpm="1795" asset_name="XML pump"/>
      </assets>
    XML
    post "/api/demo-org/assets/import",
         params: { filename: "assets.xml", import: xml }.to_json, headers: json_headers(@admin)
    assert_response :created
    assert Asset.exists?(asset_tag: "X-100")

    json = [ { asset_tag: "X-101", unit_id: "CDU-1", equipment_class: "Centrifugal Pump",
              driver_type: "Electric Motor", bearing_de_model: "SKF 6314 C3",
              bearing_nde_model: "SKF 7314 BECBM", rated_rpm: 1795 } ].to_json
    post "/api/demo-org/assets/import",
         params: { filename: "assets.json", import: json }.to_json, headers: json_headers(@admin)
    assert_response :created

    duplicate = [ { asset_tag: "P-204A", unit_id: "CDU-1", equipment_class: "Centrifugal Pump",
                   driver_type: "Electric Motor", bearing_de_model: "A", bearing_nde_model: "B",
                   rated_rpm: 1 } ].to_json
    post "/api/demo-org/assets/import",
         params: { filename: "dup.json", import: duplicate }.to_json, headers: json_headers(@admin)
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal [ 1 ], body["conflict_rows"]
  end

  #
  test "hierarchy validation reports unique tags, parents and metadata" do
    post "/api/demo-org/assets/validate_hierarchy", params: {}.to_json,
         headers: json_headers(@admin)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["assets_checked"]
    assert body.key?("valid")
    assert body.key?("errors")
    assert body.key?("published")
  end

  # the tree read model the hierarchy explorer renders
  # (node selection populates the inspector and drills into the health workspace).
  test "the hierarchy tree rolls the worst child state up every level" do
    get "/api/demo-org/assets/hierarchy", headers: auth_headers(@admin)
    assert_response :ok

    tree = JSON.parse(response.body)["tree"]
    root = tree.first
    assert_equal "complex", root["node_type"]
    assert_equal "Trip", root["health_state"]
    unit_node = root["children"].first
    assert_equal "unit", unit_node["node_type"]
    assert_equal "CDU-1", unit_node["label"]
    tags = unit_node["children"].map { |c| c["asset_tag"] }
    assert_includes tags, "P-204A"
    assert_includes tags, "P-101B"
    critical = unit_node["children"].find { |c| c["asset_tag"] == "P-204A" }
    assert_equal "Trip", critical["health_state"]
    assert_equal "critical", critical["severity"]
  end

  #
  test "baseline training runs locally and promotion is gated" do
    window = BaselineWindow.create!(organization: @demo_org, asset: @asset, label: "Apr 02",
                                    window_start: 30.days.ago, window_end: 23.days.ago,
                                    load_percent: 88.0, completeness_percent: 99.8, selected: true)
    baseline = ModelBaseline.create!(organization: @demo_org, asset: @asset,
                                     model_version: "v3.8.0-PCA-AE",
                                     algorithm_type: "Deep Autoencoder", status: "Candidate")

    post "/api/demo-org/model_baselines/#{baseline.id}/train", params: {}.to_json,
         headers: json_headers(@specialist)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Trained", body["training_status"]
    assert body["gates_satisfied"]
    assert body["accuracy_metrics_json"].key?("precision")
    assert_equal 1, body["accuracy_metrics_json"]["windows_used"]

    post "/api/demo-org/model_baselines/#{baseline.id}/promote", params: {}.to_json,
         headers: json_headers(@specialist)
    assert_response :ok
    body = JSON.parse(response.body)
    assert body["promoted"]
    assert_equal "Production", baseline.reload.status
    assert_equal @specialist.id, baseline.approved_by_id

    assert SecurityAuditEvent.where(organization: @demo_org, action_type: "BASELINE_PROMOTION").exists?
  end

  test "promotion is refused when the gates are not satisfied" do
    baseline = ModelBaseline.create!(organization: @demo_org, asset: @asset,
                                     model_version: "v0.0.2-TEST",
                                     algorithm_type: "Deep Autoencoder", status: "Candidate")
    post "/api/demo-org/model_baselines/#{baseline.id}/promote", params: {}.to_json,
         headers: json_headers(@specialist)
    assert_response :unprocessable_entity
    assert_equal "Candidate", baseline.reload.status
  end

  # parts kit + warehouse bin,
  # the <=3000 ms transmission, the confirmation payload, and the timeout/reject
  # path that reverts the advisory with zero data lost.
  test "dispatch creates a work order with reservations, and a failure reverts the advisory" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/dispatch_work_order",
         params: { priority: "Priority 2 - Urgent (Within 7 Days)", cmms_type: "SAP PM",
                   required_by: (Time.current + 7.days).to_date.to_s }.to_json,
         headers: json_headers(@planner)
    assert_response :created
    body = JSON.parse(response.body)
    assert body["success"]
    assert_operator body["duration_ms"], :<=, 3000
    assert_equal "Dispatched", body["work_order"]["sync_status"]
    assert body["work_order"]["external_order_number"].present?
    assert body["work_order"]["material_reservations_json"].any?
    assert_equal "Dispatched", @advisory.reload.status

    failed = PrescriptiveAdvisory.create!(organization: @demo_org, diagnostic_incident: @incident,
                                          advisory_code: "ADV-2", status: "Ready for Dispatch")
    post "/api/demo-org/prescriptive_advisories/#{failed.id}/dispatch_work_order",
         params: { priority: "Priority 2 - Urgent (Within 7 Days)", simulate_failure: "true" }.to_json,
         headers: json_headers(@planner)
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_not body["success"]
    assert_match(/did not acknowledge/, body["errors"].first)
    assert_equal "Ready for Dispatch", failed.reload.status
    assert_equal "Pending Sync", CmmsWorkOrder.find_by(prescriptive_advisory: failed).sync_status
  end

  #
  test "sign-off persists the finding and propagates it to planning" do
    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/sign_off",
         params: { finding: { root_cause: "Stage 2 outer race spall",
                              evidence_summary: "Discrete BPFO peaks with 1X sidebands",
                              failure_mechanism: "Stage 2 Bearing Outer Race Spall",
                              finding_confidence: 0.89 } }.to_json,
         headers: json_headers(@specialist)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Signed off", body["finding_status"]
    assert_equal @specialist.id, body["signed_off_by_id"]
    assert_includes body["propagated_advisories"], @advisory.id
  end

  # The sign-off and the propagation into planning are one write: if a propagated
  # advisory cannot be saved, the finding must not be left half-applied.
  test "a propagation failure rolls back the finding sign-off" do
    # A legacy advisory with an out-of-range derate: saving it during propagation
    # fails validation, so the whole transaction must unwind.
    @advisory.update_column(:throttle_percentage, 250.0)
    original_finding_status = @incident.reload.finding_status

    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/sign_off",
         params: { finding: { root_cause: "Stage 2 outer race spall" } }.to_json,
         headers: json_headers(@specialist)

    assert_response :unprocessable_entity
    assert_match(/Throttle percentage/, JSON.parse(response.body)["errors"].join(" "))

    rolled_back = @incident.reload
    assert_nil rolled_back.signed_off_at, "the finding sign-off must have rolled back"
    assert_equal original_finding_status, rolled_back.finding_status
    assert_not_equal "Signed off", rolled_back.finding_status
  end

  #
  test "acknowledgement persists the transition and writes an audit row" do
    post "/api/demo-org/diagnostic_incidents/#{@incident.id}/acknowledge", params: {}.to_json,
         headers: json_headers(@engineer)
    assert_response :ok
    assert_equal "Under Investigation", @incident.reload.status
    assert_equal @engineer.id, @incident.acknowledged_by_id
    assert_not_nil @incident.acknowledged_at

    assert SecurityAuditEvent.where(organization: @demo_org, action_type: "ACKNOWLEDGE").exists?
  end

  # the superintendent sign-off lands in the shift handover log.
  test "derate approval writes the restriction to the shift handover log" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
         params: { throttle_percentage: 70 }.to_json, headers: json_headers(@superintendent)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 70.0, body["throttle_percentage"]
    assert_equal @superintendent.id, body["derate_approved_by_id"]
    assert body["shift_log_written"]
    assert ShiftLogEntry.where(organization: @demo_org, event_type: "Derate approval").exists?
  end

  # a derate is a percentage of design flow: only 0–100 is a valid operating point.
  test "derate approval rejects an out-of-range throttle with 422" do
    [ 250, -40 ].each do |throttle|
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
           params: { throttle_percentage: throttle }.to_json, headers: json_headers(@superintendent)
      assert_response :unprocessable_entity,
                      "throttle #{throttle} must be rejected"
      assert_match(/Throttle percentage/i, JSON.parse(response.body)["errors"].join(" "))
      assert_nil @advisory.reload.derate_approved_at
    end

    [ 0, 100 ].each do |throttle|
      post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/approve_derate",
           params: { throttle_percentage: throttle }.to_json, headers: json_headers(@superintendent)
      assert_response :ok, "throttle #{throttle} is a valid operating point"
      assert_equal throttle.to_f, JSON.parse(response.body)["throttle_percentage"]
    end
  end

  #
  test "a standby switchover advisory carries the check evidence" do
    standby = Asset.create!(organization: @demo_org, asset_tag: "P-204B",
                            asset_name: "Crude charge pump B", health_state: "Normal",
                            monitored: true, last_sample_at: Time.current - 5.seconds,
                            data_completeness_pct: 99.4)

    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/evaluate_standby",
         params: {}.to_json, headers: json_headers(@superintendent)
    assert_response :created

    body = JSON.parse(response.body)
    assert_equal standby.id, body["standby_asset_id"]
    assert body["standby_ready"]
    assert_equal 4, body["standby_checks_json"].length
    assert body["standby_checks_json"].all? { |c| c["passed"] }
  end

  test "standby evaluation reports when no twin exists" do
    post "/api/demo-org/prescriptive_advisories/#{@advisory.id}/evaluate_standby",
         params: {}.to_json, headers: json_headers(@superintendent)
    assert_response :unprocessable_entity
    assert_match(/No standby twin/, JSON.parse(response.body)["errors"].first)
  end

  test "extras endpoints require authentication and organization membership" do
    get "/api/demo-org/dashboard/fleet_overview"
    assert_response :unauthorized

    get "/api/demo-org/dashboard/fleet_overview", headers: auth_headers(@outsider)
    assert_response :not_found
  end

  test "the operations superintendent scope narrows the anomaly queue to open incidents" do
    # The conditional-access Extra: Scopes::DiagnosticIncidentScope narrows
    # resolved incidents out for this role only, on top of tenancy and policy.
    resolved = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, incident_code: "INC-OLD", status: "Resolved",
      severity_level: "Low", health_state: "Normal", detected_at: 40.days.ago
    )

    get "/api/demo-org/dashboard/active_anomalies", headers: auth_headers(@superintendent)
    assert_response :ok
    ids = JSON.parse(response.body).map { |row| row["record_id"] }
    assert_not_includes ids, resolved.id

    get "/api/demo-org/diagnostic_incidents", headers: auth_headers(@engineer)
    assert_response :ok
    slugs = JSON.parse(response.body)["data"].map { |r| r["incident_code"] }
    assert_includes slugs, "INC-OLD"
  end
end
