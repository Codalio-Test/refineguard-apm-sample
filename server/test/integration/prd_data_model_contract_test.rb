# frozen_string_literal: true

require "test_helper"

# "The data model stores X" criteria, one assertion group per criterion, read back
# through the real serialized API payload of the owning resource.
#
# These are the 34 criteria the PRD states as bare column names; the blueprint
# generated the columns, and this suite proves each one is actually reachable on
# the wire (a column the serializer never emits is a column the SPA cannot use).
#
# details_json entity_affected
# email approved
# last_name first_name
# profile_completed
# description last_heartbeat server_address
# component_name component_type algorithm_type
# urgency
# unit_code refinery_area protocol_type
# criticality_class hyperparameters_json
# measurement_type
# severity_weight
# sync_status
# rul_days_estimate
# training_window_end
# gaps asset twin + live state tag quality/mapping
# connector telemetry incident finding/RUL band
# spectrum payloads advisory steps/warehouse/standby
# work-order dispatch owning-model attribution
# air-gap badge columns
class PrdDataModelContractTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime

    @connector = HistorianConnector.create!(
      organization: @demo_org, connector_name: "PI Primary", historian_type: "OSIsoft_PI",
      protocol_type: "OSIsoft PI AF / Web API", server_address: "10.120.44.15",
      endpoint_url: "https://10.120.44.15:5450", port: 5450,
      status: "Connected", last_heartbeat: Time.current, poll_latency_ms: 380,
      polling_interval_seconds: 5, buffer_depth: 3, backfill_queue: 0,
      backfill_total: 184, backfill_committed: 184, ring_buffer_enabled: false,
      connection_timeout_ms: 3000, credentials_ref: "ot-secret/pi-primary"
    )
    @component = AssetComponent.create!(
      organization: @demo_org, asset: @asset, component_name: "Outboard Bearing",
      component_type: "Angular Contact Ball Bearing Pair", position: "Pump OB",
      bearing_model: "SKF 7314 BECBM", health_state: "Alarm"
    )
    @tag = HistorianTag.create!(
      organization: @demo_org, asset: @asset, asset_component: @component,
      historian_connector: @connector, historian_type: "OSIsoft_PI",
      source_tag_name: "P204A.VIB.OH", tag_path: "PI:P204A.VIB.OH",
      measurement_type: "Overall Vibration Velocity Horizontal", engineering_unit: "mm/s",
      scan_rate_ms: 1000, deadband_val: 0.1, quality_status: "Good", last_value: 8.42,
      last_validated_at: Time.current, stale_seconds: 8, mapped: true, mapping_state: "Mapped",
      compatible: true
    )
    @incident = DiagnosticIncident.create!(
      organization: @demo_org, asset: @asset, failure_mode: @failure_mode,
      incident_code: "INC-24018", status: "Active", severity_level: "High", health_state: "Trip",
      rul_days_estimate: 8.5, rul_window_low_days: 6.0, rul_window_high_days: 11.0,
      rul_confidence_pct: 90.0, pf_interval_days: 21.0, regime: "heavy",
      regime_confidence_pct: 96.0, root_cause: "Stage 2 outer race spall",
      evidence_summary: "Discrete BPFO peaks with 1X sidebands",
      failure_mechanism: "Stage 2 Bearing Outer Race Spall", finding_confidence: 0.89,
      finding_status: "Signed off", detected_at: 3.days.ago
    )
    @baseline = ModelBaseline.create!(
      organization: @demo_org, asset: @asset, model_version: "v2.4.1-PCA-AE",
      algorithm_type: "Deep Autoencoder & Principal Component Residual Tracking",
      training_window_start: 90.days.ago, training_window_end: 30.days.ago,
      hyperparameters_json: { "fft_bins" => 512, "latent_dim" => 8 },
      accuracy_metrics_json: { "precision" => 0.94, "recall" => 0.91 },
      gates_json: { "precision" => true, "false_alarms" => true },
      status: "Production", training_status: "Trained", training_progress: 100,
      is_active: true
    )
    @window = BaselineWindow.create!(
      organization: @demo_org, asset: @asset, model_baseline: @baseline, label: "Apr 02",
      window_start: 30.days.ago, window_end: 23.days.ago, load_percent: 88.0,
      completeness_percent: 99.8, selected: true
    )
    @advisory = PrescriptiveAdvisory.create!(
      organization: @demo_org, diagnostic_incident: @incident, advisory_code: "ADV-1",
      recommended_action: "Replace the outboard bearing pair.",
      action_steps_json: [ "Isolate the pump", "Replace bearing pair", "Restore seal flush" ],
      parts_required_json: { "bearings" => [ "SKF 7314 BECBM Pair" ] },
      warehouse_status: "In stock", warehouse_bin: "C-14", parts_lead_time_days: 3,
      throttle_percentage: 15.0, urgency: "Urgent Action Required",
      status: "Ready for Dispatch", due_within_days: 6,
      standby_asset_id: @healthy_asset.id, standby_ready: true,
      standby_checks_json: [ { "key" => "lube_oil_level", "passed" => true } ]
    )
    @work_order = CmmsWorkOrder.create!(
      organization: @demo_org, prescriptive_advisory: @advisory, user: @planner,
      cmms_type: "SAP PM", external_order_number: "SAP-WO-884210", sync_status: "Dispatched",
      priority: "Priority 2 - Urgent (Within 7 Days)", required_by: (Time.current + 7.days).to_date,
      dispatched_at: Time.current, confirmed_at: Time.current,
      work_order_payload: { "order_type" => "PM02" },
      material_reservations_json: [ { "item" => "SKF 7314 BECBM Pair", "warehouse_bin" => "C-14" } ]
    )
    @spectrum = SpectrumSnapshot.create!(
      organization: @demo_org, asset: @asset, captured_at: Time.current,
      channel: "OB Horizontal", line_resolution: 65_536, sample_rate_hz: 25_600.0,
      rms_velocity: 8.42, running_speed_hz: 29.92, cursor_hz: 106.8, cursor_amplitude: 0.62,
      cursor_order: 3.57, delta_baseline: 0.31, waterfall_horizon_days: 30,
      spectrum_json: [ { "hz" => 29.92, "amplitude" => 0.42 }, { "hz" => 106.8, "amplitude" => 0.62 } ],
      harmonics_json: [ { "order" => 1, "hz" => 29.92, "relative_amplitude" => 0.42 } ],
      bearing_markers_json: [ { "label" => "BPFO", "expected_hz" => 106.8, "order" => 3.57 } ],
      waterfall_json: [ { "day" => 0, "spectrum" => [ { "hz" => 29.92, "amplitude" => 0.3 } ] } ],
      orbit_json: [ { "angle" => 0, "x" => 1.0, "y" => 0.1 } ]
    )
    @audit = Refineguard::SecurityAuditWriter.call(
      organization: @demo_org, user: @admin, action_type: "DISPATCH_WORK_ORDER",
      entity_affected: "CmmsWorkOrder:#{@work_order.id}", severity: "warning",
      result: "Success", details: { "target_system" => "SAP PM RFC_GATEWAY" }
    )
  end

  def index_rows(slug, user = @admin)
    get "/api/demo-org/#{slug}", headers: auth_headers(user)
    assert_response :ok, "#{slug} index returned #{response.status}"
    JSON.parse(response.body)["data"]
  end

  def row_matching(slug, key, value, user = @admin)
    row = index_rows(slug, user).find { |candidate| candidate[key] == value }
    assert_not_nil row, "#{slug} index has no row where #{key}=#{value.inspect}"
    row
  end

  # the audit row carries details_json and entity_affected.
  test "security audit events expose entity_affected and details_json" do
    row = row_matching("security_audit_events", "id", @audit.id)

    assert_equal "CmmsWorkOrder:#{@work_order.id}", row["entity_affected"]
    assert_equal({ "target_system" => "SAP PM RFC_GATEWAY" }, row["details_json"])
    assert row["tamper_proof_hash"].present?
  end

  # the identity columns.
  test "the user identity exposes email, approved, first_name and last_name" do
    row = row_matching("users", "email", @admin.email)

    assert_equal @admin.email, row["email"]
    assert_equal true, row["approved"]
    assert_equal "Test", row["first_name"]
    assert_equal "User", row["last_name"]
    # The bearer token never leaves the server.
    assert_not row.key?("api_token")
  end

  # profile completed is a computed attribute on the identity.
  test "profile_completed is emitted as a computed attribute on the user identity" do
    complete = row_matching("users", "email", @admin.email)
    assert_equal true, complete["profile_completed"]

    incomplete = User.create!(name: "No Names", email: "incomplete@example.com",
                              password: "password", first_name: nil, last_name: nil)
    UserRole.create!(user: incomplete, organization: @demo_org, role: @roles["reliability_engineer"])
    row = row_matching("users", "email", "incomplete@example.com")
    assert_equal false, row["profile_completed"]
  end

  # FailureMode description and severity weight.
  test "failure modes expose description and severity_weight" do
    failure_mode = FailureMode.create!(
      organization: @demo_org, iso_code: "ISO14224-HYDR-CAVIT-SUCT",
      failure_name: "Hydraulic Cavitation & Recirculation", equipment_category: "Centrifugal Pump",
      severity_weight: 0.8,
      description: "NPSH margin deficiency producing broadband noise in the 2-8 kHz band"
    )
    row = row_matching("failure_modes", "id", failure_mode.id)

    assert_equal 0.8, row["severity_weight"]
    assert_match(/NPSH margin/, row["description"])
  end

  # the connector telemetry columns the
  # air-gap badges in the locked shell read.
  test "historian connectors expose protocol, address, heartbeat, latency and buffer depth" do
    row = row_matching("historian_connectors", "id", @connector.id)

    assert_equal "OSIsoft PI AF / Web API", row["protocol_type"]
    assert_equal "10.120.44.15", row["server_address"]
    assert row["last_heartbeat"].present?
    assert_equal 380, row["poll_latency_ms"]
    assert_equal 3, row["buffer_depth"].to_i
    assert_equal 184, row["backfill_total"].to_i
    assert_equal 184, row["backfill_committed"].to_i
    assert_equal 3000, row["connection_timeout_ms"]
    # The credential *reference* is stored but never serialized (only a reference
    # exists — never a plaintext secret on the wire).
    assert_not row.key?("credentials_ref")
  end

  # AssetComponent name and type.
  test "asset components expose component_name and component_type" do
    row = row_matching("asset_components", "id", @component.id)

    assert_equal "Outboard Bearing", row["component_name"]
    assert_equal "Angular Contact Ball Bearing Pair", row["component_type"]
  end

  # the ModelBaseline training contract.
  test "model baselines expose algorithm_type, hyperparameters_json and training_window_end" do
    row = row_matching("model_baselines", "id", @baseline.id)

    assert_match(/Deep Autoencoder/, row["algorithm_type"])
    assert_equal 512, row["hyperparameters_json"]["fft_bins"]
    assert row["training_window_end"].present?
  end

  # the advisory contract the action centre renders.
  test "prescriptive advisories expose urgency, steps, warehouse and standby evidence" do
    row = row_matching("prescriptive_advisories", "id", @advisory.id)

    assert_equal "Urgent Action Required", row["urgency"]
    assert_equal 3, row["action_steps_json"].length
    assert_equal "In stock", row["warehouse_status"]
    assert_equal "C-14", row["warehouse_bin"]
    assert_equal 3, row["parts_lead_time_days"]
    assert_equal "Ready for Dispatch", row["status"]
    assert_equal 6, row["due_within_days"]
    assert_equal @healthy_asset.id, row["standby_asset_id"]
    assert_equal true, row["standby_ready"]
    assert_equal "lube_oil_level", row["standby_checks_json"].first["key"]
  end

  # PlantUnit unit_code and refinery_area.
  test "plant units expose unit_code and refinery_area" do
    @unit.update!(refinery_area: "Area A - Crude Fractionation")
    row = row_matching("plant_units", "id", @unit.id)

    assert_equal "CDU-1", row["unit_code"]
    assert_equal "Area A - Crude Fractionation", row["refinery_area"]
  end

  # the extended ISO 14224 twin + live-state columns.
  test "assets expose criticality_class and the extended digital-twin columns" do
    @asset.update!(
      criticality_class: "A - Severe/Critical", driver_type: "Electric Motor",
      manufacturer: "Sulzer", commissioned_on: Date.new(2019, 4, 2), rated_rpm: 1795.0,
      rated_flow_m3h: 420.0, max_bearing_temp_c: 105.0,
      last_tag_validation_at: Time.current, motor_current_a: 318.0
    )
    row = row_matching("assets", "id", @asset.asset_tag)

    assert_equal "A - Severe/Critical", row["criticality_class"]
    assert_equal "Electric Motor", row["driver_type"]
    assert_equal "Sulzer", row["manufacturer"]
    assert row["commissioned_on"].present?
    assert_equal 1795.0, row["rated_rpm"]
    assert_equal 420.0, row["rated_flow_m3h"]
    assert_equal 105.0, row["max_bearing_temp_c"]
    assert row["last_tag_validation_at"].present?
    assert_equal 318.0, row["motor_current_a"]
    assert_equal "SKF 6314 C3", row["bearing_de_model"]
    assert_equal "SKF 7314 BECBM", row["bearing_nde_model"]
    assert row["hierarchy_path"].present?
    assert row["data_completeness_pct"].present?
  end

  # the historian tag measurement type and quality/mapping state.
  test "historian tags expose measurement_type and the quality/mapping columns" do
    row = row_matching("historian_tags", "id", @tag.id)

    assert_equal "Overall Vibration Velocity Horizontal", row["measurement_type"]
    assert_equal "Good", row["quality_status"]
    assert_equal "Mapped", row["mapping_state"]
    assert_equal true, row["compatible"]
    assert_equal 8, row["stale_seconds"].to_i
    assert_equal 8.42, row["last_value"]
    assert row["last_validated_at"].present?
  end

  # the diagnostic incident finding and RUL-band
  # surface the health summary and advisory screens read.
  test "diagnostic incidents expose sync_status, rul_days_estimate and the finding fields" do
    row = row_matching("diagnostic_incidents", "id", @incident.id)

    assert_equal "New", row["sync_status"] # (computed)
    assert_equal 8.5, row["rul_days_estimate"]
    assert_equal 6.0, row["rul_window_low_days"]
    assert_equal 11.0, row["rul_window_high_days"]
    assert_equal 90.0, row["rul_confidence_pct"]
    assert_equal 21.0, row["pf_interval_days"]
    assert_equal "heavy", row["regime"]
    assert_equal 96.0, row["regime_confidence_pct"]
    assert_match(/outer race spall/, row["root_cause"])
    assert_match(/BPFO/, row["evidence_summary"])
    assert_equal "Stage 2 Bearing Outer Race Spall", row["failure_mechanism"]
    assert_equal 0.89, row["finding_confidence"]
    assert_equal "Signed off", row["finding_status"]
  end

  # the spectral payload columns the workbench charts consume.
  test "spectrum snapshots expose the spectrum, harmonic, marker, waterfall and orbit payloads" do
    row = row_matching("spectrum_snapshots", "id", @spectrum.id)

    assert_equal 65_536, row["line_resolution"].to_i
    assert row["spectrum_json"].any?
    assert row["harmonics_json"].any?
    assert_equal "BPFO", row["bearing_markers_json"].first["label"]
    assert row["waterfall_json"].any?
    assert row["orbit_json"].any?
    assert_equal 106.8, row["cursor_hz"]
    assert_equal 3.57, row["cursor_order"]
    assert_equal 0.31, row["delta_baseline"]
    assert_equal 30, row["waterfall_horizon_days"].to_i
  end

  # the CMMS dispatch evidence columns.
  test "cmms work orders expose priority, required_by, reservations and error_message" do
    row = row_matching("cmms_work_orders", "id", @work_order.id)

    assert_equal "Priority 2 - Urgent (Within 7 Days)", row["priority"]
    assert row["required_by"].present?
    assert_equal "SKF 7314 BECBM Pair", row["material_reservations_json"].first["item"]
    assert row.key?("error_message")
    assert row["confirmed_at"].present?
  end

  # the attributable columns live on the owning model, not on the story's
  # subject: the golden window on BaselineWindow, the metrics on ModelBaseline.
  test "attributed columns live on the owning models (G23 / AC-158)" do
    window = row_matching("baseline_windows", "id", @window.id)
    assert_equal 88.0, window["load_percent"]
    assert_equal 99.8, window["completeness_percent"]
    assert_equal true, window["selected"]

    baseline = row_matching("model_baselines", "id", @baseline.id)
    assert_equal 0.94, baseline["accuracy_metrics_json"]["precision"]
    assert baseline["gates_json"].any?
    assert_equal "Production", baseline["status"]
  end
end
