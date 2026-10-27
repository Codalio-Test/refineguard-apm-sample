# frozen_string_literal: true

class DiagnosticIncidentPolicy < Rhino::ResourcePolicy
  self.resource_slug = "diagnostic_incidents"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist") || has_role?(user, "maintenance_planner")
    return [
        "id",
        "asset_id",
        "incident_code",
        "status",
        "severity_level",
        "health_state",
        "rul_days_estimate",
        "rul_window_low_days",
        "rul_window_high_days",
        "pf_interval_days",
        "regime",
        "detected_at"
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
        "failure_mode_id",
        "incident_code",
        "status",
        "severity_level",
        "health_state",
        "rul_days_estimate",
        "rul_window_low_days",
        "rul_window_high_days",
        "rul_confidence_pct",
        "pf_interval_days",
        "regime",
        "regime_confidence_pct",
        "acknowledged_at",
        "detected_at",
        "resolved_at"
      ] if has_role?(user, "reliability_engineer")
    return [
        "root_cause",
        "evidence_summary",
        "failure_mechanism",
        "finding_confidence",
        "finding_status",
        "signed_off_at",
        "status",
        "severity_level",
        "acknowledged_at",
        "resolved_at"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "failure_mode_id",
        "incident_code",
        "status",
        "severity_level",
        "health_state",
        "rul_days_estimate",
        "rul_window_low_days",
        "rul_window_high_days",
        "rul_confidence_pct",
        "pf_interval_days",
        "regime",
        "regime_confidence_pct",
        "acknowledged_at",
        "detected_at",
        "resolved_at"
      ] if has_role?(user, "reliability_engineer")
    return [
        "root_cause",
        "evidence_summary",
        "failure_mechanism",
        "finding_confidence",
        "finding_status",
        "signed_off_at",
        "status",
        "severity_level",
        "acknowledged_at",
        "resolved_at"
      ] if has_role?(user, "machinery_specialist")
    return [ "status", "severity_level" ] if has_role?(user, "maintenance_planner")
    []
  end

  # Custom (non-CRUD) action gates

  # Acknowledging an anomaly is the reliability engineer's triage action
  def acknowledge?
    update? && (has_role?(user, "reliability_engineer") || has_role?(user, "admin"))
  end

  # Signing off the diagnostic finding is the vibration specialist's action
  def sign_off?
    update? && (has_role?(user, "machinery_specialist") || has_role?(user, "admin"))
  end
end
