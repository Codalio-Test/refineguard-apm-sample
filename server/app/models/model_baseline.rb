# frozen_string_literal: true

# Local ML baseline for one asset: training window, hyperparameters, evaluation
# metrics, promotion gates and the active/archived lifecycle.
class ModelBaseline < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable
  include Rhino::HasAuditTrail

  STATUS_CANDIDATE = "Candidate"
  STATUS_PRODUCTION = "Production"
  STATUS_ARCHIVED = "Archived"

  belongs_to :asset, class_name: "Asset"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :parent_model_baseline, class_name: "ModelBaseline", optional: true
  has_many :baseline_windows, class_name: "BaselineWindow", dependent: :destroy

  rhino_filters :asset_id, :model_version, :algorithm_type, :training_window_start, :training_window_end, :status, :training_status, :training_progress, :is_active, :approved_by_id, :approved_at, :parent_model_baseline_id, :promoted_at
  rhino_sorts :asset_id, :model_version, :algorithm_type, :training_window_start, :training_window_end, :status, :training_status, :training_progress, :is_active, :approved_by_id, :approved_at, :parent_model_baseline_id, :promoted_at, :created_at
  rhino_fields :id, :asset_id, :model_version, :algorithm_type, :training_window_start, :training_window_end, :hyperparameters_json, :accuracy_metrics_json, :gates_json, :status, :training_status, :training_progress, :training_log, :is_active, :approved_by_id, :approved_at, :parent_model_baseline_id, :promoted_at, :created_at
  rhino_includes :asset, :approved_by, :parent_model_baseline
  rhino_search :model_version, :algorithm_type
  rhino_default_sort "-created_at"

  validates :asset_id, presence: true
  validates :model_version, presence: true, length: { maximum: 255 }
  validates :algorithm_type, presence: true, length: { maximum: 255 }
  validates :status, presence: true, length: { maximum: 255 }
  validates :training_status, length: { maximum: 255 }, allow_nil: true
  validates :training_progress, numericality: { only_integer: true }, allow_nil: true
  validates :is_active, inclusion: { in: [ true, false ] }, allow_nil: true

  # Every promotion gate satisfied? A missing gate counts as not-satisfied.
  def gates_satisfied?
    gates = gates_json
    return false unless gates.is_a?(Hash) && gates.any?

    gates.values.all? { |value| value == true || value.to_s == "true" }
  end

  def rhino_computed_attributes
    {
      "asset_tag" => asset&.asset_tag,
      "gates_satisfied" => gates_satisfied?,
      "approved_by_name" => approved_by&.name
    }
  end
end
