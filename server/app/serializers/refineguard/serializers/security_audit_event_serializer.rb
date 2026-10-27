# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shapes for the append-only security audit trail
    class SecurityAuditEventSerializer < Base
      CSV_HEADERS = %w[id recorded_at severity actor_name actor_role action_type entity_affected
                       source_host result tamper_proof_hash previous_hash tamper_proof].freeze

      def row
        {
          "id" => record.id,
          "recorded_at" => record.recorded_at&.iso8601,
          "severity" => record.severity,
          "actor_name" => record.actor_name,
          "actor_role" => record.actor_role,
          "action_type" => record.action_type,
          "entity_affected" => record.entity_affected,
          "source_host" => record.source_host,
          "result" => record.result,
          "tamper_proof_hash" => record.tamper_proof_hash,
          "previous_hash" => record.previous_hash,
          "tamper_proof" => record.tamper_proof?,
          "details" => record.details_json
        }
      end

      def csv_row
        [ record.id, record.recorded_at&.iso8601, record.severity, record.actor_name,
         record.actor_role, record.action_type, record.entity_affected, record.source_host,
         record.result, record.tamper_proof_hash, record.previous_hash, record.tamper_proof? ]
      end
    end
  end
end
