# frozen_string_literal: true

class AssetHealthIndexPolicy < Rhino::ResourcePolicy
  self.resource_slug = "asset_health_indices"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist")
    return [
        "id",
        "asset_id",
        "calculated_at",
        "health_score",
        "health_delta",
        "health_state",
        "iso_severity_category",
        "anomaly_confidence"
      ] if has_role?(user, "maintenance_planner")
    return [
        "id",
        "asset_id",
        "calculated_at",
        "health_score",
        "health_delta",
        "health_state",
        "iso_severity_category"
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
        "calculated_at",
        "health_score",
        "health_delta",
        "anomaly_confidence",
        "health_state",
        "contributing_factors_json",
        "envelope_checks_json",
        "reconstruction_error",
        "threshold_p99",
        "consecutive_breach_intervals",
        "iso_severity_category"
      ] if has_role?(user, "reliability_engineer") || has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    []
  end
end
