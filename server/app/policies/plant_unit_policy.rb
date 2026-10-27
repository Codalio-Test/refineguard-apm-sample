# frozen_string_literal: true

class PlantUnitPolicy < Rhino::ResourcePolicy
  self.resource_slug = "plant_units"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist") || has_role?(user, "maintenance_planner") || has_role?(user, "operations_superintendent")
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
