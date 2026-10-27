# frozen_string_literal: true

class AssetComponent < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable

  belongs_to :asset, class_name: "Asset"
  has_many :historian_tags, class_name: "HistorianTag", dependent: :nullify

  rhino_filters :asset_id, :component_name, :component_type, :position, :bearing_model, :seal_type, :health_state
  rhino_sorts :asset_id, :component_name, :component_type, :position, :bearing_model, :seal_type, :health_state, :created_at
  rhino_fields :id, :asset_id, :component_name, :component_type, :position, :bearing_model, :seal_type, :health_state, :created_at
  rhino_includes :asset
  rhino_search :component_name, :bearing_model, :seal_type

  validates :asset_id, presence: true
  validates :component_name, presence: true, length: { maximum: 255 }
  validates :component_type, length: { maximum: 255 }, allow_nil: true
  validates :position, length: { maximum: 255 }, allow_nil: true
  validates :bearing_model, length: { maximum: 255 }, allow_nil: true
  validates :seal_type, length: { maximum: 255 }, allow_nil: true
  validates :health_state, length: { maximum: 255 }, allow_nil: true

  def severity
    Refineguard::Severity.badge(health_state)
  end

  def rhino_computed_attributes
    {
      "severity" => severity,
      "asset_tag" => asset&.asset_tag
    }
  end
end
