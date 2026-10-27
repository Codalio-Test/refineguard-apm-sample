# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shapes for the model-baseline lifecycle actions
    class ModelBaselineSerializer < Base
      def training(duration_ms:, budget_ms:)
        {
          id: record.id,
          model_version: record.model_version,
          training_status: record.training_status,
          training_progress: record.training_progress,
          training_log: record.training_log,
          accuracy_metrics_json: record.accuracy_metrics_json,
          gates_json: record.gates_json,
          gates_satisfied: record.gates_satisfied?,
          duration_ms: duration_ms,
          budget_ms: budget_ms
        }
      end

      def promotion
        {
          promoted: true,
          id: record.id,
          status: record.status,
          is_active: record.is_active,
          approved_by_id: record.approved_by_id,
          approved_at: record.approved_at&.iso8601,
          promoted_at: record.promoted_at&.iso8601
        }
      end
    end
  end
end
