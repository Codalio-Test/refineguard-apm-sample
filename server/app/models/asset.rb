# frozen_string_literal: true

# ISO 14224 / ISA-95 rotating machinery digital twin.
#
# The row also carries the *latest* telemetry snapshot the fleet table renders
# (health_index, rms_velocity_mms, bearing_temp_c, estimated_rul_window,
# last_sample_at), so /fleet-overview needs one request instead of a fan-out.
class Asset < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable

  # `/assets/:assetId/*` routes carry the asset TAG (P-101A), never the numeric
  # primary key, so member endpoints resolve the record by `asset_tag`.
  rhino_route_key :asset_tag

  belongs_to :plant_unit, class_name: "PlantUnit", optional: true
  belongs_to :parent_asset, class_name: "Asset", optional: true

  has_many :asset_components, class_name: "AssetComponent", dependent: :destroy
  has_many :historian_tags, class_name: "HistorianTag", dependent: :nullify
  has_many :asset_health_indices, class_name: "AssetHealthIndex", dependent: :destroy
  has_many :diagnostic_incidents, class_name: "DiagnosticIncident", dependent: :destroy
  has_many :model_baselines, class_name: "ModelBaseline", dependent: :destroy
  has_many :baseline_windows, class_name: "BaselineWindow", dependent: :destroy
  has_many :failure_mode_assessments, class_name: "FailureModeAssessment", dependent: :destroy
  has_many :spectrum_snapshots, class_name: "SpectrumSnapshot", dependent: :destroy
  has_many :shift_log_entries, class_name: "ShiftLogEntry", dependent: :nullify
  has_many :child_assets, class_name: "Asset", foreign_key: :parent_asset_id,
                          dependent: :nullify, inverse_of: :parent_asset

  rhino_filters :plant_unit_id, :parent_asset_id, :asset_tag, :asset_name, :equipment_class, :equipment_type, :driver_type, :criticality_class, :manufacturer, :commissioned_on, :design_speed_rpm, :rated_rpm, :rated_flow_m3h, :max_bearing_temp_c, :bearing_type, :bearing_de_model, :bearing_nde_model, :seal_plan, :operating_status, :health_state, :health_index, :health_index_delta, :rms_velocity_mms, :rms_velocity_delta_pct, :bearing_temp_c, :bearing_temp_delta_c, :motor_current_a, :estimated_rul_days, :estimated_rul_window, :last_sample_at, :data_completeness_pct, :hierarchy_path, :monitored, :last_tag_validation_at
  rhino_sorts :plant_unit_id, :parent_asset_id, :asset_tag, :asset_name, :equipment_class, :equipment_type, :driver_type, :criticality_class, :manufacturer, :commissioned_on, :design_speed_rpm, :rated_rpm, :rated_flow_m3h, :max_bearing_temp_c, :bearing_type, :bearing_de_model, :bearing_nde_model, :seal_plan, :operating_status, :health_state, :health_index, :health_index_delta, :rms_velocity_mms, :rms_velocity_delta_pct, :bearing_temp_c, :bearing_temp_delta_c, :motor_current_a, :estimated_rul_days, :estimated_rul_window, :last_sample_at, :data_completeness_pct, :hierarchy_path, :monitored, :last_tag_validation_at, :created_at
  rhino_fields :id, :plant_unit_id, :parent_asset_id, :asset_tag, :asset_name, :equipment_class, :equipment_type, :driver_type, :criticality_class, :manufacturer, :commissioned_on, :design_speed_rpm, :rated_rpm, :rated_flow_m3h, :max_bearing_temp_c, :bearing_type, :bearing_de_model, :bearing_nde_model, :seal_plan, :operating_status, :health_state, :health_index, :health_index_delta, :rms_velocity_mms, :rms_velocity_delta_pct, :bearing_temp_c, :bearing_temp_delta_c, :motor_current_a, :estimated_rul_days, :estimated_rul_window, :last_sample_at, :data_completeness_pct, :hierarchy_path, :monitored, :last_tag_validation_at, :created_at
  rhino_includes :plant_unit, :parent_asset
  rhino_search :asset_tag, :asset_name, :hierarchy_path, :manufacturer

  # `asset_tag` is the required writable scalar the host runtime contract proves
  # mutation and 422 rejection with; it must be unique per organization.
  validates :asset_tag, presence: true, uniqueness: { scope: :organization_id },
                        length: { maximum: 255 }
  validates :asset_name, presence: true, length: { maximum: 255 }
  validates :equipment_class, length: { maximum: 255 }, allow_nil: true
  validates :equipment_type, length: { maximum: 255 }, allow_nil: true
  validates :driver_type, length: { maximum: 255 }, allow_nil: true
  validates :criticality_class, length: { maximum: 255 }, allow_nil: true
  validates :manufacturer, length: { maximum: 255 }, allow_nil: true
  validates :design_speed_rpm, numericality: true, allow_nil: true
  validates :rated_rpm, numericality: true, allow_nil: true
  validates :rated_flow_m3h, numericality: true, allow_nil: true
  validates :max_bearing_temp_c, numericality: true, allow_nil: true
  validates :bearing_type, length: { maximum: 255 }, allow_nil: true
  validates :bearing_de_model, length: { maximum: 255 }, allow_nil: true
  validates :bearing_nde_model, length: { maximum: 255 }, allow_nil: true
  validates :seal_plan, length: { maximum: 255 }, allow_nil: true
  validates :operating_status, length: { maximum: 255 }, allow_nil: true
  validates :health_state, length: { maximum: 255 }, allow_nil: true
  validates :health_index,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
  validates :health_index_delta, numericality: true, allow_nil: true
  validates :rms_velocity_mms, numericality: true, allow_nil: true
  validates :rms_velocity_delta_pct, numericality: true, allow_nil: true
  validates :bearing_temp_c, numericality: true, allow_nil: true
  validates :bearing_temp_delta_c, numericality: true, allow_nil: true
  validates :motor_current_a, numericality: true, allow_nil: true
  validates :estimated_rul_days, numericality: true, allow_nil: true
  validates :estimated_rul_window, length: { maximum: 255 }, allow_nil: true
  validates :data_completeness_pct, numericality: true, allow_nil: true
  validates :hierarchy_path, length: { maximum: 255 }, allow_nil: true
  validates :monitored, inclusion: { in: [ true, false ] }, allow_nil: true

  # ISO 10816 severity category derived from the vibration velocity (mm/s RMS).
  def iso_severity_category
    v = rms_velocity_mms
    return nil if v.nil?

    if v < 2.8 then "Good"
    elsif v < 7.1 then "Satisfactory"
    elsif v < 11.2 then "Unsatisfactory"
    else "Unacceptable"
    end
  end

  def severity
    Refineguard::Severity.badge(health_state)
  end

  def rhino_computed_attributes
    {
      # The locked prototype binds `asset.id` both as the row's display tag and
      # as the navigation segment (`/assets/${asset.id}/health-summary`), so the
      # serialized `id` is the asset tag. The numeric primary key stays available
      # as `record_id` for writes and FK payloads.
      "id" => asset_tag,
      "record_id" => id,
      "name" => asset_name,
      "unit" => plant_unit&.unit_code,
      "kind" => equipment_class.presence || equipment_type,
      "status" => Refineguard::Severity.label(severity),
      "severity" => severity,
      "health" => health_index,
      "health_state" => health_state,
      "iso_severity_category" => iso_severity_category,
      "rms" => rms_velocity_mms && format("%.2f", rms_velocity_mms),
      "temp" => bearing_temp_c && bearing_temp_c.round.to_s,
      "rul" => estimated_rul_window,
      "sample" => sample_age_label
    }
  end

  # "12 s" / "4 min" — the "Last sample" column renders `<value> ago`.
  def sample_age_label
    return nil if last_sample_at.nil?

    secs = (Time.current - last_sample_at).to_i
    return "#{secs} s" if secs < 120
    return "#{(secs / 60.0).round} min" if secs < 7200

    "#{(secs / 3600.0).round} h"
  end
end
