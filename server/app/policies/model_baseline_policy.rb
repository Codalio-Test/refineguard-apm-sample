# frozen_string_literal: true

class ModelBaselinePolicy < Rhino::ResourcePolicy
  self.resource_slug = "model_baselines"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "machinery_specialist") || has_role?(user, "reliability_engineer")
    []
  end

  def hidden_attributes_for_show(user)
    []
  end

  def permitted_attributes_for_create(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "model_version",
        "algorithm_type",
        "training_window_start",
        "training_window_end",
        "hyperparameters_json"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "model_version",
        "algorithm_type",
        "training_window_start",
        "training_window_end",
        "hyperparameters_json",
        "accuracy_metrics_json",
        "gates_json",
        "status",
        "training_status",
        "training_progress",
        "is_active",
        "approved_at",
        "promoted_at"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  # Custom (non-CRUD) action gates

  # Local baseline training is the machinery specialist's action
  def train?
    update? && (has_role?(user, "machinery_specialist") || has_role?(user, "admin"))
  end

  # Promoting a trained candidate to production is gated the same way
  def promote?
    update? && (has_role?(user, "machinery_specialist") || has_role?(user, "admin"))
  end
end
