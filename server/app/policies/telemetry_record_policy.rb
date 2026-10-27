# frozen_string_literal: true

class TelemetryRecordPolicy < Rhino::ResourcePolicy
  self.resource_slug = "telemetry_records"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist")
    return [ "id", "historian_tag_id", "recorded_at", "recorded_value", "data_quality_flag" ] if has_role?(user, "operations_superintendent")
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
end
