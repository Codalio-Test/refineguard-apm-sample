# frozen_string_literal: true

class AssetComponentPolicy < Rhino::ResourcePolicy
  self.resource_slug = "asset_components"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "machinery_specialist") || has_role?(user, "reliability_engineer")
    return [
        "id",
        "asset_id",
        "component_name",
        "component_type",
        "position",
        "bearing_model",
        "seal_type"
      ] if has_role?(user, "maintenance_planner")
    return [
        "id",
        "asset_id",
        "component_name",
        "component_type",
        "position",
        "health_state"
      ] if has_role?(user, "operations_superintendent")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "component_name",
        "component_type",
        "position",
        "bearing_model",
        "seal_type",
        "health_state"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "component_name",
        "component_type",
        "position",
        "bearing_model",
        "seal_type",
        "health_state"
      ] if has_role?(user, "machinery_specialist")
    []
  end
end
