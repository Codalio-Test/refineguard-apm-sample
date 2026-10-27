# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shapes for the diagnostic-incident custom actions
    class DiagnosticIncidentSerializer < Base
      # The fleet anomaly-queue row. `id` is deliberately the ASSET TAG: the
      # locked grid navigates straight to `/assets/:assetTag/diagnostics`
      def anomaly_row
        {
          "id" => record.asset&.asset_tag,
          "record_id" => record.id,
          "issue" => record.failure_mode&.failure_name || record.failure_mechanism ||
                     "Degradation detected",
          "age" => age_label(record.detected_at),
          "severity" => record.severity,
          "asset_tag" => record.asset&.asset_tag,
          "asset_tag_label" => record.asset&.asset_tag,
          "status" => record.status,
          "rul_window" => record.rul_window_label,
          "detected_at" => record.detected_at&.iso8601
        }
      end

      def acknowledgement
        {
          id: record.id,
          status: record.status,
          acknowledged_by_id: record.acknowledged_by_id,
          acknowledged_at: record.acknowledged_at&.iso8601,
          sync_status: "Under Investigation"
        }
      end

      def sign_off(propagated_advisories:)
        {
          id: record.id,
          finding_status: record.finding_status,
          root_cause: record.root_cause,
          evidence_summary: record.evidence_summary,
          failure_mechanism: record.failure_mechanism,
          finding_confidence: record.finding_confidence,
          signed_off_by_id: record.signed_off_by_id,
          signed_off_at: record.signed_off_at&.iso8601,
          propagated_advisories: propagated_advisories
        }
      end

      private

      def age_label(timestamp)
        return "—" if timestamp.nil?

        seconds = (Time.current - timestamp).to_i
        return "#{seconds / 60} min" if seconds < 3600
        return "#{(seconds / 3600.0).round} h" if seconds < 86_400

        "#{(seconds / 86_400.0).round} d"
      end
    end
  end
end
