# frozen_string_literal: true

# One row = one assessed failure mode for one asset at one time, carrying the
# kinematic marker evidence (expected/observed Hz, amplitude, match score) that
# the diagnostics screen renders as the physical fingerprint table.
class FailureModeAssessment < Rhino::RhinoModel
  include Rhino::BelongsToOrganization

  belongs_to :asset, class_name: "Asset"
  belongs_to :diagnostic_incident, class_name: "DiagnosticIncident", optional: true
  belongs_to :failure_mode, class_name: "FailureMode", optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :assessed_by, class_name: "User", optional: true

  rhino_filters :asset_id, :diagnostic_incident_id, :failure_mode_id, :probability, :confidence_low, :confidence_high, :marker_label, :expected_hz, :observed_hz, :amplitude, :match_score, :assigned_to_id, :assessed_at, :assessed_by_id
  rhino_sorts :asset_id, :diagnostic_incident_id, :failure_mode_id, :probability, :confidence_low, :confidence_high, :marker_label, :expected_hz, :observed_hz, :amplitude, :match_score, :assigned_to_id, :assessed_at, :assessed_by_id, :created_at
  rhino_fields :id, :asset_id, :diagnostic_incident_id, :failure_mode_id, :probability, :confidence_low, :confidence_high, :marker_label, :expected_hz, :observed_hz, :amplitude, :match_score, :assigned_to_id, :assessed_at, :assessed_by_id, :created_at
  rhino_includes :asset, :diagnostic_incident, :failure_mode, :assigned_to, :assessed_by
  rhino_default_sort "-probability"

  validates :asset_id, presence: true
  validates :probability, presence: true, numericality: true
  validates :assessed_at, presence: true
  validates :confidence_low, numericality: true, allow_nil: true
  validates :confidence_high, numericality: true, allow_nil: true
  validates :marker_label, length: { maximum: 255 }, allow_nil: true
  validates :expected_hz, numericality: true, allow_nil: true
  validates :observed_hz, numericality: true, allow_nil: true
  validates :amplitude, numericality: true, allow_nil: true
  validates :match_score, numericality: true, allow_nil: true

  def severity_from_probability
    return "Normal" if probability.nil?

    if probability >= 75 then "Alarm"
    elsif probability >= 40 then "Alert"
    else "Normal"
    end
  end

  def rhino_computed_attributes
    {
      "failure_mode_name" => failure_mode&.failure_name,
      "asset_tag" => asset&.asset_tag,
      "severity" => Refineguard::Severity.badge(severity_from_probability)
    }
  end
end
