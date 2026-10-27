# frozen_string_literal: true

# One evaluation of the multivariate Asset Health Index for one asset.
class AssetHealthIndex < Rhino::RhinoModel
  include Rhino::BelongsToOrganization

  belongs_to :asset, class_name: "Asset"

  rhino_filters :asset_id, :calculated_at, :health_score, :health_delta, :anomaly_confidence, :health_state, :reconstruction_error, :threshold_p99, :consecutive_breach_intervals, :iso_severity_category
  rhino_sorts :asset_id, :calculated_at, :health_score, :health_delta, :anomaly_confidence, :health_state, :reconstruction_error, :threshold_p99, :consecutive_breach_intervals, :iso_severity_category, :created_at
  rhino_fields :id, :asset_id, :calculated_at, :health_score, :health_delta, :anomaly_confidence, :health_state, :contributing_factors_json, :envelope_checks_json, :reconstruction_error, :threshold_p99, :consecutive_breach_intervals, :iso_severity_category, :created_at
  rhino_includes :asset
  rhino_default_sort "-calculated_at"

  validates :asset_id, presence: true
  validates :calculated_at, presence: true
  validates :health_score, presence: true,
                           numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :health_delta, numericality: true, allow_nil: true
  validates :anomaly_confidence, numericality: true, allow_nil: true
  validates :health_state, length: { maximum: 255 }, allow_nil: true
  validates :reconstruction_error, numericality: true, allow_nil: true
  validates :threshold_p99, numericality: true, allow_nil: true
  validates :consecutive_breach_intervals, numericality: { only_integer: true }, allow_nil: true
  validates :iso_severity_category, length: { maximum: 255 }, allow_nil: true

  def severity
    Refineguard::Severity.badge(health_state)
  end

  # Ranked attribution: the contributing factors ordered by weight, normalised to
  # percentages, ready for the prototype's attribution bars.
  def attribution
    factors = contributing_factors_json
    return [] unless factors.is_a?(Hash)

    total = factors.values.sum { |v| v.is_a?(Hash) ? v["weight"].to_f : v.to_f }
    factors.map do |name, value|
      weight = value.is_a?(Hash) ? value["weight"].to_f : value.to_f
      {
        "label" => name,
        "weight" => weight.round(4),
        "percent" => total.positive? ? (weight / total * 100).round(1) : 0.0,
        "z_score" => value.is_a?(Hash) ? value["z_score"] : nil,
        "status" => value.is_a?(Hash) ? value["status"] : nil
      }
    end.sort_by { |f| -f["weight"] }
  end

  def rhino_computed_attributes
    {
      "severity" => severity,
      "attribution" => attribution,
      "envelope_checks" => envelope_checks_json || [],
      "asset_tag" => asset&.asset_tag
    }
  end
end
