# frozen_string_literal: true

class SecurityAuditEventPolicy < Rhino::ResourcePolicy
  self.resource_slug = "security_audit_events"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  # The trail is append-only: rows are written server-side by the platform event
  # writer, so no role may create or update one through the API. This matches the
  # blueprint's `create_fields: []` / `update_fields: []` grants.
  def permitted_attributes_for_create(user)
    []
  end

  def permitted_attributes_for_update(user)
    []
  end

  # Exporting the audit evidence bundle is a read of the trail
  def export?
    index?
  end
end
