# frozen_string_literal: true

# DCS console shift handover log entry.
#
# Carries derating approvals, standby switchover notices and the step-by-step
# warm-up/start check-off that syncs completion back to /fleet-overview.
class ShiftLogEntry < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include Rhino::HasAuditTrail

  belongs_to :plant_unit, class_name: "PlantUnit", optional: true
  belongs_to :asset, class_name: "Asset", optional: true
  belongs_to :author, class_name: "User", optional: true
  belongs_to :acknowledged_by, class_name: "User", optional: true

  rhino_filters :plant_unit_id, :asset_id, :author_id, :acknowledged_by_id, :occurred_at, :shift_label, :event_type, :severity, :steps_completed, :steps_total, :incoming_ack, :handover_completed_at
  rhino_sorts :plant_unit_id, :asset_id, :author_id, :acknowledged_by_id, :occurred_at, :shift_label, :event_type, :severity, :steps_completed, :steps_total, :incoming_ack, :handover_completed_at, :created_at
  rhino_fields :id, :plant_unit_id, :asset_id, :author_id, :acknowledged_by_id, :occurred_at, :shift_label, :event_type, :severity, :message, :unit_status, :open_risks, :outstanding_actions, :procedure_steps_json, :steps_completed, :steps_total, :incoming_ack, :handover_completed_at, :created_at
  rhino_includes :plant_unit, :asset, :author, :acknowledged_by
  rhino_search :shift_label, :event_type, :message
  rhino_default_sort "-occurred_at"

  validates :occurred_at, presence: true
  validates :shift_label, length: { maximum: 255 }, allow_nil: true
  validates :event_type, length: { maximum: 255 }, allow_nil: true
  validates :severity, length: { maximum: 255 }, allow_nil: true
  validates :steps_completed, numericality: { only_integer: true }, allow_nil: true
  validates :steps_total, numericality: { only_integer: true }, allow_nil: true
  validates :incoming_ack, inclusion: { in: [ true, false ] }, allow_nil: true

  # The stored `severity` column uses the locked badge vocabulary directly
  # (`info` / `warning` / `critical`), with the ISO state accepted as an alias.
  def severity_badge
    Refineguard::Severity.badge(severity)
  end

  def rhino_computed_attributes
    {
      "severity" => severity_badge,
      "unit" => plant_unit&.unit_code,
      "asset_tag" => asset&.asset_tag,
      "author_name" => author&.name,
      "steps_percent" => steps_total.to_i.positive? ? (steps_completed.to_i * 100.0 / steps_total.to_i).round : 0,
      "timestamp" => occurred_at&.iso8601
    }
  end
end
