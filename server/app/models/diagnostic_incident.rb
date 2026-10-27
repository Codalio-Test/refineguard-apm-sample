# frozen_string_literal: true

# A detected degradation incident on one asset.
#
# Backs /assets/:assetId/diagnostics, the /fleet-overview anomaly queue and
# /prescriptive-advisories. Audit-bearing: every change is written to the
# engine's `audit_logs` through Rhino::HasAuditTrail.
class DiagnosticIncident < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable
  include Rhino::HasAuditTrail

  STATUS_ACTIVE = "Active"
  STATUS_UNDER_INVESTIGATION = "Under Investigation"
  STATUS_RESOLVED = "Resolved"
  URGENT_RUL_THRESHOLD_DAYS = 14

  belongs_to :asset, class_name: "Asset"
  belongs_to :failure_mode, class_name: "FailureMode", optional: true
  belongs_to :signed_off_by, class_name: "User", optional: true
  belongs_to :acknowledged_by, class_name: "User", optional: true

  has_many :prescriptive_advisories, class_name: "PrescriptiveAdvisory", dependent: :destroy
  has_many :failure_mode_assessments, class_name: "FailureModeAssessment", dependent: :nullify

  rhino_filters :asset_id, :failure_mode_id, :incident_code, :status, :severity_level, :health_state, :rul_days_estimate, :rul_window_low_days, :rul_window_high_days, :rul_confidence_pct, :pf_interval_days, :regime, :regime_confidence_pct, :failure_mechanism, :finding_confidence, :finding_status, :signed_off_by_id, :signed_off_at, :acknowledged_by_id, :acknowledged_at, :detected_at, :resolved_at
  rhino_sorts :asset_id, :failure_mode_id, :incident_code, :status, :severity_level, :health_state, :rul_days_estimate, :rul_window_low_days, :rul_window_high_days, :rul_confidence_pct, :pf_interval_days, :regime, :regime_confidence_pct, :failure_mechanism, :finding_confidence, :finding_status, :signed_off_by_id, :signed_off_at, :acknowledged_by_id, :acknowledged_at, :detected_at, :resolved_at, :created_at
  rhino_fields :id, :asset_id, :failure_mode_id, :incident_code, :status, :severity_level, :health_state, :rul_days_estimate, :rul_window_low_days, :rul_window_high_days, :rul_confidence_pct, :pf_interval_days, :regime, :regime_confidence_pct, :root_cause, :evidence_summary, :failure_mechanism, :finding_confidence, :finding_status, :signed_off_by_id, :signed_off_at, :acknowledged_by_id, :acknowledged_at, :detected_at, :resolved_at, :created_at
  rhino_includes :asset, :failure_mode, :signed_off_by, :acknowledged_by
  rhino_search :incident_code, :root_cause, :evidence_summary
  rhino_default_sort "-detected_at"

  validates :asset_id, presence: true
  validates :status, presence: true, length: { maximum: 255 }
  validates :detected_at, presence: true
  validates :incident_code, length: { maximum: 255 }, allow_nil: true
  validates :severity_level, length: { maximum: 255 }, allow_nil: true
  validates :health_state, length: { maximum: 255 }, allow_nil: true
  validates :rul_days_estimate, numericality: true, allow_nil: true
  validates :rul_window_low_days, numericality: true, allow_nil: true
  validates :rul_window_high_days, numericality: true, allow_nil: true
  validates :rul_confidence_pct, numericality: true, allow_nil: true
  validates :pf_interval_days, numericality: true, allow_nil: true
  validates :regime, length: { maximum: 255 }, allow_nil: true
  validates :regime_confidence_pct, numericality: true, allow_nil: true
  validates :failure_mechanism, length: { maximum: 255 }, allow_nil: true
  validates :finding_confidence, numericality: true, allow_nil: true
  validates :finding_status, length: { maximum: 255 }, allow_nil: true

  # the acknowledge transition is persisted, not a local toggle. Returns
  # the updated record or raises ActiveRecord::RecordInvalid.
  def acknowledge!(user, at: Time.current)
    update!(
      status: STATUS_UNDER_INVESTIGATION,
      acknowledged_by_id: user&.id,
      acknowledged_at: at
    )
    self
  end

  # persists the engineering finding and stamps the sign-off.
  def sign_off!(user, attributes = {}, at: Time.current)
    update!(
      attributes.slice(
        "root_cause", "evidence_summary", "failure_mechanism", "finding_confidence"
      ).to_h.merge(
        "finding_status" => "Signed off",
        "signed_off_by_id" => user&.id,
        "signed_off_at" => at
      )
    )
    self
  end

  def severity
    Refineguard::Severity.badge(health_state.presence || severity_level)
  end

  # "6–11 d" — the advisory and diagnostics screens print the 90% RUL band.
  def rul_window_label
    return estimated_window_label if rul_window_low_days.blank? || rul_window_high_days.blank?
    return nil if rul_days_estimate.blank? && rul_window_low_days.blank?

    "#{rul_window_low_days.round}–#{rul_window_high_days.round} d"
  end

  def estimated_window_label
    return nil if rul_days_estimate.blank?

    "#{rul_days_estimate.round} d"
  end

  def rhino_computed_attributes
    {
      "severity" => severity,
      "asset_tag" => asset&.asset_tag,
      "unit" => asset&.plant_unit&.unit_code,
      "finding" => failure_mode&.failure_name,
      "rul_window" => rul_window_label,
      "sync_status" => (acknowledged_at.present? ? "Acknowledged" : "New"),
      "acknowledged_by_name" => acknowledged_by&.name,
      "signed_off_by_name" => signed_off_by&.name
    }
  end
end
