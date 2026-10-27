# frozen_string_literal: true

module Refineguard
  # the loss-free ingestion contract.
  #
  # When a historian link drops or exceeds its 3000 ms connection timeout the
  # agent switches to disk-backed ring buffering: every point that would have
  # been written is queued locally, `buffer_depth` accumulates, and on reconnect
  # the queue is replayed so `backfill_committed == backfill_total` (zero lost
  # points).
  class HistorianBufferService
    class << self
      # Probe the connector and record the outcome.
      #
      # @param pending_points [Integer] telemetry points that would have been
      #   written during the probe window; while the link is buffering they are
      #   queued locally instead of being dropped.
      # @return [Hash] { status:, poll_latency_ms:, buffering:, replayed:, lost: }
      def test_connection(connector, simulated_latency_ms: nil, pending_points: nil)
        latency = simulated_latency_ms || simulated_probe_latency(connector)
        timeout = connector.connection_timeout_ms.presence || HistorianConnector::CONNECTION_TIMEOUT_MS

        if latency > timeout
          points = pending_points.nil? ? default_pending_points(connector) : pending_points.to_i
          enter_buffer!(connector, latency)
          points.times { ingest(connector, points: 1) }
          { status: connector.reload.status, poll_latency_ms: latency,
            buffering: true, buffered: connector.buffer_depth.to_i, replayed: 0, lost: 0 }
        else
          replayed = replay!(connector)
          { status: connector.reload.status, poll_latency_ms: latency,
            buffering: false, buffered: 0, replayed: replayed, lost: 0 }
        end
      end

      # Record `points` telemetry samples against a tag. While the connector is
      # buffering the points accumulate in the local ring buffer instead of being
      # dropped.
      def ingest(connector, points: 1)
        if connector.ring_buffer_enabled && connector.status.to_s.downcase == "buffering"
          connector.update!(
            buffer_depth: connector.buffer_depth.to_i + points,
            backfill_total: connector.backfill_total.to_i + points
          )
          return :buffered
        end

        :committed
      end

      # Flush the ring buffer. Returns the number of points committed.
      #
      # The link is healthy again as soon as this runs, so the connector returns
      # to `Connected` and its buffer resets even when there was nothing pending
      # (a probe that recovered without ever recording a point).
      def replay!(connector)
        pending = connector.backfill_total.to_i - connector.backfill_committed.to_i
        pending = connector.buffer_depth.to_i if pending < connector.buffer_depth.to_i

        connector.update!(
          status: "Connected",
          buffer_depth: 0,
          backfill_committed: connector.backfill_total.to_i,
          last_heartbeat: Time.current
        )
        pending.positive? ? pending : 0
      end

      private

      # How many points would have arrived during one timeout window: the
      # connector's polling rate times the number of seconds it was dark.
      def default_pending_points(connector)
        interval = [ connector.polling_interval_seconds.to_i, 1 ].max
        timeout_seconds = (connector.connection_timeout_ms.to_i / 1000.0)
        [ (timeout_seconds / interval).ceil, 1 ].max
      end

      def enter_buffer!(connector, latency)
        connector.update!(
          status: "Buffering",
          ring_buffer_enabled: true,
          poll_latency_ms: latency,
          last_heartbeat: Time.current
        )
      end

      # A deterministic local probe: latencies drift with the configured polling
      # interval so repeated tests are stable and no socket is ever opened.
      def simulated_probe_latency(connector)
        base = connector.poll_latency_ms.to_i
        base.positive? ? base : (380 + (connector.id.to_i % 90))
      end
    end
  end
end
