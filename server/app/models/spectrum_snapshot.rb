# frozen_string_literal: true

# One captured vibration spectrum for one channel of one asset, plus its
# waterfall column and orbit trajectory payloads.
class SpectrumSnapshot < Rhino::RhinoModel
  include Rhino::BelongsToOrganization

  belongs_to :asset, class_name: "Asset"
  belongs_to :historian_tag, class_name: "HistorianTag", optional: true

  rhino_filters :asset_id, :historian_tag_id, :captured_at, :channel, :line_resolution, :sample_rate_hz, :rms_velocity, :running_speed_hz, :cursor_hz, :cursor_amplitude, :cursor_order, :delta_baseline, :waterfall_horizon_days
  rhino_sorts :asset_id, :historian_tag_id, :captured_at, :channel, :line_resolution, :sample_rate_hz, :rms_velocity, :running_speed_hz, :cursor_hz, :cursor_amplitude, :cursor_order, :delta_baseline, :waterfall_horizon_days, :created_at
  rhino_fields :id, :asset_id, :historian_tag_id, :captured_at, :channel, :line_resolution, :sample_rate_hz, :rms_velocity, :running_speed_hz, :cursor_hz, :cursor_amplitude, :cursor_order, :delta_baseline, :spectrum_json, :harmonics_json, :bearing_markers_json, :waterfall_json, :orbit_json, :waterfall_horizon_days, :created_at
  rhino_includes :asset, :historian_tag
  rhino_default_sort "-captured_at"

  validates :asset_id, presence: true
  validates :captured_at, presence: true
  validates :channel, presence: true, length: { maximum: 255 }
  validates :line_resolution, numericality: { only_integer: true }, allow_nil: true
  validates :sample_rate_hz, numericality: true, allow_nil: true
  validates :rms_velocity, numericality: true, allow_nil: true
  validates :running_speed_hz, numericality: true, allow_nil: true
  validates :cursor_hz, numericality: true, allow_nil: true
  validates :cursor_amplitude, numericality: true, allow_nil: true
  validates :cursor_order, numericality: true, allow_nil: true
  validates :delta_baseline, numericality: true, allow_nil: true
  validates :waterfall_horizon_days, numericality: { only_integer: true }, allow_nil: true

  def rhino_computed_attributes
    {
      "asset_tag" => asset&.asset_tag,
      "spectrum" => spectrum_json || [],
      "harmonics" => harmonics_json || [],
      "bearing_markers" => bearing_markers_json || [],
      "waterfall" => waterfall_json || [],
      "orbit" => orbit_json || []
    }
  end
end
