# frozen_string_literal: true

module Refineguard
  # The ISA-95 hierarchy read model
  # Returns nested Complex → Unit → Train → Asset → Component nodes with a
  # worst-child roll-up of the health state at every level, so the sidebar tree
  # and the /assets browser can show a single node pill per branch
  class AssetHierarchyTree
    STATE_RANK = { "Trip" => 0, "Alarm" => 1, "Alert" => 2, "Normal" => 3 }.freeze

    def self.call(organization)
      new(organization).call
    end

    def initialize(organization)
      @organization = organization
    end

    # @return [Array<Hash>] root nodes
    def call
      [ complex_node(unit_nodes + orphan_nodes) ]
    end

    private

    attr_reader :organization

    def unit_nodes
      units.map do |unit|
        children = root_assets_for(unit).map { |asset| asset_node(asset) }
        unit_node(unit, children)
      end
    end

    def orphan_nodes
      orphans = orphan_assets
      return [] if orphans.empty?

      [ unassigned_node(orphans) ]
    end

    def unit_node(unit, children)
      state = rollup(children)
      {
        "id" => "unit-#{unit.id}",
        "record_id" => unit.id,
        "label" => unit.unit_code,
        "name" => unit.unit_name,
        "node_type" => "unit",
        "refinery_area" => unit.refinery_area,
        "health_state" => state,
        "severity" => Refineguard::Severity.badge(state),
        "children" => children
      }
    end

    def unassigned_node(orphans)
      state = worst_state(orphans.map(&:health_state))
      {
        "id" => "unit-unassigned",
        "record_id" => nil,
        "label" => "Unassigned",
        "name" => "Assets without a process unit",
        "node_type" => "unit",
        "health_state" => state,
        "severity" => Refineguard::Severity.badge(state),
        "children" => orphans.map { |asset| asset_node(asset) }
      }
    end

    def complex_node(children)
      state = rollup(children)
      {
        "id" => "complex-root",
        "record_id" => nil,
        "label" => "Refinery Complex",
        "name" => organization.name,
        "node_type" => "complex",
        "health_state" => state,
        "severity" => Refineguard::Severity.badge(state),
        "children" => children
      }
    end

    def asset_node(asset, depth = 0)
      children = child_assets(asset).map { |child| asset_node(child, depth + 1) }
      components = component_nodes(asset)
      own = asset.health_state.presence || "Normal"

      {
        "id" => "asset-#{asset.id}",
        "record_id" => asset.id,
        "asset_tag" => asset.asset_tag,
        "label" => asset.asset_tag,
        "name" => asset.asset_name,
        "node_type" => "asset",
        "equipment_class" => asset.equipment_class,
        "plant_unit_id" => asset.plant_unit_id,
        "health_index" => asset.health_index,
        "health_state" => own,
        "severity" => asset.severity,
        "depth" => depth,
        "children" => children + components,
        "rollup_state" => worst_state(children.map { |c| c["health_state"] } + [ own ])
      }
    end

    def component_nodes(asset)
      asset.asset_components.map do |component|
        {
          "id" => "component-#{component.id}",
          "record_id" => component.id,
          "label" => component.component_name,
          "name" => component.position,
          "node_type" => "component",
          "health_state" => component.health_state,
          "severity" => component.severity,
          "asset_tag" => asset.asset_tag,
          "children" => []
        }
      end
    end

    def rollup(children)
      worst_state(children.map { |child| child["health_state"] })
    end

    def worst_state(states)
      cleaned = states.compact.reject(&:blank?)
      return "Normal" if cleaned.empty?

      cleaned.min_by { |state| STATE_RANK.fetch(state, 99) }
    end

    def units
      @units ||= PlantUnit.where(organization: organization).includes(:assets)
                          .order(:unit_code).to_a
    end

    def assets
      @assets ||= Asset.where(organization: organization).includes(:asset_components)
                       .order(:asset_tag).to_a
    end

    def by_parent
      @by_parent ||= assets.group_by(&:parent_asset_id)
    end

    def root_assets_for(unit)
      root_assets.select { |asset| asset.plant_unit_id == unit.id }
    end

    def orphan_assets
      root_assets.reject { |asset| asset.plant_unit_id.present? }
    end

    def root_assets
      @root_assets ||= by_parent[nil].to_a
    end

    def child_assets(asset)
      by_parent[asset.id].to_a
    end
  end
end
