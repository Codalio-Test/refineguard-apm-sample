# frozen_string_literal: true

module Refineguard
  # the 1-minute health evaluation sweep.
  #
  # Every index row is evaluated against its 99th-percentile reconstruction-error
  # threshold; three consecutive breaches transition the asset from Normal to
  # Alert.
  class HealthEvaluationJob < ApplicationJob
    queue_as :default

    def perform(organization_id = nil)
      scope = AssetHealthIndex.order(calculated_at: :desc)
      scope = scope.where(organization_id: organization_id) if organization_id

      scope.limit(500).each do |index|
        Rhino.for_user(nil).in_organization(index.organization).run do
          Refineguard::HealthStateService.evaluate(index)
        end
      end
    end
  end
end
