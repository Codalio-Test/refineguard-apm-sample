# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shape for a single row of the historian tag validation harness
    class TagValidationRowSerializer < Base
      def row
        {
          "tag_id" => record.tag_id,
          "tag_path" => record.tag_path,
          "success" => record.success,
          "value" => record.value,
          "latency_ms" => record.latency_ms,
          "quality_status" => record.quality_status,
          "stale_seconds" => record.stale_seconds,
          "errors" => record.errors
        }
      end
    end
  end
end
