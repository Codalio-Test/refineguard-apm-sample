# frozen_string_literal: true

class FailureModePolicy < Rhino::ResourcePolicy
  self.resource_slug = "failure_modes"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "machinery_specialist") || has_role?(user, "reliability_engineer")
    return [ "id", "iso_code", "failure_name", "equipment_category", "severity_weight" ] if has_role?(user, "maintenance_planner")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "iso_code",
        "failure_name",
        "equipment_category",
        "severity_weight",
        "detection_signature",
        "description"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "iso_code",
        "failure_name",
        "equipment_category",
        "severity_weight",
        "detection_signature",
        "description"
      ] if has_role?(user, "machinery_specialist")
    []
  end
end
