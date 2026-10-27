# frozen_string_literal: true

require "test_helper"

# The fleet grid, its unit filter and the unit risk matrix.
#
# filtering by refinery operating unit narrows the grid
# each card carries the health index, the ISO 10816 category and the
#          24-hour trend / sample age
# the card's `id` is the asset tag, so the locked
#          `/assets/${id}/health-summary` navigation resolves
# a bound tag is verified with a live value and sub-second latency
# the anomaly queue is ordered by severity, then by age
# the risk matrix cross-cuts every process unit
class FleetGridContractTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
    @unit_two = PlantUnit.create!(organization: @demo_org, unit_code: "FCC-2",
                                 unit_name: "Fluid Catalytic Cracking",
                                 rate_percent: 88.0, exposure_usd_per_day: 512_000.0)
    @asset_two = Asset.create!(organization: @demo_org, plant_unit: @unit_two, asset_tag: "C-101B",
                               asset_name: "Wet gas compressor B", health_state: "Alert",
                               health_index: 54.0, rms_velocity_mms: 5.18, bearing_temp_c: 82.0,
                               monitored: true, last_sample_at: Time.current - 3.minutes)
    @tag = HistorianTag.create!(organization: @demo_org, asset: @asset,
                                historian_type: "OSIsoft_PI", source_tag_name: "P204A.VIB.OH",
                                tag_path: "PI:P204A.VIB.OH", measurement_type: "Vibration Velocity",
                                engineering_unit: "mm/s", scan_rate_ms: 1000, deadband_val: 0.1,
                                quality_status: "Good", stale_seconds: 8, last_value: 8.42)
  end

  def asset_rows(params = {})
    get "/api/demo-org/assets", params: params, headers: auth_headers(@admin)
    assert_response :ok
    JSON.parse(response.body)["data"]
  end

  # the unit filter narrows the grid to the selected operating unit.
  test "filtering the fleet by operating unit narrows the asset grid" do
    rows = asset_rows(filter: { plant_unit_id: @unit_two.id })

    assert_equal %w[C-101B], rows.map { |row| row["id"] }
    assert_equal [ "FCC-2" ], rows.map { |row| row["unit"] }.uniq

    rows = asset_rows(filter: { plant_unit_id: @unit.id })
    assert_equal [ "CDU-1" ], rows.map { |row| row["unit"] }.uniq
    assert_not_includes rows.map { |row| row["id"] }, "C-101B"
  end

  # the card contract: health index, ISO 10816 category, severity and the
  # sample-age / trend columns.
  test "fleet rows carry the health index, ISO category and sample age" do
    rows = asset_rows
    critical = rows.find { |row| row["id"] == "P-204A" }
    healthy = rows.find { |row| row["id"] == "P-101B" }

    assert_equal 28.0, critical["health"]
    assert_equal "critical", critical["severity"]
    assert_equal "Unsatisfactory", critical["iso_severity_category"] # 8.42 mm/s -> ISO Zone C
    assert critical["sample"].present?, "the 24-hour trend column needs a sample age"
    assert_equal "8.42", critical["rms"]

    assert_equal "healthy", healthy["severity"]
    assert_equal "Good", healthy["iso_severity_category"] # 1.04 mm/s -> ISO Zone A/B
  end

  # the row id is the asset tag: clicking a card navigates straight to the
  # tag-keyed health summary, and that URL resolves.
  test "a fleet row navigates to the tag-keyed health summary" do
    row = asset_rows.find { |candidate| candidate["asset_tag"] == "P-204A" }
    assert_equal "P-204A", row["id"]

    get "/api/demo-org/assets/#{row['id']}", headers: auth_headers(@admin)
    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal "P-204A", body["id"]
    assert_equal 28.0, body["health_index"]
    assert body["plant_unit_id"].present?, "the health summary is pre-loaded with the asset context"
  end

  # binding a tag verifies it and returns the live value with latency
  # well inside the 1000 ms read budget.
  test "a bound historian tag is verified with a live value under 1000ms" do
    post "/api/demo-org/historian_tags/validate_batch",
         params: { tag_ids: [ @tag.id ] }.to_json, headers: json_headers(@admin)
    assert_response :ok

    body = JSON.parse(response.body)
    row = body["results"].first
    assert row["success"], "binding failed: #{row['errors'].inspect}"
    assert_equal 8.42, row["value"]
    assert_operator row["latency_ms"], :<=, 1000
    assert_equal "Good", row["quality_status"]
  end

  # the anomaly queue is ordered by severity first, then by age.
  test "the anomaly queue is ordered by severity then by age" do
    older_critical = create_incident("P-204A", "Trip", 6.days.ago, "INC-OLD-CRIT")
    newer_warning = create_incident("P-101B", "Alert", 30.minutes.ago, "INC-NEW-WARN")
    newer_critical = create_incident("C-101B", "Alarm", 1.hour.ago, "INC-NEW-CRIT")

    get "/api/demo-org/dashboard/active_anomalies", headers: auth_headers(@admin)
    assert_response :ok

    ids = JSON.parse(response.body).map { |row| row["id"] }
    assert_equal [ "C-101B", "P-204A", "P-101B" ], ids
    assert_equal newer_critical.id, JSON.parse(response.body).first["record_id"]
  end

  # the risk matrix returns a row per process unit with its risk cells and
  # the verified derate recommendation.
  test "the unit risk matrix cross-cuts every process unit" do
    get "/api/demo-org/dashboard/unit_risk_matrix", headers: auth_headers(@admin)
    assert_response :ok
    body = JSON.parse(response.body)

    assert_equal %w[CDU-1 FCC-2], body["rows"].map { |row| row["unit"] }.sort
    body["rows"].each do |row|
      assert_equal %w[current_shift 24h 7d 30d], row["risk_cells"].map { |c| c["horizon"] }
      %w[rate critical_train trip_probability derate exposure].each do |key|
        assert row.key?(key), "unit row is missing #{key}"
      end
    end

    assert_equal 8, body["risk_cells"].length # 2 units x 4 horizons
    assert_equal "Reduce charge rate by 8%.", body["derate_recommendation"]
  end

  private

  def create_incident(asset_tag, health_state, detected_at, code)
    asset = Asset.find_by!(organization: @demo_org, asset_tag: asset_tag)
    DiagnosticIncident.create!(organization: @demo_org, asset: asset, incident_code: code,
                               status: "Active", severity_level: "High", health_state: health_state,
                               rul_days_estimate: 18.0, detected_at: detected_at)
  end
end
