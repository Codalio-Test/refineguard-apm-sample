# frozen_string_literal: true

class ShiftLogEntryPolicy < Rhino::ResourcePolicy
  self.resource_slug = "shift_log_entries"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "operations_superintendent") || has_role?(user, "reliability_engineer")
    return [
        "id",
        "plant_unit_id",
        "asset_id",
        "occurred_at",
        "shift_label",
        "event_type",
        "severity",
        "message",
        "outstanding_actions"
      ] if has_role?(user, "maintenance_planner")
    return [
        "id",
        "plant_unit_id",
        "asset_id",
        "occurred_at",
        "shift_label",
        "event_type",
        "severity",
        "message"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "plant_unit_id",
        "asset_id",
        "occurred_at",
        "shift_label",
        "event_type",
        "severity",
        "message",
        "unit_status",
        "open_risks",
        "outstanding_actions",
        "procedure_steps_json",
        "steps_completed",
        "steps_total",
        "incoming_ack",
        "handover_completed_at"
      ] if has_role?(user, "operations_superintendent")
    return [
        "plant_unit_id",
        "asset_id",
        "occurred_at",
        "shift_label",
        "event_type",
        "severity",
        "message",
        "procedure_steps_json",
        "steps_completed",
        "steps_total"
      ] if has_role?(user, "reliability_engineer")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "plant_unit_id",
        "asset_id",
        "occurred_at",
        "shift_label",
        "event_type",
        "severity",
        "message",
        "unit_status",
        "open_risks",
        "outstanding_actions",
        "procedure_steps_json",
        "steps_completed",
        "steps_total",
        "incoming_ack",
        "handover_completed_at"
      ] if has_role?(user, "operations_superintendent")
    []
  end
end
