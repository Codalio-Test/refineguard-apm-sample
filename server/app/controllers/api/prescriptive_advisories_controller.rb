# frozen_string_literal: true

module Api
  # CMMS dispatch and superintendent derate approval.
  class PrescriptiveAdvisoriesController < BaseController
    # Every action operates on one advisory and funnels through the same
    # tenancy-scoped lookup, so the find-and-authorize is declared once
    before_action :load_advisory!

    # POST /api/{organization}/prescriptive_advisories/:id/dispatch_work_order
    def dispatch_work_order
      return if deny!(PrescriptiveAdvisoryPolicy, :dispatch_work_order?, @advisory)

      result = Refineguard::CmmsDispatchService.dispatch(
        advisory: @advisory,
        user: current_user,
        cmms_type: params[:cmms_type].presence || "SAP PM",
        priority: params[:priority].presence,
        required_by: params[:required_by].presence,
        force_failure: simulate_failure_requested?
      )

      render json: dispatch_payload(result), status: dispatch_status(result)
    end

    # POST /api/{organization}/prescriptive_advisories/:id/approve_derate
    # Approving a derating advisory logs the restriction to the DCS shift
    # handover log with a timestamped superintendent sign-off
    def approve_derate
      return if deny!(PrescriptiveAdvisoryPolicy, :approve_derate?, @advisory)

      write_derate_approval!

      render json: Refineguard::Serializers::PrescriptiveAdvisorySerializer.new(@advisory)
                       .derate_approval
    rescue ActiveRecord::RecordInvalid => e
      # An out-of-range throttle (a derate is a 0–100% of design flow) is a
      # validation failure, not a server error: nothing is written and the
      # caller gets the unified 422 envelope
      render_errors(e.record.errors.full_messages, :unprocessable_entity)
    end

    # POST /api/{organization}/prescriptive_advisories/:id/evaluate_standby
    # Generate a standby switchover advisory for the incident
    def evaluate_standby
      return if deny!(PrescriptiveAdvisoryPolicy, :evaluate_standby?, @advisory)

      incident = @advisory.diagnostic_incident
      if incident.nil?
        return render json: { errors: [ "Advisory has no linked diagnostic incident" ] },
                      status: :unprocessable_entity
      end

      switchover = Refineguard::StandbyCheckService.evaluate(incident)

      if switchover.nil?
        return render json: { errors: [ "No standby twin is available for this asset" ] },
                      status: :unprocessable_entity
      end

      render json: Refineguard::Serializers::PrescriptiveAdvisorySerializer.new(switchover)
                       .standby_switchover,
             status: :created
    end

    private

    def load_advisory!
      @advisory = Rhino.query(PrescriptiveAdvisory).find_by(id: params[:id])
      return if @advisory

      render_errors([ "Advisory not found" ], :not_found)
    end

    def dispatch_payload(result)
      payload = {
        success: result.success,
        adapter: result.simulated ? "simulated" : "http",
        simulated: result.simulated,
        duration_ms: result.duration_ms,
        budget_ms: result.budget_ms,
        advisory_status: @advisory.reload.status,
        errors: result.errors
      }
      if result.work_order
        payload[:work_order] =
          Refineguard::Serializers::CmmsWorkOrderSerializer.new(result.work_order).dispatch_payload
      end
      payload
    end

    def dispatch_status(result)
      return :conflict if result.conflict
      return :created if result.success

      :unprocessable_entity
    end

    # The failure-branch hook is a test affordance only; a client can never force
    # a production dispatch to fail
    def simulate_failure_requested?
      Rails.env.test? && params[:simulate_failure].to_s == "true"
    end

    def write_derate_approval!
      incident = @advisory.diagnostic_incident
      asset = incident&.asset
      unit = asset&.plant_unit

      ShiftLogEntry.transaction do
        @advisory.update!(
          throttle_percentage: params[:throttle_percentage].presence&.to_f ||
                                 @advisory.throttle_percentage,
          derate_approved_by_id: current_user&.id,
          derate_approved_at: Time.current,
          status: PrescriptiveAdvisory::STATUS_READY
        )

        ShiftLogEntry.create!(shift_log_attributes(asset, unit))
      end

      Refineguard::SecurityAuditWriter.call(
        organization: current_organization, user: current_user,
        action_type: "DERATE_APPROVAL", severity: "warning", result: "Success",
        entity_affected: "PrescriptiveAdvisory:#{@advisory.id}",
        details: { "asset_tag" => asset&.asset_tag,
                   "throttle_percentage" => @advisory.throttle_percentage,
                   "signed_off_at" => @advisory.derate_approved_at&.iso8601 }
      )
    end

    def shift_log_attributes(asset, unit)
      throttle = @advisory.throttle_percentage.to_f.round
      {
        organization: current_organization,
        plant_unit_id: unit&.id,
        asset_id: asset&.id,
        author_id: current_user&.id,
        acknowledged_by_id: current_user&.id,
        occurred_at: Time.current,
        shift_label: current_shift_label,
        event_type: "Derate approval",
        severity: "warning",
        message: "Derate approved for #{asset&.asset_tag}: throttle to #{throttle}% flow.",
        unit_status: "Running at reduced rate (#{throttle}%)",
        outstanding_actions: @advisory.recommended_action,
        steps_completed: 0,
        steps_total: Array(@advisory.action_steps_json).length
      }
    end

    def current_shift_label
      hour = Time.current.hour
      return "Night shift" if hour < 6
      return "Day shift" if hour < 18

      "Evening shift"
    end
  end
end
