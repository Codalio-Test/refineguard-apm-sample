# frozen_string_literal: true

# High-volume time-series row. Pagination is mandatory; filters are the read
# pattern (asset/unit trend and spectral synchronization).
class TelemetryRecord < Rhino::RhinoModel
  include Rhino::BelongsToOrganization

  belongs_to :historian_tag, class_name: "HistorianTag"

  rhino_filters :historian_tag_id, :recorded_at, :recorded_value, :data_quality_flag
  rhino_sorts :historian_tag_id, :recorded_at, :recorded_value, :data_quality_flag, :created_at
  rhino_fields :id, :historian_tag_id, :recorded_at, :recorded_value, :data_quality_flag, :created_at
  rhino_includes :historian_tag
  rhino_default_sort "-recorded_at"

  validates :historian_tag_id, presence: true
  validates :recorded_at, presence: true
  validates :recorded_value, presence: true, numericality: true
  validates :data_quality_flag, length: { maximum: 255 }, allow_nil: true

  def rhino_computed_attributes
    { "tag_path" => historian_tag&.tag_path, "asset_tag" => historian_tag&.asset&.asset_tag }
  end
end
