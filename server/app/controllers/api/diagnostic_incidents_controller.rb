# frozen_string_literal: true

module Api
  # Diagnostic finding sign-off and the persisted anomaly acknowledgement
  # transition.
  class DiagnosticIncidentsController < BaseController
    # POST /api/{organization}/diagnostic_incidents/:id/acknowledge
    def acknowledge
      incident = Rhino.query(DiagnosticIncident).find_by(id: params[:id])
      return render_errors([ "Diagnostic incident not found" ], :not_found) if incident.nil?

      return if deny!(DiagnosticIncidentPolicy, :acknowledge?, incident)

      incident.acknowledge!(current_user)

      Refineguard::SecurityAuditWriter.call(
        organization: current_organization, user: current_user,
        action_type: "ACKNOWLEDGE",
        severity: "info",
        result: "Success",
        entity_affected: incident.incident_code.presence || "DiagnosticIncident:#{incident.id}",
        details: { "status" => incident.status, "acknowledged_at" => incident.acknowledged_at&.iso8601,
                   "asset_tag" => incident.asset&.asset_tag }
      )

      render json: Refineguard::Serializers::DiagnosticIncidentSerializer.new(incident).acknowledgement
    end

    #  POST /api/{organization}/diagnostic_incidents/:id/sign_off
    def sign_off
      incident = Rhino.query(DiagnosticIncident).find_by(id: params[:id])
      return render_errors([ "Diagnostic incident not found" ], :not_found) if incident.nil?

      return if deny!(DiagnosticIncidentPolicy, :sign_off?, incident)

      finding = params[:finding] || params
      # The sign-off and the propagation into prescriptive planning are ONE
      # logical write: if a propagated advisory fails to save, the finding itself
      # must not be left half-applied, so both run in a single transaction.
      propagated = DiagnosticIncident.transaction do
        incident.sign_off!(current_user, finding.to_unsafe_h.transform_keys(&:to_s))
        propagate_to_planning(incident)
      end

      Refineguard::SecurityAuditWriter.call(
        organization: current_organization, user: current_user,
        action_type: "DIAGNOSTIC_SIGN_OFF", severity: "warning", result: "Success",
        entity_affected: incident.incident_code.presence || "DiagnosticIncident:#{incident.id}",
        details: { "finding_status" => incident.finding_status,
                   "failure_mechanism" => incident.failure_mechanism,
                   "signed_off_at" => incident.signed_off_at&.iso8601,
                   "propagated_advisories" => propagated }
      )

      render json: Refineguard::Serializers::DiagnosticIncidentSerializer.new(incident)
                       .sign_off(propagated_advisories: propagated)
    rescue ActiveRecord::RecordInvalid => e
      # A propagated advisory that cannot be saved rolls the whole write back
      # (transaction above); report it with the unified 422 envelope.
      render_errors(e.record.errors.full_messages, :unprocessable_entity)
    end

    private

    # Every open advisory for the incident inherits the signed-off finding.
    def propagate_to_planning(incident)
      incident.prescriptive_advisories.map do |advisory|
        advisory.update!(
          recommended_action: advisory.recommended_action.presence ||
                              "Address #{incident.failure_mechanism || 'confirmed defect'} on " \
                              "#{incident.asset&.asset_tag}.",
          status: advisory.status.presence || PrescriptiveAdvisory::STATUS_READY
        )
        advisory.id
      end
    end
  end
end
