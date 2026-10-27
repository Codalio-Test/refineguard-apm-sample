# frozen_string_literal: true

require "test_helper"

# The spectral workbench read path.
#
# 64k-line spectra are served within 500 ms
# the waterfall cascade is available over 7 / 30 / 90-day horizons
# vibration, motor amps, suction pressure and bearing temperature share
#          one synchronized time axis
# the waterfall slices carry the per-slice spectra the 3D canvas renders
#
# The interactive tilt/rotate/scrub gestures in are client-side; what the
# server owes them is the slice payload asserted here.
class SpectrumWorkbenchTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
    @tag_vib = HistorianTag.create!(
      organization: @demo_org, asset: @asset, historian_type: "OSIsoft_PI",
      source_tag_name: "P204A.VIB.OH", tag_path: "PI:P204A.VIB.OH",
      measurement_type: "Overall Vibration Velocity Horizontal", engineering_unit: "mm/s",
      scan_rate_ms: 1000, deadband_val: 0.1, quality_status: "Good", last_value: 8.42
    )
    @tag_amps = HistorianTag.create!(
      organization: @demo_org, asset: @asset, historian_type: "OSIsoft_PI",
      source_tag_name: "P204A.II.MTR", tag_path: "PI:P204A.II.MTR",
      measurement_type: "Motor Current", engineering_unit: "A",
      scan_rate_ms: 1000, deadband_val: 0.2, quality_status: "Good", last_value: 318.0
    )
    @tag_suct = HistorianTag.create!(
      organization: @demo_org, asset: @asset, historian_type: "OSIsoft_PI",
      source_tag_name: "P204A.PI.SUCT", tag_path: "PI:P204A.PI.SUCT",
      measurement_type: "Suction Pressure", engineering_unit: "barg",
      scan_rate_ms: 1000, deadband_val: 0.1, quality_status: "Good", last_value: 2.4
    )
    @tag_temp = HistorianTag.create!(
      organization: @demo_org, asset: @asset, historian_type: "OSIsoft_PI",
      source_tag_name: "P204A.TI.OB", tag_path: "PI:P204A.TI.OB",
      measurement_type: "Bearing Metal Temperature", engineering_unit: "degC",
      scan_rate_ms: 10_000, deadband_val: 0.5, quality_status: "Good", last_value: 96.0
    )

    # One shared, aligned sample axis across all four tags.
    @sample_times = 6.times.map { |i| Time.current - (i * 10).minutes }
    {
      @tag_vib => [ 8.42, 7.9, 7.2, 6.4, 5.6, 5.1 ],
      @tag_amps => [ 318.0, 315.0, 309.0, 304.0, 299.0, 296.0 ],
      @tag_suct => [ 2.4, 2.45, 2.55, 2.7, 2.85, 3.0 ],
      @tag_temp => [ 96.0, 95.0, 93.5, 91.0, 88.5, 86.0 ]
    }.each do |tag, values|
      @sample_times.each_with_index do |at, index|
        TelemetryRecord.create!(organization: @demo_org, historian_tag: tag, recorded_at: at,
                                recorded_value: values[index], data_quality_flag: "Good - 192 (OPC Quality)")
      end
    end

    @spectrum = SpectrumSnapshot.create!(
      organization: @demo_org, asset: @asset, historian_tag: @tag_vib, captured_at: Time.current,
      channel: "OB Horizontal", line_resolution: 65_536, sample_rate_hz: 25_600.0,
      rms_velocity: 8.42, running_speed_hz: 29.92, cursor_hz: 106.8, cursor_order: 3.57,
      cursor_amplitude: 0.62, delta_baseline: 0.31,
      waterfall_horizon_days: 30,
      spectrum_json: Array.new(65_536) { |i| { "hz" => (i * 0.39).round(2), "amplitude" => (i % 97) / 1000.0 } },
      harmonics_json: (1..10).map { |order| { "order" => order, "hz" => (29.92 * order).round(2),
                                              "relative_amplitude" => (0.5 / order).round(3) } },
      bearing_markers_json: Refineguard::BearingKinematics.markers("SKF 7314 BECBM", 29.92),
      waterfall_json: 30.times.map do |day|
        { "day" => day, "captured_at" => (day.days.ago).iso8601,
          "spectrum" => [ { "hz" => 29.92, "amplitude" => 0.42 + (day / 100.0) } ] }
      end,
      orbit_json: 12.times.map { |i| { "angle" => i * 30, "x" => Math.cos(i), "y" => Math.sin(i) * 0.2 } }
    )
  end

  # a 65 536-line acquisition is served inside the 500 ms budget.
  test "a 64k-line spectrum snapshot is served within 500ms" do
    url = "/api/demo-org/spectrum_snapshots?filter[asset_id]=#{@asset.id}&sort=-captured_at&include=historian_tag"

    get url, headers: auth_headers(@specialist) # warm-up: eager load + query cache
    assert_response :ok

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get url, headers: auth_headers(@specialist)
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    assert_response :ok
    body = JSON.parse(response.body)["data"].first

    assert_equal 65_536, body["line_resolution"]
    assert_equal 65_536, body["spectrum_json"].length
    assert_equal "OB Horizontal", body["channel"]
    assert_operator elapsed_ms, :<=, 500, "64k-line spectrum served in #{elapsed_ms.round}ms"
  end

  # the harmonic cursor ladder and the waterfall cascade horizons
  # are both part of the served contract.
  test "harmonic cursors, bearing markers and waterfall horizons are served" do
    get "/api/demo-org/spectrum_snapshots?filter[asset_id]=#{@asset.id}",
        headers: auth_headers(@specialist)
    row = JSON.parse(response.body)["data"].first

    orders = row["harmonics_json"].map { |h| h["order"] }
    assert_equal (1..10).to_a, orders # 1X-10X cursors

    assert_equal %w[BPFO BPFI BSF FTF], row["bearing_markers_json"].map { |m| m["label"] }
    assert_equal 106.8, row["cursor_hz"]
    assert_equal 3.57, row["cursor_order"]
    assert row["cursor_amplitude"].present?      # real-time amplitude readout
    assert row["delta_baseline"].nil? || row["delta_baseline"].is_a?(Numeric)
  end

  # the 7 / 30 / 90-day cascade. Each horizon is requestable and the
  # window is stated on the payload.
  test "the waterfall cascade is available over 7, 30 and 90 day horizons" do
    [ 7, 30, 90 ].each do |horizon|
      SpectrumSnapshot.create!(
        organization: @demo_org, asset: @asset, captured_at: Time.current,
        channel: "OB Horizontal", line_resolution: 4096, waterfall_horizon_days: horizon,
        waterfall_json: horizon.times.map { |day| { "day" => day, "spectrum" => [] } }
      )
    end

    get "/api/demo-org/spectrum_snapshots?filter[asset_id]=#{@asset.id}&sort=-captured_at",
        headers: auth_headers(@specialist)
    assert_response :ok
    rows = JSON.parse(response.body)["data"]

    assert_equal [ 7, 30, 90 ], rows.map { |r| r["waterfall_horizon_days"] }.uniq.sort
    rows.each { |row| assert_equal row["waterfall_horizon_days"], row["waterfall_json"].length }
  end

  # vibration RMS, motor amps, suction pressure and bearing temperature are
  # returned on one shared time axis.
  test "vibration, amps, suction pressure and bearing temperature share one time axis" do
    ids = [ @tag_vib, @tag_amps, @tag_suct, @tag_temp ].map(&:id).join(",")

    get "/api/demo-org/telemetry_records?filter[historian_tag_id]=#{ids}&sort=-recorded_at&include=historian_tag",
        headers: auth_headers(@specialist)
    assert_response :ok
    rows = JSON.parse(response.body)["data"]

    assert_equal 24, rows.length

    axes = rows.group_by { |row| row["recorded_at"] }.values
    assert_equal 6, axes.length, "each sample instant is shared across the four tags"
    axes.each do |slice|
      assert_equal 4, slice.length, "all four measurement types are present at every instant"
      # Four distinct historian tags — each row names its own tag (the synchronized
      # trend resolves the measurement from `tag_path`).
      assert_equal 4, slice.map { |r| r["historian_tag_id"] }.uniq.length
      assert_equal 4, slice.map { |r| r["tag_path"] }.uniq.length
      assert_equal [ @asset.asset_tag ], slice.map { |r| r["asset_tag"] }.uniq
    end

    # Every tag contributes the same six instants, in the same order.
    per_tag = rows.group_by { |row| row["historian_tag_id"] }
    assert_equal 4, per_tag.length
    expected = per_tag.values.first.map { |r| r["recorded_at"] }
    per_tag.each_value { |tag_rows| assert_equal expected, tag_rows.map { |r| r["recorded_at"] } }
  end

  # every waterfall slice carries the per-slice spectrum the 3D canvas
  # renders when it tilts / rotates / scrubs.
  test "waterfall slices carry per-slice spectra for the 3D canvas" do
    get "/api/demo-org/spectrum_snapshots?filter[asset_id]=#{@asset.id}&sort=-captured_at",
        headers: auth_headers(@specialist)
    row = JSON.parse(response.body)["data"].first

    slices = row["waterfall_json"]
    assert_equal 30, slices.length
    assert_equal (0..29).to_a, slices.map { |s| s["day"] }

    slices.each do |slice|
      assert slice["captured_at"].present?, "a slice must be scrubable back to a real timestamp"
      assert slice["spectrum"].is_a?(Array)
      assert slice["spectrum"].first.key?("hz") && slice["spectrum"].first.key?("amplitude")
    end
  end
end
