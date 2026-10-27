# frozen_string_literal: true

# On-premises historian link (OSIsoft PI / Honeywell PHD / OPC UA).
#
# Carries the ingestion telemetry the locked shell renders (poll latency, buffer
# depth, backfill counters) and the 3000 ms connection timeout that triggers the
# disk-backed ring buffer.
class HistorianConnector < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable

  CONNECTION_TIMEOUT_MS = 3000

  has_many :historian_tags, class_name: "HistorianTag", dependent: :nullify

  rhino_filters :connector_name, :historian_type, :protocol_type, :endpoint_url, :server_address, :port, :polling_interval_seconds, :status, :last_heartbeat, :poll_latency_ms, :buffer_depth, :backfill_queue, :backfill_committed, :backfill_total, :ring_buffer_enabled, :connection_timeout_ms, :credentials_ref
  rhino_sorts :connector_name, :historian_type, :protocol_type, :endpoint_url, :server_address, :port, :polling_interval_seconds, :status, :last_heartbeat, :poll_latency_ms, :buffer_depth, :backfill_queue, :backfill_committed, :backfill_total, :ring_buffer_enabled, :connection_timeout_ms, :credentials_ref, :created_at
  rhino_fields :id, :connector_name, :historian_type, :protocol_type, :endpoint_url, :server_address, :port, :polling_interval_seconds, :status, :last_heartbeat, :poll_latency_ms, :buffer_depth, :backfill_queue, :backfill_committed, :backfill_total, :ring_buffer_enabled, :connection_timeout_ms, :credentials_ref, :created_at
  rhino_search :connector_name, :historian_type, :endpoint_url, :server_address
  rhino_additional_hidden :credentials_ref

  validates :connector_name, presence: true, length: { maximum: 255 }
  validates :historian_type, presence: true, length: { maximum: 255 }
  validates :protocol_type, length: { maximum: 255 }, allow_nil: true
  validates :endpoint_url, length: { maximum: 255 }, allow_nil: true
  validates :server_address, length: { maximum: 255 }, allow_nil: true
  validates :port, numericality: { only_integer: true }, allow_nil: true
  validates :polling_interval_seconds,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :status, length: { maximum: 255 }, allow_nil: true
  validates :poll_latency_ms, numericality: { only_integer: true }, allow_nil: true
  validates :buffer_depth, numericality: { only_integer: true }, allow_nil: true
  validates :backfill_queue, numericality: { only_integer: true }, allow_nil: true
  validates :backfill_committed, numericality: { only_integer: true }, allow_nil: true
  validates :backfill_total, numericality: { only_integer: true }, allow_nil: true
  validates :ring_buffer_enabled, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :connection_timeout_ms, numericality: { only_integer: true }, allow_nil: true
  validates :credentials_ref, length: { maximum: 255 }, allow_nil: true

  def severity
    return "warning" if buffer_depth.to_i.positive?
    return "warning" if poll_latency_ms.to_i > 1000

    case status.to_s.downcase
    when "connected", "synced", "sync ok", "healthy" then "healthy"
    when "degraded", "buffering" then "warning"
    when "disconnected", "failed", "offline" then "critical"
    else "info"
    end
  end

  # "380ms" — the ingestion badge prints the latency inline.
  def latency_label
    poll_latency_ms ? "#{poll_latency_ms}ms" : "—"
  end

  def rhino_computed_attributes
    {
      "severity" => severity,
      "endpoint" => endpoint_url.presence || server_address,
      "latency" => latency_label,
      "buffer" => buffer_depth.to_i.to_s,
      "backfill_pending" => backfill_total.to_i - backfill_committed.to_i
    }
  end
end
