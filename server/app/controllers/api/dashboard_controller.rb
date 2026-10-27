# frozen_string_literal: true

module Api
  # The tenant-safe aggregation endpoints behind /fleet-overview and
  # /operations/unit-risk-matrix.
  # Every read goes through Rhino.query (org-scoped, fail-closed) and is gated by
  # the matching resource policy, so a role without `assets.index` cannot reach
  # the fleet aggregate.
  class DashboardController < BaseController
    #  GET /api/{organization}/dashboard/fleet_overview
    def fleet_overview
      return if deny!(AssetPolicy, :index?, Asset)

      indices = Rhino.query(Asset).to_a

      render json: {
        kpis: kpis(indices),
        totals: health_totals(indices),
        unit_risk: unit_risk_series,
        generated_at: Time.current.iso8601
      }
    end

    # GET /api/{organization}/dashboard/active_anomalies
    # `id` is the ASSET TAG: the locked prototype navigates straight to
    # `/assets/${item.id}/diagnostics`.
    def active_anomalies
      return if deny!(DiagnosticIncidentPolicy, :index?, DiagnosticIncident)

      incidents = Rhino.query(DiagnosticIncident)
                       .includes(asset: :plant_unit, failure_mode: nil)
                       .where.not(health_state: [ nil, "Normal" ])
                       .to_a

      rows = incidents.sort_by do |incident|
        [ Refineguard::Severity.rank(incident.severity), -(incident.detected_at&.to_i || 0) ]
      end

      render json: rows.map { |incident|
        Refineguard::Serializers::DiagnosticIncidentSerializer.new(incident).anomaly_row
      }
    end

    #  GET /api/{organization}/dashboard/unit_risk_matrix
    def unit_risk_matrix
      return if deny!(PlantUnitPolicy, :index?, PlantUnit)
      return if deny!(AssetPolicy, :index?, Asset)

      rows = risk_matrix_rows

      render json: {
        rows: rows,
        # 4 units x 4 horizons — the locked risk cell grid
        risk_cells: rows.flat_map { |row| row["risk_cells"] },
        derate_recommendation: rows.map { |row| row["derate_recommendation"] }.compact.first,
        severity: rows.map { |row| row["severity"] }
                      .min_by { |state| Refineguard::Severity.rank(state) } || "healthy",
        generated_at: Time.current.iso8601
      }
    end

    private

    def risk_matrix_rows
      units = Rhino.query(PlantUnit).order(:unit_code).to_a
      assets = Rhino.query(Asset).includes(:diagnostic_incidents).to_a
      advisories = Rhino.query(PrescriptiveAdvisory)
                        .includes(diagnostic_incident: :asset)
                        .where(status: PrescriptiveAdvisory::STATUS_READY)
                        .to_a

      Refineguard::UnitRiskMatrixBuilder.new(units: units, assets: assets,
                                             advisories: advisories).rows
    end

    # The locked prototype's four KPI objects
    def kpis(indices)
      critical = indices.count { |asset| asset.severity == "critical" }
      warning = indices.count { |asset| asset.severity == "warning" }
      monitored = indices.count { |asset| asset.monitored != false }
      average_health = average_health(indices)

      [
        { "label" => "Monitored assets", "value" => monitored, "note" => "Live historian coverage",
          "direction" => "flat" },
        { "label" => "Requires attention", "value" => warning + critical,
          "note" => "Alert or worse", "direction" => "up" },
        { "label" => "Critical", "value" => critical, "note" => "Alarm / Trip",
          "direction" => "up" },
        { "label" => "Fleet health index", "value" => average_health, "note" => "Mean of latest scores",
          "direction" => average_health.to_f < 80 ? "down" : "flat" }
      ]
    end

    def average_health(indices)
      values = indices.filter_map(&:health_index)
      return nil if values.empty?

      (values.sum / values.length).round(1)
    end

    # The PRD's ISO 10816 tallies
    def health_totals(indices)
      {
        "Total Monitored" => indices.count { |asset| asset.monitored != false },
        "Normal" => indices.count { |asset| asset.health_state == "Normal" },
        "Alert" => indices.count { |asset| asset.health_state == "Alert" },
        "Alarm" => indices.count { |asset| asset.health_state == "Alarm" },
        "Trip" => indices.count { |asset| asset.health_state == "Trip" }
      }
    end

    def unit_risk_series
      Rhino.query(PlantUnit).order(:unit_code).map do |unit|
        { "name" => unit.unit_code, "exposure_percent" => unit.rate_percent }
      end
    end
  end
end
