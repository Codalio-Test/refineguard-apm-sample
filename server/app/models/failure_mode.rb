# frozen_string_literal: true

# ISO 14224 failure-mode taxonomy used by the diagnostic classifier.
class FailureMode < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable

  has_many :diagnostic_incidents, class_name: "DiagnosticIncident", dependent: :nullify
  has_many :failure_mode_assessments, class_name: "FailureModeAssessment", dependent: :destroy

  rhino_filters :iso_code, :failure_name, :equipment_category, :severity_weight, :detection_signature
  rhino_sorts :iso_code, :failure_name, :equipment_category, :severity_weight, :detection_signature, :created_at
  rhino_fields :id, :iso_code, :failure_name, :equipment_category, :severity_weight, :detection_signature, :description, :created_at
  rhino_search :iso_code, :failure_name, :detection_signature, :description

  validates :iso_code, presence: true, length: { maximum: 255 }
  validates :failure_name, presence: true, length: { maximum: 255 }
  validates :equipment_category, length: { maximum: 255 }, allow_nil: true
  validates :severity_weight, numericality: true, allow_nil: true
  validates :detection_signature, length: { maximum: 255 }, allow_nil: true

  # The diagnostics classifier card labels rows with the PRD's short name.
  def rhino_computed_attributes
    { "name" => failure_name, "code" => iso_code }
  end
end
