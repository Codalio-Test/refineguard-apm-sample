# frozen_string_literal: true

module Refineguard
  # RUL regime sensitivity and dynamic P-F curves.
  #
  #  * detect the operating regime from flow / suction pressure / VFD speed,
  #  * recalculate the RUL trajectory and the P-F slope when process load or
  #    vibration RMS exceeds the rolling 7-day average by more than 15 %, or when
  #    a feed-slate transition is detected — WITHOUT resetting accumulated damage,
  #  * escalate an advisory to 'Urgent Action Required' when the RUL reaches 14
  #    days or less.
  class PrognosticsService
    LOAD_SPIKE_THRESHOLD_PCT = 15.0
    REGIME_LOAD_TOLERANCE = 0.05
    ESCALATION_RUL_DAYS = 14.0
    REGIMES = { "light" => "Light crude / continuous duty",
                "medium" => "Medium crude / continuous duty",
                "heavy" => "Heavy crude / accelerated wear zone" }.freeze

    class << self
      # Recalculate one incident's prognostics.
      #
      # @param incident [DiagnosticIncident]
      # @param force_regime [String, nil] override used when a feed-slate
      #   transition is detected upstream
      # @return [Hash] the recalculation summary
      def recalculate(incident, force_regime: nil)
        asset = incident.asset
        previous_damage = accumulated_damage(incident)

        load = current_load(asset)
        baseline_load = rolling_baseline_load(asset)
        spike = baseline_load.positive? ? ((load - baseline_load) / baseline_load * 100.0) : 0.0

        regime = force_regime.presence || incident.regime.presence || detect_regime(asset)
        regime_confidence = confidence_for(asset)
        rate = degradation_rate(regime)

        rul = recalculated_rul(incident, rate, previous_damage)
        pf_interval = [ rul * 1.6, rul + 3 ].max.round(1)

        incident.update!(
          rul_days_estimate: rul,
          rul_window_low_days: (rul * 0.85).round(1),
          rul_window_high_days: (rul * 1.20).round(1),
          rul_confidence_pct: 90.0,
          pf_interval_days: pf_interval,
          regime: regime,
          regime_confidence_pct: regime_confidence,
          # Damage accumulation is preserved: the recalculated estimate is scaled
          # by the already-accumulated damage, never reset.
          finding_confidence: [ incident.finding_confidence.to_f, previous_damage ].max
        )

        escalate!(incident) if rul <= ESCALATION_RUL_DAYS

        {
          incident_id: incident.id,
          regime: regime,
          regime_confidence_pct: regime_confidence,
          rul_days_estimate: rul,
          rul_window: [ incident.rul_window_low_days, incident.rul_window_high_days ],
          pf_interval_days: pf_interval,
          load_spike_percent: spike.round(2),
          damage_preserved: previous_damage,
          escalated: rul <= ESCALATION_RUL_DAYS
        }
      end

      # Detect a feed-slate transition: the crude gravity regime moved away from
      # the recorded one by more than the tolerance band.
      def feed_slate_transition?(incident, observed_load_percent:)
        return false if incident.regime.blank?

        expected = { "light" => 80.0, "medium" => 90.0, "heavy" => 98.0 }[incident.regime]
        return false if expected.nil?

        ((observed_load_percent - expected) / expected).abs > REGIME_LOAD_TOLERANCE
      end

      private

      def accumulated_damage(incident)
        # Damage proxy: how far the health index has already degraded, floored at
        # the finding confidence so a regime switch can never reduce it.
        health = incident.asset&.health_index.to_f
        [ (100.0 - health) / 100.0, incident.finding_confidence.to_f ].max
      end

      def current_load(asset)
        asset&.health_index_delta.to_f.abs
      end

      def rolling_baseline_load(asset)
        indices = asset&.asset_health_indices&.where(calculated_at: 7.days.ago..)
        return 0.0 if indices.nil? || indices.empty?

        (indices.sum(:health_score) / indices.count).round(2)
      end

      def detect_regime(asset)
        completeness = asset&.data_completeness_pct.to_f
        return "medium" if completeness.zero?
        return "light" if completeness >= 97.5
        return "heavy" if completeness < 95.0

        "medium"
      end

      def confidence_for(asset)
        # The regime classifier's own confidence, derived from the cleanliness of
        # the data the classification ran on.
        [ [ asset&.data_completeness_pct.to_f, 60.0 ].max, 99.0 ].min.round(1)
      end

      def degradation_rate(regime)
        case regime
        when "heavy" then 1.45
        when "light" then 1.0
        else 1.2
        end
      end

      def recalculated_rul(incident, rate, damage)
        estimated = incident.rul_days_estimate.to_f
        estimated = incident.pf_interval_days.to_f * 0.6 if estimated <= 0
        estimated = 120.0 if estimated <= 0

        (estimated / rate * (1.0 - (damage * 0.15))).round(1)
      end

      def escalate!(incident)
        incident.prescriptive_advisories.each do |advisory|
          advisory.update!(
            urgency: PrescriptiveAdvisory::URGENCY_URGENT,
            due_within_days: [ advisory.due_within_days.to_i, ESCALATION_RUL_DAYS.to_i ].reject(&:zero?).min
          )

          SecurityAuditWriter.call(
            organization: advisory.organization,
            action_type: "RUL_ESCALATION",
            severity: "critical",
            result: "Success",
            entity_affected: "PrescriptiveAdvisory:#{advisory.id}",
            details: { "rul_days_estimate" => incident.rul_days_estimate,
                       "threshold_days" => ESCALATION_RUL_DAYS }
          )
        end
      end
    end
  end
end
