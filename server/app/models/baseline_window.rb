# frozen_string_literal: true

# A candidate golden operating window offered to the retraining workbench.
class BaselineWindow < Rhino::RhinoModel
  include Rhino::BelongsToOrganization

  belongs_to :asset, class_name: "Asset"
  belongs_to :model_baseline, class_name: "ModelBaseline", optional: true

  rhino_filters :asset_id, :model_baseline_id, :label, :window_start, :window_end, :load_percent, :completeness_percent, :selected, :eligible
  rhino_sorts :asset_id, :model_baseline_id, :label, :window_start, :window_end, :load_percent, :completeness_percent, :selected, :eligible, :created_at
  rhino_fields :id, :asset_id, :model_baseline_id, :label, :window_start, :window_end, :load_percent, :completeness_percent, :selected, :eligible, :created_at
  rhino_includes :asset, :model_baseline
  rhino_search :label
  rhino_default_sort "-window_start"

  validates :asset_id, presence: true
  validates :label, presence: true, length: { maximum: 255 }
  validates :window_start, presence: true
  validates :window_end, presence: true
  validates :load_percent, numericality: true, allow_nil: true
  validates :completeness_percent, numericality: true, allow_nil: true
  validates :selected, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :eligible, inclusion: { in: [ true, false ] }, allow_nil: true

  validate :window_end_after_start

  def rhino_computed_attributes
    {
      "asset_tag" => asset&.asset_tag,
      "summary" => "#{label} · #{load_percent&.round}% load · #{completeness_percent}% complete"
    }
  end

  private

  def window_end_after_start
    return if window_start.blank? || window_end.blank?
    return if window_end >= window_start

    errors.add(:window_end, "must be after the window start")
  end
end
