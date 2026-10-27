# frozen_string_literal: true

class PrescriptiveAdvisoryPolicy < Rhino::ResourcePolicy
  self.resource_slug = "prescriptive_advisories"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "maintenance_planner") || has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist") || has_role?(user, "operations_superintendent")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "diagnostic_incident_id",
        "advisory_code",
        "recommended_action",
        "action_steps_json",
        "throttle_percentage",
        "parts_required_json",
        "warehouse_status",
        "warehouse_bin",
        "parts_lead_time_days",
        "urgency",
        "status",
        "due_within_days"
      ] if has_role?(user, "maintenance_planner")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "diagnostic_incident_id",
        "advisory_code",
        "recommended_action",
        "action_steps_json",
        "throttle_percentage",
        "parts_required_json",
        "warehouse_status",
        "warehouse_bin",
        "parts_lead_time_days",
        "urgency",
        "status",
        "due_within_days"
      ] if has_role?(user, "maintenance_planner")
    return [ "urgency", "status", "due_within_days", "recommended_action" ] if has_role?(user, "reliability_engineer")
    return [
        "throttle_percentage",
        "derate_approved_at",
        "status",
        "standby_asset_id",
        "standby_ready"
      ] if has_role?(user, "operations_superintendent")
    []
  end

  # Custom (non-CRUD) action gates
  # Each action checks its OWN permission rather than borrowing `update?`, so a
  # role that may edit an ordinary advisory field does not automatically inherit
  # the ability to sign off an operational restriction or transmit a work order

  # Approving a derate restricts plant throughput, so it is an operations
  # decision: only the plant operations superintendent may sign one off
  def approve_derate?
    update? && has_role?(user, "operations_superintendent")
  end

  # Transmitting the work order to the on-prem CMMS is maintenance planning's
  # job; the reliability engineer may also action an approved advisory
  def dispatch_work_order?
    update? && (has_role?(user, "maintenance_planner") ||
                has_role?(user, "reliability_engineer") ||
                has_role?(user, "admin"))
  end

  # A standby switchover changes how the plant runs, so operations (and the
  # reliability engineer assessing the twin) own it
  def evaluate_standby?
    update? && (has_role?(user, "operations_superintendent") ||
                has_role?(user, "reliability_engineer") ||
                has_role?(user, "admin"))
  end
end
