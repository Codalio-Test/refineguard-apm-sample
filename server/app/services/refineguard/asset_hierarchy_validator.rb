# frozen_string_literal: true

module Refineguard
  # The asset-hierarchy validation contract: unique tags, parent integrity
  # required metadata and historian bindings
  class AssetHierarchyValidator
    REQUIRED_METADATA = %w[asset_name equipment_class rated_rpm bearing_de_model
                           bearing_nde_model].freeze

    def self.call(organization)
      new(organization).call
    end

    def initialize(organization)
      @organization = organization
    end

    def call
      errors = duplicate_tag_errors + assets.flat_map { |asset| asset_errors(asset) }
      { "valid" => errors.empty?, "assets_checked" => assets.length, "errors" => errors }
    end

    private

    def assets
      @assets ||= Asset.where(organization: @organization).to_a
    end

    def duplicate_tag_errors
      assets.group_by(&:asset_tag)
            .select { |_tag, rows| rows.length > 1 }
            .keys
            .map { |tag| { "type" => "duplicate_tag", "asset_tag" => tag } }
    end

    def asset_errors(asset)
      errors = []
      missing = missing_metadata(asset)
      errors << { "type" => "missing_metadata", "asset_tag" => asset.asset_tag,
                  "fields" => missing } if missing.any?
      errors << invalid_parent_error(asset) if invalid_parent?(asset)
      errors << { "type" => "missing_historian_binding", "asset_tag" => asset.asset_tag } unless bound?(asset)
      errors
    end

    def missing_metadata(asset)
      REQUIRED_METADATA.select { |field| asset.public_send(field).blank? }
    end

    def invalid_parent?(asset)
      asset.parent_asset_id.present? && assets.none? { |candidate| candidate.id == asset.parent_asset_id }
    end

    def invalid_parent_error(asset)
      { "type" => "invalid_parent", "asset_tag" => asset.asset_tag,
        "parent_asset_id" => asset.parent_asset_id }
    end

    def bound?(asset)
      asset.historian_tags.exists?
    end
  end
end
