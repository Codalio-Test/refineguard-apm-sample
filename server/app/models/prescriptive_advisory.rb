# frozen_string_literal: true

# Prescriptive maintenance advisory derived from a diagnostic incident.
class PrescriptiveAdvisory < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable
  include Rhino::HasAuditTrail

  STATUS_READY = "Ready for Dispatch"
  STATUS_DISPATCHED = "Dispatched"
  URGENCY_ROUTINE = "Routine"
  URGENCY_URGENT = "Urgent Action Required"
  URGENT_RUL_THRESHOLD_DAYS = 14

  belongs_to :diagnostic_incident, class_name: "DiagnosticIncident"
  belongs_to :standby_asset, class_name: "Asset", optional: true
  belongs_to :derate_approved_by, class_name: "User", optional: true
  has_many :cmms_work_orders, class_name: "CmmsWorkOrder", dependent: :destroy

  rhino_filters :diagnostic_incident_id, :advisory_code, :throttle_percentage, :warehouse_status, :warehouse_bin, :parts_lead_time_days, :urgency, :status, :due_within_days, :standby_asset_id, :standby_ready, :derate_approved_by_id, :derate_approved_at
  rhino_sorts :diagnostic_incident_id, :advisory_code, :throttle_percentage, :warehouse_status, :warehouse_bin, :parts_lead_time_days, :urgency, :status, :due_within_days, :standby_asset_id, :standby_ready, :derate_approved_by_id, :derate_approved_at, :created_at
  rhino_fields :id, :diagnostic_incident_id, :advisory_code, :recommended_action, :action_steps_json, :throttle_percentage, :parts_required_json, :warehouse_status, :warehouse_bin, :parts_lead_time_days, :urgency, :status, :due_within_days, :standby_asset_id, :standby_ready, :standby_checks_json, :derate_approved_by_id, :derate_approved_at, :created_at
  rhino_includes :diagnostic_incident, :standby_asset, :derate_approved_by
  rhino_search :advisory_code, :recommended_action
  rhino_default_sort "due_within_days"

  validates :diagnostic_incident_id, presence: true
  validates :status, presence: true, length: { maximum: 255 }
  validates :advisory_code, length: { maximum: 255 }, allow_nil: true
  # A throttle is a percentage of design flow: values outside 0–100 describe an
  # impossible operating point, so they are rejected before a derate is signed off
  validates :throttle_percentage,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
  validates :warehouse_status, length: { maximum: 255 }, allow_nil: true
  validates :warehouse_bin, length: { maximum: 255 }, allow_nil: true
  validates :parts_lead_time_days, numericality: { only_integer: true }, allow_nil: true
  validates :urgency, length: { maximum: 255 }, allow_nil: true
  validates :due_within_days, numericality: { only_integer: true }, allow_nil: true
  validates :standby_ready, inclusion: { in: [ true, false ] }, allow_nil: true

  def severity
    Refineguard::Severity.badge(health_state.presence || urgency_state)
  end

  def health_state
    diagnostic_incident&.health_state
  end

  # Fall back to the urgency vocabulary when the incident carries no ISO state.
  def urgency_state
    case urgency.to_s
    when /urgent/i then "Alarm"
    when /routine/i then "Normal"
    else urgency
    end
  end

  def rul_window_label
    diagnostic_incident&.rul_window_label
  end

  def rhino_computed_attributes
    {
      "severity" => severity,
      "asset_tag" => diagnostic_incident&.asset&.asset_tag,
      "asset_id" => diagnostic_incident&.asset_id,
      "finding" => diagnostic_incident&.failure_mode&.failure_name ||
                   diagnostic_incident&.failure_mechanism,
      "rul_window" => rul_window_label,
      "pf_interval_days" => diagnostic_incident&.pf_interval_days,
      "recommendation" => recommended_action,
      "regime" => diagnostic_incident&.regime,
      "regime_confidence_pct" => diagnostic_incident&.regime_confidence_pct,
      "standby_asset_tag" => standby_asset&.asset_tag,
      "derate_approved_by_name" => derate_approved_by&.name
    }
  end
end
