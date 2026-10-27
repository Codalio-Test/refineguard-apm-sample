# frozen_string_literal: true

# A historian sensor point bound to a digital-twin variable.
#
# staleness and quality are computed on the read path so a tag that is
# invalid, stale for more than 60 s, or reporting a bad OPC quality flag is
# flagged (red row) and blocks digital-twin activation for its asset.
class HistorianTag < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable

  STALE_THRESHOLD_SECONDS = 60
  HISTORIAN_TYPES = %w[OSIsoft_PI Honeywell_PHD Yokogawa_Exaquantum].freeze
  QUALITY_BAD_PREFIXES = [ "Bad", "Uncertain", "Invalid", "Stale" ].freeze

  belongs_to :asset, class_name: "Asset", optional: true
  belongs_to :asset_component, class_name: "AssetComponent", optional: true
  belongs_to :historian_connector, class_name: "HistorianConnector", optional: true
  has_many :telemetry_records, class_name: "TelemetryRecord", dependent: :destroy
  has_many :spectrum_snapshots, class_name: "SpectrumSnapshot", dependent: :nullify

  rhino_filters :asset_id, :asset_component_id, :historian_connector_id, :historian_type, :source_tag_name, :tag_path, :measurement_type, :engineering_unit, :scan_rate_ms, :deadband_val, :scan_frequency_hz, :quality_status, :last_value, :last_validated_at, :stale_seconds, :mapped, :mapping_state, :compatible
  rhino_sorts :asset_id, :asset_component_id, :historian_connector_id, :historian_type, :source_tag_name, :tag_path, :measurement_type, :engineering_unit, :scan_rate_ms, :deadband_val, :scan_frequency_hz, :quality_status, :last_value, :last_validated_at, :stale_seconds, :mapped, :mapping_state, :compatible, :created_at
  rhino_fields :id, :asset_id, :asset_component_id, :historian_connector_id, :historian_type, :source_tag_name, :tag_path, :measurement_type, :engineering_unit, :scan_rate_ms, :deadband_val, :scan_frequency_hz, :quality_status, :last_value, :last_validated_at, :stale_seconds, :mapped, :mapping_state, :compatible, :created_at
  rhino_includes :asset, :asset_component, :historian_connector

  # The tag-mapping table searches by tag path and filters by connector/unit.
  rhino_search :tag_path, :source_tag_name, :measurement_type

  validates :historian_type, presence: true, inclusion: { in: HISTORIAN_TYPES }
  validates :source_tag_name, presence: true, length: { maximum: 255 }
  validates :tag_path, presence: true, uniqueness: { scope: :organization_id },
                       length: { maximum: 255 }
  validates :measurement_type, length: { maximum: 255 }, allow_nil: true
  validates :engineering_unit, length: { maximum: 255 }, allow_nil: true
  validates :scan_rate_ms, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :deadband_val, numericality: true, allow_nil: true
  validates :scan_frequency_hz, numericality: true, allow_nil: true
  validates :quality_status, length: { maximum: 255 }, allow_nil: true
  validates :last_value, numericality: true, allow_nil: true
  validates :mapped, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :mapping_state, length: { maximum: 255 }, allow_nil: true
  validates :compatible, inclusion: { in: [ true, false ] }, allow_nil: true

  # Recomputed on read from `last_validated_at`.
  #
  # The `stale_seconds` column carries the staleness the connector measured at
  # its last poll; it wins when present so the tag-mapping table shows a stable,
  # auditable number. Rows that have never been polled fall back to a live
  # computation against `last_validated_at`.
  def computed_stale_seconds
    return stale_seconds if stale_seconds.present?
    return nil if last_validated_at.nil?

    [ (Time.current - last_validated_at).to_i, 0 ].max
  end

  def stale?
    secs = computed_stale_seconds
    !secs.nil? && secs > STALE_THRESHOLD_SECONDS
  end

  def bad_quality?
    quality_status.present? && QUALITY_BAD_PREFIXES.any? { |q| quality_status.start_with?(q) }
  end

  # A tag blocks twin activation when its path is invalid, it is stale, or its
  # OPC quality flag is bad.
  def healthy?
    tag_path.present? && !stale? && !bad_quality?
  end

  def rhino_computed_attributes
    {
      "stale_seconds" => computed_stale_seconds,
      "stale" => stale?,
      "healthy" => healthy?,
      "severity" => healthy? ? "healthy" : "critical",
      "asset_tag" => asset&.asset_tag,
      "component_name" => asset_component&.component_name
    }
  end
end
