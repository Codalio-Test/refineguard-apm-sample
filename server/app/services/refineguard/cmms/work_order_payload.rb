# frozen_string_literal: true

module Refineguard
  module Cmms
    # Assembles the CMMS work-order payload from an advisory, its diagnostic
    # incident and the latest FFT snapshot, and derives the material reservations
    class WorkOrderPayload
      def self.build(advisory:, incident:, asset:, cmms_type:, priority:, required_by:)
        new(advisory, incident, asset, cmms_type, priority, required_by).build
      end

      # Parts kit + warehouse bin, flattened into reservation rows
      def self.reservations_for(advisory)
        parts = advisory.parts_required_json
        return [] unless parts.is_a?(Hash)

        parts.flat_map do |_category, items|
          Array(items).map do |item|
            { "item" => item, "warehouse_bin" => advisory.warehouse_bin,
              "status" => advisory.warehouse_status }
          end
        end
      end

      def initialize(advisory, incident, asset, cmms_type, priority, required_by)
        @advisory = advisory
        @incident = incident
        @asset = asset
        @cmms_type = cmms_type
        @priority = priority
        @required_by = required_by
      end

      def build
        {
          "order_type" => "PM02",
          "priority" => @priority,
          "required_by" => @required_by,
          "target_system" => @cmms_type,
          "short_text" => short_text,
          "equipment_number" => @asset.asset_tag,
          "functional_location" => @asset.hierarchy_path,
          "iso_failure_code" => @incident.failure_mode&.iso_code,
          "diagnostic_summary" => diagnostic_summary,
          "fft_snapshot" => fft_snapshot,
          "material_reservations" => self.class.reservations_for(@advisory)
        }
      end

      private

      def short_text
        "RefineGuard APM: #{@advisory.recommended_action.presence || @advisory.advisory_code}"
      end

      def diagnostic_summary
        {
          "incident_code" => @incident.incident_code,
          "root_cause" => @incident.root_cause,
          "failure_mechanism" => @incident.failure_mechanism,
          "finding_confidence" => @incident.finding_confidence,
          "rul_window_low_days" => @incident.rul_window_low_days,
          "rul_window_high_days" => @incident.rul_window_high_days,
          "regime" => @incident.regime
        }
      end

      def fft_snapshot
        snapshot = @asset.spectrum_snapshots.order(captured_at: :desc).first
        return nil if snapshot.nil?

        {
          "captured_at" => snapshot.captured_at.iso8601,
          "channel" => snapshot.channel,
          "rms_velocity" => snapshot.rms_velocity,
          "bearing_markers" => snapshot.bearing_markers_json
        }
      end
    end
  end
end
