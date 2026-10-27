# frozen_string_literal: true

module Api
  # Connector probe, ring-buffer transition and loss-free replay.
  class HistorianConnectorsController < BaseController
    # POST /api/{organization}/historian_connectors/:id/test_connection
    def test_connection
      connector = Rhino.query(HistorianConnector).find_by(id: params[:id])

      if connector.nil?
        return render_errors([ "Historian connector not found" ], :not_found)
      end

      return if deny!(HistorianConnectorPolicy, :test_connection?, connector)

      simulated = params[:simulated_latency_ms].presence&.to_i
      pending = params[:pending_points].presence
      result = Refineguard::HistorianBufferService.test_connection(
        connector, simulated_latency_ms: simulated,
                   pending_points: pending && pending.to_i
      )

      Refineguard::SecurityAuditWriter.call(
        organization: current_organization, user: current_user,
        action_type: "HISTORIAN_CONNECTION_TEST",
        severity: result[:buffering] ? "warning" : "info",
        result: "Success",
        entity_affected: connector.connector_name,
        details: { "latency_ms" => result[:poll_latency_ms], "buffering" => result[:buffering],
                   "replayed" => result[:replayed], "lost" => result[:lost] }
      )

      render json: Refineguard::Serializers::HistorianConnectorSerializer.new(connector).probe(result)
    end
  end
end
