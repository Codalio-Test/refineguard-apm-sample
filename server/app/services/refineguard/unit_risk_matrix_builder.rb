# frozen_string_literal: true

module Refineguard
  # Builds the operational risk matrix rows for the dashboard endpoint
  # Kept out of the controller so the row arithmetic (worst-severity roll-up
  # trip probability, exposure label, four horizon cells, trend series) has a
  # single, testable home and the controller action stays a thin read
  class UnitRiskMatrixBuilder
    HORIZONS = %w[current_shift 24h 7d 30d].freeze

    def initialize(units:, assets:, advisories:)
      @units = units
      @assets = assets
      @advisories = advisories
    end

    # @return [Array<Hash>] one row per plant unit
    def rows
      @units.map { |unit| row_for(unit) }
    end

    private

    def row_for(unit)
      unit_assets = assets_for(unit)
      worst = worst_asset(unit_assets)

      Refineguard::Serializers::PlantUnitSerializer.new(unit).risk_row(
        critical_train: worst&.asset_tag,
        trip_probability: trip_probability_for(unit_assets),
        exposure: exposure_for(unit),
        risk_cells: risk_cells(unit_assets),
        severity: worst&.severity || "healthy",
        trend: trend_series(unit_assets)
      )
    end

    def assets_for(unit)
      @assets.select { |asset| asset.plant_unit_id == unit.id }
    end

    def worst_asset(unit_assets)
      unit_assets.min_by { |asset| Refineguard::Severity.rank(asset.severity) }
    end

    def trip_probability_for(unit_assets)
      return 3 if unit_assets.empty?

      weighted = unit_assets.sum { |asset| severity_weight(asset.severity) }
      [ (weighted.to_f / unit_assets.length).round, 99 ].min
    end

    def severity_weight(severity)
      case severity
      when "critical" then 18
      when "warning" then 9
      else 2
      end
    end

    def exposure_for(unit)
      return nil unless unit.exposure_usd_per_day

      "$#{unit.exposure_usd_per_day.to_i / 1000}k/day"
    end

    # A 4-cell row per unit (Current shift / 24 h / 7 d / 30 d) carrying the
    # worst severity index the prototype colours
    def risk_cells(unit_assets)
      HORIZONS.each_with_index.map do |horizon, index|
        severity = worst_asset(unit_assets)&.severity || "healthy"
        {
          "horizon" => horizon,
          "index" => Refineguard::Severity.rank(severity) + index,
          "severity" => severity,
          "devices_at_risk" => unit_assets.count { |asset| asset.severity != "healthy" } + @advisories.count
        }
      end
    end

    def trend_series(unit_assets)
      scores = unit_assets.filter_map(&:health_index)
      return [] if scores.empty?

      scores.each_with_index.map { |score, index| { "x" => index, "y" => score } }
    end
  end
end
