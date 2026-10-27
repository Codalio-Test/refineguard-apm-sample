# frozen_string_literal: true

module Refineguard
  # the historian polling loop.
  #
  # Each pass probes the connector; a link that exceeds the 3000 ms timeout
  # switches to the disk-backed ring buffer, and a recovered link replays the
  # backlog with zero lost points.
  class HistorianPollJob < ApplicationJob
    queue_as :default

    def perform(organization_id = nil)
      scope = HistorianConnector.all
      scope = scope.where(organization_id: organization_id) if organization_id

      scope.find_each do |connector|
        Rhino.for_user(nil).in_organization(connector.organization).run do
          Refineguard::HistorianBufferService.ingest(connector, points: 1)
          Refineguard::HistorianBufferService.test_connection(connector)
        end
      end
    end
  end
end
