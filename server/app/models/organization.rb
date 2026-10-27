# frozen_string_literal: true

# The tenant aggregate. Rhino's multi-tenancy is route-prefix based
# (`/api/:organization/...`) and every RefineGuard resource carries its own
# `organization_id`; these associations exist so services can reach a tenant's
# resources from the organization record itself.
class Organization < ApplicationRecord
  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles
  has_many :roles, through: :user_roles

  has_many :org_role_permissions, dependent: :destroy

  # RefineGuard resources.
  has_many :plant_units, class_name: "PlantUnit"
  has_many :assets, class_name: "Asset"
  has_many :asset_components, class_name: "AssetComponent"
  has_many :failure_modes, class_name: "FailureMode"
  has_many :failure_mode_assessments, class_name: "FailureModeAssessment"
  has_many :historian_connectors, class_name: "HistorianConnector"
  has_many :historian_tags, class_name: "HistorianTag"
  has_many :telemetry_records, class_name: "TelemetryRecord"
  has_many :asset_health_indices, class_name: "AssetHealthIndex"
  has_many :diagnostic_incidents, class_name: "DiagnosticIncident"
  has_many :spectrum_snapshots, class_name: "SpectrumSnapshot"
  has_many :model_baselines, class_name: "ModelBaseline"
  has_many :baseline_windows, class_name: "BaselineWindow"
  has_many :prescriptive_advisories, class_name: "PrescriptiveAdvisory"
  has_many :cmms_work_orders, class_name: "CmmsWorkOrder"
  has_many :shift_log_entries, class_name: "ShiftLogEntry"
  has_many :security_audit_events, class_name: "SecurityAuditEvent"

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
