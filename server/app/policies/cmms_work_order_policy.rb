# frozen_string_literal: true

class CmmsWorkOrderPolicy < Rhino::ResourcePolicy
  self.resource_slug = "cmms_work_orders"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "maintenance_planner") || has_role?(user, "reliability_engineer")
    return [
        "id",
        "prescriptive_advisory_id",
        "cmms_type",
        "external_order_number",
        "sync_status",
        "priority",
        "required_by",
        "dispatched_at",
        "confirmed_at"
      ] if has_role?(user, "machinery_specialist")
    return [
        "id",
        "prescriptive_advisory_id",
        "cmms_type",
        "external_order_number",
        "sync_status",
        "priority",
        "required_by",
        "dispatched_at"
      ] if has_role?(user, "operations_superintendent")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "prescriptive_advisory_id",
        "cmms_type",
        "priority",
        "required_by",
        "work_order_payload"
      ] if has_role?(user, "maintenance_planner") || has_role?(user, "reliability_engineer")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "priority",
        "required_by",
        "external_order_number",
        "sync_status",
        "dispatched_at",
        "confirmed_at",
        "work_order_payload",
        "material_reservations_json",
        "error_message"
      ] if has_role?(user, "maintenance_planner")
    []
  end
end
