# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shape for a plant-unit row of the operational risk matrix
    class PlantUnitSerializer < Base
      # @param critical_train [String, nil] the worst-severity asset tag
      # @param trip_probability [Integer] the 0-99 roll-up
      # @param exposure [String, nil] the pre-formatted exposure label
      # @param risk_cells [Array<Hash>] the four horizon cells
      # @param severity [String] the unit's worst severity
      # @param trend [Array<Hash>] the health-index series
      def risk_row(critical_train:, trip_probability:, exposure:, risk_cells:, severity:, trend:)
        {
          "unit" => record.unit_code,
          "unit_id" => record.id,
          "rate" => rate_label,
          "critical_train" => critical_train,
          "trip_probability" => "#{trip_probability}%",
          "derate" => derate_label,
          "exposure" => exposure,
          "derate_recommendation" => record.derate_recommendation,
          "risk_cells" => risk_cells,
          "severity" => severity,
          "trend" => trend
        }
      end

      private

      def rate_label
        record.rate_percent && "#{record.rate_percent.round}%"
      end

      def derate_label
        record.derate_recommendation.present? ? "#{record.rate_percent.to_f.round} kbpd" : "—"
      end
    end
  end
end
