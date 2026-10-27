# frozen_string_literal: true

class SpectrumSnapshotPolicy < Rhino::ResourcePolicy
  self.resource_slug = "spectrum_snapshots"

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
        "historian_tag_id",
        "captured_at",
        "channel",
        "line_resolution",
        "sample_rate_hz",
        "rms_velocity",
        "running_speed_hz",
        "cursor_hz",
        "cursor_amplitude",
        "cursor_order",
        "delta_baseline",
        "spectrum_json",
        "harmonics_json",
        "bearing_markers_json",
        "waterfall_json",
        "orbit_json",
        "waterfall_horizon_days"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    []
  end
end
