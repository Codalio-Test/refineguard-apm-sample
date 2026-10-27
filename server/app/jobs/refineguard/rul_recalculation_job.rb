# frozen_string_literal: true

module Refineguard
  # the scheduled prognostics sweep.
  #
  # Recalculates the RUL trajectory and P-F slope for every open incident,
  # detects feed-slate transitions and escalates advisories that reach the
  # 14-day threshold.
  class RulRecalculationJob < ApplicationJob
    queue_as :default

    # @param organization_id [Integer, nil] limit the sweep to one organization
    def perform(organization_id = nil)
      scope = DiagnosticIncident.where.not(rul_days_estimate: nil)
      scope = scope.where(organization_id: organization_id) if organization_id

      scope.find_each do |incident|
        Rhino.for_user(nil).in_organization(incident.organization).run do
          observed_load = incident.asset&.health_index
          transition = Refineguard::PrognosticsService.feed_slate_transition?(
            incident, observed_load_percent: observed_load.to_f
          )

          Refineguard::PrognosticsService.recalculate(
            incident, force_regime: transition ? next_regime(incident.regime) : nil
          )
        end
      end
    end

    private

    # A feed-slate switch steps the regime one level heavier (or wraps back).
    def next_regime(regime)
      order = %w[light medium heavy]
      index = order.index(regime.to_s)
      return nil if index.nil?

      order[(index + 1) % order.length]
    end
  end
end
