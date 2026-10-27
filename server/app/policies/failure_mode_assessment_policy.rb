# frozen_string_literal: true

class FailureModeAssessmentPolicy < Rhino::ResourcePolicy
  self.resource_slug = "failure_mode_assessments"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "machinery_specialist") || has_role?(user, "reliability_engineer")
    return [
        "id",
        "asset_id",
        "diagnostic_incident_id",
        "failure_mode_id",
        "probability",
        "marker_label",
        "expected_hz",
        "observed_hz",
        "amplitude",
        "match_score",
        "assessed_at"
      ] if has_role?(user, "maintenance_planner")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "diagnostic_incident_id",
        "failure_mode_id",
        "probability",
        "confidence_low",
        "confidence_high",
        "marker_label",
        "expected_hz",
        "observed_hz",
        "amplitude",
        "match_score",
        "assessed_at"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "diagnostic_incident_id",
        "failure_mode_id",
        "probability",
        "confidence_low",
        "confidence_high",
        "marker_label",
        "expected_hz",
        "observed_hz",
        "amplitude",
        "match_score",
        "assessed_at"
      ] if has_role?(user, "machinery_specialist")
    []
  end
end
