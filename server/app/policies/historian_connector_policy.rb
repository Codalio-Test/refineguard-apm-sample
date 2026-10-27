# frozen_string_literal: true

class HistorianConnectorPolicy < Rhino::ResourcePolicy
  self.resource_slug = "historian_connectors"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "id",
        "connector_name",
        "historian_type",
        "status",
        "last_heartbeat",
        "poll_latency_ms",
        "buffer_depth",
        "backfill_queue"
      ] if has_role?(user, "reliability_engineer")
    return [
        "id",
        "connector_name",
        "historian_type",
        "protocol_type",
        "status",
        "last_heartbeat",
        "poll_latency_ms",
        "buffer_depth"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    []
  end

  # Probing a connector mutates its buffer/status, so it is an admin action
  def test_connection?
    update? && has_role?(user, "admin")
  end
end
