# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shape for the historian-connector probe
    class HistorianConnectorSerializer < Base
      # @param result [Hash] the outcome of HistorianBufferService.test_connection
      def probe(result)
        {
          id: record.id,
          connector_name: record.connector_name,
          status: result[:status],
          poll_latency_ms: result[:poll_latency_ms],
          connection_timeout_ms: record.connection_timeout_ms,
          ring_buffer_enabled: record.reload.ring_buffer_enabled,
          buffer_depth: record.buffer_depth.to_i,
          backfill_total: record.backfill_total.to_i,
          backfill_committed: record.backfill_committed.to_i,
          replayed: result[:replayed],
          buffered_points: result[:buffered],
          lost_points: result[:lost],
          message: probe_message(result)
        }
      end

      private

      def probe_message(result)
        if result[:buffering]
          "Link exceeded #{record.connection_timeout_ms}ms — disk-backed ring buffering engaged."
        else
          "Link healthy — ring buffer drained with zero lost points."
        end
      end
    end
  end
end
