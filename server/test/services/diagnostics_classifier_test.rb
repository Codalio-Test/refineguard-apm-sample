# frozen_string_literal: true

require "test_helper"

# The physics-informed failure-mode classifier.
#
# It separates broadband cavitation noise from discrete bearing harmonics and
# ranks the ISO 14224 modes by probability. These tests pin every scoring branch:
# present/absent markers, present/absent harmonics, the amplitude-ratio fallback,
# and each cavitation shortcut.
class DiagnosticsClassifierTest < ActiveSupport::TestCase
  # Mutation coverage: every scoring branch of the classifier is pinned here.
  cover "Refineguard::DiagnosticsClassifier"

  setup do
    @org = Organization.create!(slug: "diag-org", name: "Diag Org")
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Pump",
                           health_state: "Alert", monitored: true)
  end

  def snapshot(attrs = {})
    SpectrumSnapshot.create!(
      { organization: @org, asset: @asset, captured_at: Time.current, channel: "DE" }.merge(attrs)
    )
  end

  def assess(snap)
    Refineguard::DiagnosticsClassifier.assess(@asset, snapshot: snap)
  end

  test "a BPFO marker ranks the outer-race mode first and carries its evidence" do
    rows = assess(snapshot(
                    bearing_markers_json: [ { "label" => "BPFO", "match_score" => 0.9,
                                             "observed_hz" => 120.0, "amplitude" => 3.2 } ],
                    harmonics_json: [ { "order" => 1, "relative_amplitude" => 0.3 } ],
                    spectrum_json: [ { "hz" => 100.0, "amplitude" => 1.0 } ]
                  ))

    top = rows.first
    assert_equal :bearing_outer_race, top[:mode]
    assert_equal "ISO14224-MECH-BRG-BPFO", top[:iso_code]
    assert_equal 90.0, top[:probability]
    assert_equal "BPFO", top[:marker_label]
    assert_equal 120.0, top[:observed_hz]
    assert_equal 3.2, top[:amplitude]
    assert_in_delta 0.9, top[:match_score], 0.001
    assert_nil top[:expected_hz]
    assert_in_delta 82.8, top[:confidence_low], 0.001
    assert_in_delta 95.4, top[:confidence_high], 0.001
  end

  test "a BPFI marker ranks the inner-race mode and its evidence" do
    rows = assess(snapshot(
                    bearing_markers_json: [ { "label" => "BPFI", "match_score" => 0.7,
                                             "observed_hz" => 180.0, "amplitude" => 1.4 } ],
                    spectrum_json: [ { "hz" => 100.0, "amplitude" => 1.0 } ]
                  ))

    inner = rows.find { |row| row[:mode] == :bearing_inner_race }
    assert_equal "ISO14224-MECH-BRG-BPFI", inner[:iso_code]
    assert_equal 70.0, inner[:probability]
    assert_equal "BPFI", inner[:marker_label]
    assert_equal 180.0, inner[:observed_hz]
    assert_equal 1.4, inner[:amplitude]
  end

  test "harmonics rank misalignment and unbalance with their running-speed orders" do
    rows = assess(snapshot(
                    running_speed_hz: 25.0,
                    harmonics_json: [ { "order" => 2, "relative_amplitude" => 0.66, "amplitude" => 4.4 },
                                      { "order" => 1, "relative_amplitude" => 0.21, "amplitude" => 1.1 } ],
                    spectrum_json: [ { "hz" => 100.0, "amplitude" => 1.0 } ]
                  ))

    misalignment = rows.find { |row| row[:mode] == :misalignment }
    assert_equal 66.0, misalignment[:probability]
    assert_equal "2X", misalignment[:marker_label]
    assert_in_delta 50.0, misalignment[:expected_hz], 0.001
    assert_equal 4.4, misalignment[:amplitude]

    unbalance = rows.find { |row| row[:mode] == :unbalance }
    assert_equal 21.0, unbalance[:probability]
    assert_equal "1X", unbalance[:marker_label]
    assert_in_delta 25.0, unbalance[:expected_hz], 0.001
    assert_equal 1.1, unbalance[:amplitude]
  end

  test "with no snapshot every mode falls back to its prior" do
    rows = Refineguard::DiagnosticsClassifier.assess(@asset)

    assert_equal 5, rows.length
    assert_equal 10.0, rows.find { |r| r[:mode] == :bearing_outer_race }[:probability]
    assert_in_delta 41.0, rows.find { |r| r[:mode] == :misalignment }[:probability], 0.001
    assert_in_delta 24.0, rows.find { |r| r[:mode] == :unbalance }[:probability], 0.001
    assert_in_delta 8.0, rows.find { |r| r[:mode] == :cavitation }[:probability], 0.001
  end

  test "a marker without a match score falls back to the amplitude ratio" do
    rows = assess(snapshot(
                    bearing_markers_json: [ { "label" => "BPFO", "expected_hz" => 100.0,
                                             "observed_hz" => 90.0, "amplitude" => 2.0 } ],
                    spectrum_json: [ { "hz" => 100.0, "amplitude" => 1.0 } ]
                  ))

    # |90 - 100| / 100 = 0.1 deviation => a 0.9 match.
    assert_in_delta 90.0, rows.find { |r| r[:mode] == :bearing_outer_race }[:probability], 0.001
  end

  test "an amplitude ratio with no expected frequency keeps its floor" do
    rows = assess(snapshot(
                    bearing_markers_json: [ { "label" => "BPFO", "expected_hz" => 0.0,
                                             "observed_hz" => 10.0 } ],
                    spectrum_json: [ { "hz" => 100.0, "amplitude" => 1.0 } ]
                  ))

    assert_in_delta 10.0, rows.find { |r| r[:mode] == :bearing_outer_race }[:probability], 0.001
  end

  test "a broadband floor with no dominant peak scores as cavitation" do
    rows = assess(snapshot(
                    spectrum_json: [ { "hz" => 1500.0, "amplitude" => 2.0 }, { "hz" => 2500.0, "amplitude" => 2.0 },
                                     { "hz" => 3500.0, "amplitude" => 2.0 }, { "hz" => 200.0, "amplitude" => 0.5 } ]
                  ))

    cavitation = rows.find { |row| row[:mode] == :cavitation }
    assert_in_delta 95.0, cavitation[:probability], 0.001
    assert_equal "1X-5X broadband", cavitation[:marker_label]
  end

  test "a dominant in-band peak is not read as cavitation" do
    rows = assess(snapshot(
                    spectrum_json: [ { "hz" => 1500.0, "amplitude" => 10.0 }, { "hz" => 2500.0, "amplitude" => 1.0 },
                                     { "hz" => 3500.0, "amplitude" => 1.0 }, { "hz" => 200.0, "amplitude" => 1.0 } ]
                  ))

    assert_in_delta 35.0, rows.find { |row| row[:mode] == :cavitation }[:probability], 0.001
  end

  test "a spectrum outside the cavitation band scores the floor" do
    rows = assess(snapshot(spectrum_json: [ { "hz" => 200.0, "amplitude" => 1.0 } ]))
    assert_in_delta 5.0, rows.find { |r| r[:mode] == :cavitation }[:probability], 0.001
  end

  test "a spectrum with only in-band energy scores the floor" do
    rows = assess(snapshot(spectrum_json: [ { "hz" => 1500.0, "amplitude" => 2.0 } ]))
    assert_in_delta 5.0, rows.find { |r| r[:mode] == :cavitation }[:probability], 0.001
  end

  test "a non-matching harmonic order keeps the prior" do
    rows = assess(snapshot(harmonics_json: [ { "order" => 3, "relative_amplitude" => 1.5 } ]))
    assert_in_delta 24.0, rows.find { |row| row[:mode] == :unbalance }[:probability], 0.001
  end
end
