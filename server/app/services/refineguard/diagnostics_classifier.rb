# frozen_string_literal: true

module Refineguard
  # the physics-informed failure-mode classifier.
  #
  # Separates hydraulic cavitation (a *broadband* noise-floor rise between 1 kHz
  # and 5 kHz) from bearing defect harmonics (discrete non-synchronous peaks at
  # the calculated BPFO / BPFI orders). The classifier is deterministic and reads
  # only what the local FFT snapshot, vibration trend and ISO taxonomy contain.
  class DiagnosticsClassifier
    CAVITATION_BAND_HZ = (1000.0..5000.0)
    DISCRETE_PEAK_RATIO = 2.5

    # ISO 14224 codes the classifier maps its verdicts onto.
    MODE_CODES = {
      bearing_outer_race: "ISO14224-MECH-BRG-BPFO",
      bearing_inner_race: "ISO14224-MECH-BRG-BPFI",
      misalignment: "ISO14224-MECH-ALIGN-ANG",
      cavitation: "ISO14224-HYDR-CAVIT-SUCT",
      unbalance: "ISO14224-MECH-UNBAL-1X"
    }.freeze

    class << self
      # @param asset [Asset]
      # @param snapshot [SpectrumSnapshot, nil] latest spectrum for the asset
      # @return [Array<Hash>] ranked assessments
      def assess(asset, snapshot: nil)
        snapshot ||= asset.spectrum_snapshots.order(captured_at: :desc).first
        markers = Array(snapshot&.bearing_markers_json)
        harmonics = Array(snapshot&.harmonics_json)

        scores = {
          bearing_outer_race: score_for_marker(markers, %w[BPFO BPFO1]) * 100,
          bearing_inner_race: score_for_marker(markers, %w[BPFI BPFI1]) * 100,
          misalignment: score_for_harmonic(harmonics, 2) * 100,
          unbalance: score_for_harmonic(harmonics, 1) * 100,
          cavitation: cavitation_score(snapshot) * 100
        }

        scores.sort_by { |_k, v| -v }.map do |mode, score|
          {
            mode: mode,
            iso_code: MODE_CODES[mode],
            probability: score.round(1),
            confidence_low: (score * 0.92).round(1),
            confidence_high: [ (score * 1.06).round(1), 99.9 ].min,
            marker_label: marker_label_for(mode, markers, harmonics),
            expected_hz: expected_hz_for(mode, snapshot),
            observed_hz: observed_hz_for(mode, markers),
            amplitude: amplitude_for(mode, markers, harmonics),
            match_score: (score / 100.0).round(3)
          }
        end
      end

      # Cavitation is a *broadband* rise: the median energy in the 1–5 kHz band
      # sits well above the adjacent floor while no single discrete peak
      # dominates. Bearing defects show the opposite signature.
      def cavitation_score(snapshot)
        spectrum = Array(snapshot&.spectrum_json)
        return 0.08 if spectrum.empty?

        band = spectrum.select { |p| CAVITATION_BAND_HZ.cover?(frequency_of(p)) }
        return 0.05 if band.empty?

        band_energy = band.sum { |p| amplitude_of(p) }
        outside = spectrum.reject { |p| CAVITATION_BAND_HZ.cover?(frequency_of(p)) }
        outside_energy = outside.sum { |p| amplitude_of(p) }
        return 0.05 if outside_energy.zero?

        broadband_ratio = (band_energy / band.count) / (outside_energy / [ outside.count, 1 ].max)
        peak_ratio = band.map { |p| amplitude_of(p) }.max.to_f / [ band.sum { |p| amplitude_of(p) } / band.count, 1e-9 ].max

        # High average band energy + no dominant single peak => cavitation.
        broadband = [ (broadband_ratio - 1.0).clamp(0.0, 3.0) / 3.0, 0.0 ].max
        not_discrete = peak_ratio < DISCRETE_PEAK_RATIO ? 1.0 : 0.35

        (broadband * not_discrete).clamp(0.0, 0.95)
      end

      def marker_label_for(mode, markers, harmonics)
        case mode
        when :bearing_outer_race then "BPFO"
        when :bearing_inner_race then "BPFI"
        when :misalignment then "2X"
        when :unbalance then "1X"
        else "1X-5X broadband"
        end
      end

      private

      def score_for_marker(markers, labels)
        marker = markers.find { |m| labels.include?(m["label"].to_s.upcase) }
        return 0.1 if marker.nil?

        match = marker["match_score"].to_f
        match = amplitude_ratio(marker) if match.zero?
        match.clamp(0.0, 1.0)
      end

      def score_for_harmonic(harmonics, order)
        harmonic = harmonics.find { |h| h["order"].to_f == order.to_f }
        return order == 2 ? 0.41 : 0.24 if harmonic.nil?

        harmonic["relative_amplitude"].to_f.clamp(0.0, 1.0)
      end

      def amplitude_ratio(marker)
        expected = marker["expected_hz"].to_f
        observed = marker["observed_hz"].to_f
        return 0.1 if expected.zero?

        (1.0 - ((observed - expected).abs / expected)).clamp(0.0, 1.0)
      end

      def expected_hz_for(mode, snapshot)
        case mode
        when :unbalance then 1.0 * snapshot&.running_speed_hz.to_f
        when :misalignment then 2.0 * snapshot&.running_speed_hz.to_f
        else nil
        end
      end

      def observed_hz_for(mode, markers)
        case mode
        when :bearing_outer_race then markers.find { |m| m["label"].to_s.upcase == "BPFO" }&.dig("observed_hz")
        when :bearing_inner_race then markers.find { |m| m["label"].to_s.upcase == "BPFI" }&.dig("observed_hz")
        end
      end

      def amplitude_for(mode, markers, harmonics)
        case mode
        when :bearing_outer_race then markers.find { |m| m["label"].to_s.upcase == "BPFO" }&.dig("amplitude")
        when :bearing_inner_race then markers.find { |m| m["label"].to_s.upcase == "BPFI" }&.dig("amplitude")
        else harmonics.find { |h| h["order"].to_f == (mode == :misalignment ? 2.0 : 1.0) }&.dig("amplitude")
        end
      end

      def frequency_of(point)
        point["hz"].to_f
      end

      def amplitude_of(point)
        point["amplitude"].to_f
      end
    end
  end
end
