# frozen_string_literal: true

class PlantUnit < Rhino::RhinoModel
  include Rhino::BelongsToOrganization
  include SoftDeletable

  has_many :assets, class_name: "Asset", dependent: :nullify
  has_many :shift_log_entries, class_name: "ShiftLogEntry", dependent: :nullify

  rhino_filters :unit_code, :unit_name, :unit_type, :refinery_area, :throughput_target_bpd, :rate_percent, :exposure_usd_per_day
  rhino_sorts :unit_code, :unit_name, :unit_type, :refinery_area, :throughput_target_bpd, :rate_percent, :exposure_usd_per_day, :created_at
  rhino_fields :id, :unit_code, :unit_name, :unit_type, :refinery_area, :description, :throughput_target_bpd, :rate_percent, :exposure_usd_per_day, :derate_recommendation, :created_at
  rhino_search :unit_code, :unit_name, :description

  validates :unit_code, presence: true, length: { maximum: 255 }
  validates :unit_name, presence: true, length: { maximum: 255 }
  validates :unit_type, length: { maximum: 255 }, allow_nil: true
  validates :refinery_area, length: { maximum: 255 }, allow_nil: true
  validates :throughput_target_bpd, numericality: true, allow_nil: true
  validates :rate_percent, numericality: true, allow_nil: true
  validates :exposure_usd_per_day, numericality: true, allow_nil: true

  # `name` is the key the locked unit-risk matrix and the fleet unit filter read.
  def rhino_computed_attributes
    {
      "name" => unit_code,
      "exposure_percent" => rate_percent,
      "assets_count" => assets.count
    }
  end
end
