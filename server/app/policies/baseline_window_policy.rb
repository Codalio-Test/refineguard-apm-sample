# frozen_string_literal: true

class BaselineWindowPolicy < Rhino::ResourcePolicy
  self.resource_slug = "baseline_windows"

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
        "model_baseline_id",
        "label",
        "window_start",
        "window_end",
        "load_percent",
        "completeness_percent",
        "selected",
        "eligible"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "model_baseline_id",
        "label",
        "window_start",
        "window_end",
        "load_percent",
        "completeness_percent",
        "selected",
        "eligible"
      ] if has_role?(user, "machinery_specialist")
    []
  end
end
