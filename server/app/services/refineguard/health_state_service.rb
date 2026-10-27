# frozen_string_literal: true

module Refineguard
  # automatic health-state transition.
  #
  # When an asset's multivariate reconstruction error exceeds the 99th-percentile
  # threshold for 3 consecutive 1-minute intervals, the health state transitions
  # from Normal to Alert and the transition is recorded — on the index row (the
  # breach counter and state) and on the asset (the rolled-up state the fleet
  # table and navigation read).
  class HealthStateService
    BREACH_INTERVALS_REQUIRED = 3

    class << self
      # Evaluate one AssetHealthIndex row.
      #
      # @param index [AssetHealthIndex]
      # @return [Hash] the evaluation summary
      def evaluate(index)
        breach = breach?(index)
        consecutive = breach ? index.consecutive_breach_intervals.to_i + 1 : 0

        index.update!(consecutive_breach_intervals: consecutive)

        transitioned = false
        if consecutive >= BREACH_INTERVALS_REQUIRED && index.health_state.to_s != "Alert"
          index.update!(health_state: "Alert")
          transitioned = true
        end

        roll_up(index.asset, index.health_state) if transitioned || breach

        {
          asset_id: index.asset_id,
          breach: breach,
          consecutive_breach_intervals: consecutive,
          transitioned: transitioned,
          health_state: index.reload.health_state
        }
      end

      # Roll the worst index state (and severity) up onto the asset so the fleet
      # table, the sidebar pills and the unit risk matrix agree.
      def roll_up(asset, state = nil)
        return nil if asset.nil?

        worst = state.presence || worst_state_for(asset)
        asset.update_columns(health_state: worst) if worst.present? && asset.health_state != worst
        asset
      end

      private

      def breach?(index)
        error = index.reconstruction_error
        threshold = index.threshold_p99
        return false if error.nil? || threshold.nil?

        error > threshold
      end

      def worst_state_for(asset)
        latest = asset.asset_health_indices.order(calculated_at: :desc).first
        latest&.health_state
      end
    end
  end
end
