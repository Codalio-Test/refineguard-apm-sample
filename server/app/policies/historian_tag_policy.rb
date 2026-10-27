# frozen_string_literal: true

class HistorianTagPolicy < Rhino::ResourcePolicy
  self.resource_slug = "historian_tags"

  def permitted_attributes_for_show(user)
    return [ "*" ] if has_role?(user, "admin") || has_role?(user, "machinery_specialist") || has_role?(user, "reliability_engineer")
    return [
        "id",
        "asset_id",
        "asset_component_id",
        "historian_type",
        "source_tag_name",
        "tag_path",
        "measurement_type",
        "engineering_unit",
        "quality_status",
        "last_value",
        "last_validated_at"
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
        "asset_component_id",
        "historian_connector_id",
        "historian_type",
        "source_tag_name",
        "tag_path",
        "measurement_type",
        "engineering_unit",
        "scan_rate_ms",
        "deadband_val",
        "scan_frequency_hz",
        "mapped",
        "mapping_state"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  def permitted_attributes_for_update(user)
    return [ "*" ] if has_role?(user, "admin")
    return [
        "asset_id",
        "asset_component_id",
        "historian_connector_id",
        "historian_type",
        "source_tag_name",
        "tag_path",
        "measurement_type",
        "engineering_unit",
        "scan_rate_ms",
        "deadband_val",
        "scan_frequency_hz",
        "mapped",
        "mapping_state"
      ] if has_role?(user, "machinery_specialist")
    []
  end

  # Importing a tag mapping file creates historian tags; the batch harness is a
  # read-only validation sweep
  def import?
    create?
  end

  def validate_batch?
    index?
  end
end
