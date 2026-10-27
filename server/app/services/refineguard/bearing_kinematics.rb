# frozen_string_literal: true

module Refineguard
  # ISO 13373-3 bearing kinematic defect frequencies.
  #
  # BPFO / BPFI / BSF / FTF lines are calculated from the stored bearing geometry
  # (number of rolling elements, element diameter, pitch diameter, contact angle)
  # and the *current* shaft speed, so a VFD speed step moves the markers with it.
  module BearingKinematics
    # Geometry for the bearing models seeded in the demo data. Diameters are in
    # millimetres; `angle` is the contact angle in degrees.
    GEOMETRY = {
      "SKF 7314 BECBM" => { elements: 12, element_mm: 17.462, pitch_mm: 105.0, angle_deg: 40.0 },
      "SKF 6314 C3" => { elements: 8, element_mm: 24.6, pitch_mm: 100.0, angle_deg: 0.0 },
      "SKF 7314 BECBM Pair" => { elements: 12, element_mm: 17.462, pitch_mm: 105.0, angle_deg: 40.0 },
      "Tilting Pad" => { elements: 5, element_mm: 0.0, pitch_mm: 0.0, angle_deg: 0.0 }
    }.freeze

    class << self
      # @param bearing_model [String, nil]
      # @param shaft_speed_hz [Float] current running speed (Hz)
      # @return [Array<Hash>] BPFO/BPFI/BSF/FTF entries with expected Hz and order
      def markers(bearing_model, shaft_speed_hz)
        speed = shaft_speed_hz.to_f
        return [] if speed <= 0

        geometry = geometry_for(bearing_model)
        geometry ? orders_for(geometry).map do |label, order|
          {
            "label" => label,
            "order" => order.round(3),
            "expected_hz" => (order * speed).round(2)
          }
        end : []
      end

      def geometry_for(bearing_model)
        return nil if bearing_model.blank?

        key = GEOMETRY.keys.find { |k| bearing_model.to_s.include?(k) }
        return nil if key.nil?

        geometry = GEOMETRY[key]
        return nil if geometry[:pitch_mm].zero? || geometry[:element_mm].zero?

        geometry
      end

      # BPFO = n/2 * f * (1 - d/D cos a)
      # BPFI = n/2 * f * (1 + d/D cos a)
      # BSF  = D/2d * f * (1 - (d/D)^2 cos^2 a)
      # FTF  = f/2 * (1 - d/D cos a)
      def orders_for(geometry)
        n = geometry[:elements].to_f
        ratio = geometry[:element_mm] / geometry[:pitch_mm]
        cos_a = Math.cos(geometry[:angle_deg] * Math::PI / 180.0)

        {
          "BPFO" => n / 2.0 * (1.0 - ratio * cos_a),
          "BPFI" => n / 2.0 * (1.0 + ratio * cos_a),
          "BSF" => geometry[:pitch_mm] / (2.0 * geometry[:element_mm]) *
                   (1.0 - (ratio**2) * (cos_a**2)),
          "FTF" => 0.5 * (1.0 - ratio * cos_a)
        }
      end
    end
  end
end
