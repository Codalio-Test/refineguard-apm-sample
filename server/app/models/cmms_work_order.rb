# frozen_string_literal: true

# A dispatched work order in the on-prem SAP PM / IBM Maximo connector.
class CmmsWorkOrder < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable
  include Rhino::HasAuditTrail

  SYNC_PENDING = "Pending Sync"
  SYNC_DISPATCHED = "Dispatched"
  SYNC_FAILED = "Failed"

  belongs_to :prescriptive_advisory, class_name: "PrescriptiveAdvisory"
  belongs_to :user, class_name: "User", optional: true

  rhino_filters :prescriptive_advisory_id, :user_id, :cmms_type, :external_order_number, :sync_status, :priority, :required_by, :dispatched_at, :confirmed_at
  rhino_sorts :prescriptive_advisory_id, :user_id, :cmms_type, :external_order_number, :sync_status, :priority, :required_by, :dispatched_at, :confirmed_at, :created_at
  rhino_fields :id, :prescriptive_advisory_id, :user_id, :cmms_type, :external_order_number, :sync_status, :priority, :required_by, :dispatched_at, :confirmed_at, :work_order_payload, :material_reservations_json, :error_message, :created_at
  rhino_includes :prescriptive_advisory, :user
  rhino_search :external_order_number, :cmms_type, :error_message
  rhino_default_sort "-dispatched_at"

  validates :prescriptive_advisory_id, presence: true
  validates :cmms_type, presence: true, length: { maximum: 255 }
  validates :sync_status, presence: true, length: { maximum: 255 }
  validates :external_order_number, length: { maximum: 255 }, allow_nil: true
  validates :priority, length: { maximum: 255 }, allow_nil: true

  def rhino_computed_attributes
    {
      "asset_tag" => prescriptive_advisory&.diagnostic_incident&.asset&.asset_tag,
      "severity" => prescriptive_advisory&.severity || "info",
      "dispatched_by_name" => user&.name
    }
  end
end
