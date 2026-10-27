# frozen_string_literal: true

require "test_helper"

# ISO 13373-3 bearing kinematics, the
# classifier and the persisted per-asset failure-mode assessment surface.
class BearingKinematicsTest < ActiveSupport::TestCase
  test "BPFO/BPFI/BSF/FTF are computed from bearing geometry and shaft speed" do
    # the overlays follow the *current* running speed.
    markers = Refineguard::BearingKinematics.markers("SKF 7314 BECBM", 29.92)
    labels = markers.map { |m| m["label"] }

    assert_equal %w[BPFO BPFI BSF FTF], labels
    markers.each do |marker|
      assert marker["order"].positive?
      assert_in_delta marker["order"] * 29.92, marker["expected_hz"], 0.02
    end

    # A speed step moves every marker proportionally (VFD / steam-turbine ramps).
    fast = Refineguard::BearingKinematics.markers("SKF 7314 BECBM", 59.84)
    assert_in_delta 2.0, fast.first["expected_hz"] / markers.first["expected_hz"], 0.001
  end

  test "unknown bearing models produce no markers rather than wrong ones" do
    assert_empty Refineguard::BearingKinematics.markers("No Such Bearing", 29.92)
    assert_empty Refineguard::BearingKinematics.markers("SKF 7314 BECBM", 0)
  end

  test "cavitation is distinguished from discrete bearing harmonics" do
    # broadband 1-5 kHz rise vs discrete non-synchronous BPFO/BPFI peaks.
    broadband = {
      "spectrum_json" => (20..120).map do |step|
        hz = step * 20.0
        { "hz" => hz, "amplitude" => (hz.between?(1000.0, 5000.0) ? 0.09 : 0.01) }
      end
    }
    discrete = {
      "spectrum_json" => [
        { "hz" => 106.8, "amplitude" => 0.55 },
        { "hz" => 162.5, "amplitude" => 0.42 },
        { "hz" => 2400.0, "amplitude" => 0.012 }
      ]
    }

    assert_operator Refineguard::DiagnosticsClassifier.cavitation_score(struct_from(broadband)),
                    :>, 0.4
    assert_operator Refineguard::DiagnosticsClassifier.cavitation_score(struct_from(discrete)),
                    :<, 0.4
  end

  test "the classifier ranks a confirmed BPFO above the other modes" do
    markers = Refineguard::BearingKinematics.markers("SKF 7314 BECBM", 29.92).map do |m|
      m.merge("match_score" => m["label"] == "BPFO" ? 0.93 : 0.12,
              "amplitude" => 0.6)
    end

    snapshot = SpectrumSnapshot.new(
      asset: nil, captured_at: Time.current, channel: "OB Horizontal",
      running_speed_hz: 29.92,
      bearing_markers_json: markers,
      harmonics_json: [ { "order" => 1, "relative_amplitude" => 0.42 },
                       { "order" => 2, "relative_amplitude" => 0.20 } ]
    )

    ranked = Refineguard::DiagnosticsClassifier.assess(
      Struct.new(:spectrum_snapshots).new(Struct.new(:order).new([])), snapshot: snapshot
    )

    assert_equal :bearing_outer_race, ranked.first[:mode]
    assert_operator ranked.first[:probability], :>, 50
  end

  private

  def struct_from(hash)
    Struct.new(:spectrum_json).new(hash["spectrum_json"])
  end
end
