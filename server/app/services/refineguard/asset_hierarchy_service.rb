# frozen_string_literal: true

module Refineguard
  # the ISA-95 hierarchy read model.
  #
  # Returns nested Complex → Unit → Train → Asset → Component nodes with a
  # worst-child roll-up of the health state at every level, so the sidebar tree
  # and the /assets browser can show a single node pill per branch.
  class AssetHierarchyService
    class << self
      # @return [Array<Hash>] root nodes
      def tree(organization)
        Refineguard::AssetHierarchyTree.call(organization)
      end

      # @return [Hash] { valid, assets_checked, errors }
      def validate(organization)
        Refineguard::AssetHierarchyValidator.call(organization)
      end
    end
  end
end
