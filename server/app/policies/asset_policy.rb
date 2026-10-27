# frozen_string_literal: true

class AssetPolicy < Rhino::ResourcePolicy
  self.resource_slug = "assets"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist") || has_role?(user, "operations_superintendent")
    return [
        "id",
        "asset_tag",
        "asset_name",
        "equipment_class",
        "plant_unit_id",
        "criticality_class",
        "health_state",
        "health_index",
        "bearing_type",
        "seal_plan",
        "operating_status"
      ] if has_role?(user, "maintenance_planner")
    []
  end

  def hidden_attributes_for_show(user)
    return [ "motor_current_a", "data_completeness_pct", "hierarchy_path" ] if has_role?(user, "maintenance_planner")
    return [
        "manufacturer",
        "commissioned_on",
        "bearing_de_model",
        "bearing_nde_model",
        "last_tag_validation_at"
      ] if has_role?(user, "operations_superintendent")
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "plant_unit_id",
        "parent_asset_id",
        "asset_tag",
        "asset_name",
        "equipment_class",
        "equipment_type",
        "driver_type",
        "criticality_class",
        "manufacturer",
        "commissioned_on",
        "design_speed_rpm",
        "rated_rpm",
        "rated_flow_m3h",
        "max_bearing_temp_c",
        "bearing_type",
        "bearing_de_model",
        "bearing_nde_model",
        "seal_plan",
        "operating_status"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "plant_unit_id",
        "parent_asset_id",
        "asset_tag",
        "asset_name",
        "equipment_class",
        "equipment_type",
        "driver_type",
        "criticality_class",
        "manufacturer",
        "commissioned_on",
        "design_speed_rpm",
        "rated_rpm",
        "rated_flow_m3h",
        "max_bearing_temp_c",
        "bearing_type",
        "bearing_de_model",
        "bearing_nde_model",
        "seal_plan",
        "operating_status"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  # Importing a hierarchy file creates assets, so it tracks the create gate
  def import?
    create?
  end
end
