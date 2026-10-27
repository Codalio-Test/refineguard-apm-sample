# frozen_string_literal: true

module Refineguard
  # Prescriptive dispatch to the on-prem SAP PM / IBM Maximo bridge
  # Orchestrates: idempotency, input validation, the configured CMMS adapter and
  # the persisted outcome. The payload assembly, the numbering and the recording
  # live in their own collaborators (WorkOrderPayload, WorkOrderNumber
  # DispatchRecorder) so this class stays a readable coordination point
  class CmmsDispatchService
    ALREADY_DISPATCHED = "The advisory has already been dispatched"

    Result = Struct.new(:success, :work_order, :errors, :duration_ms, :conflict, :simulated,
                        :budget_ms, keyword_init: true)

    class << self
      # @param force_failure [Boolean] test-only hook to exercise the failure path
      # @param adapter [Refineguard::Cmms::Adapter] the transmit adapter
      def dispatch(advisory:, user:, cmms_type: "SAP PM", priority: nil, required_by: nil,
                   force_failure: false, adapter: Refineguard::Cmms::Adapter.for)
        started = monotonic

        incident = advisory.diagnostic_incident
        asset = incident&.asset
        errors = validation_errors(priority, incident, asset)
        return result(success: false, errors: errors, started: started, adapter: adapter) if errors.any?

        payload = Refineguard::Cmms::WorkOrderPayload.build(
          advisory: advisory, incident: incident, asset: asset, cmms_type: cmms_type,
          priority: priority, required_by: required_by
        )

        # The idempotency check and the work-order write happen under ONE row lock
        # on the advisory. `with_lock` reloads the row and takes a
        # `SELECT ... FOR UPDATE`, so a second concurrent dispatch blocks until
        # the first commits, then observes the advisory is already dispatched and
        # is refused with 409 instead of writing a duplicate work order.
        advisory.with_lock do
          next conflict(advisory, started, adapter) if dispatched?(advisory)

          perform(advisory, user, cmms_type, priority, required_by, payload, adapter, started,
                  force_failure)
        end
      rescue ActiveRecord::RecordInvalid => e
        result(success: false, errors: e.record.errors.full_messages, started: started,
               adapter: adapter)
      end

      private

      def perform(advisory, user, cmms_type, priority, required_by, payload, adapter, started,
                  force_failure)
        if force_failure
          return failure(advisory, user, cmms_type, priority, required_by, payload,
                         message: "CMMS connector did not acknowledge",
                         duration_ms: elapsed(started), adapter: adapter)
        end

        transmission = adapter.transmit(payload)
        return transmitted_failure(advisory, user, cmms_type, priority, required_by, payload,
                                   transmission, adapter, started) unless transmission.transmitted

        order = Refineguard::Cmms::DispatchRecorder.dispatch!(
          advisory: advisory, user: user, cmms_type: cmms_type, priority: priority,
          required_by: required_by, payload: payload, transmission: transmission,
          duration_ms: elapsed(started)
        )
        result(success: true, work_order: order, started: started, adapter: adapter)
      end

      def transmitted_failure(advisory, user, cmms_type, priority, required_by, payload,
                              transmission, adapter, started)
        failure(advisory, user, cmms_type, priority, required_by, payload,
                message: transmission.error.presence || "CMMS connector did not acknowledge",
                duration_ms: elapsed(started), adapter: adapter)
      end

      def failure(advisory, user, cmms_type, priority, required_by, payload, message:, duration_ms:, adapter:)
        order = Refineguard::Cmms::DispatchRecorder.failure!(
          advisory: advisory, user: user, cmms_type: cmms_type, priority: priority,
          required_by: required_by, payload: payload, message: message, duration_ms: duration_ms
        )
        Result.new(success: false, work_order: order, errors: [ message ], duration_ms: duration_ms,
                   conflict: false, simulated: adapter.simulated?, budget_ms: adapter.budget_ms)
      end

      def conflict(advisory, started, adapter)
        result(success: false, errors: [ ALREADY_DISPATCHED ], started: started, adapter: adapter,
               conflict: true)
      end

      def dispatched?(advisory)
        advisory.status == PrescriptiveAdvisory::STATUS_DISPATCHED
      end

      def validation_errors(priority, incident, asset)
        errors = []
        errors << "A maintenance priority is required" if priority.blank?
        errors << "The advisory has no linked diagnostic incident" if incident.nil?
        errors << "The advisory has no linked asset" if asset.nil?
        errors
      end

      def result(success:, started:, adapter:, work_order: nil, errors: [], conflict: false)
        Result.new(success: success, work_order: work_order, errors: errors,
                   duration_ms: elapsed(started), conflict: conflict,
                   simulated: adapter.simulated?, budget_ms: adapter.budget_ms)
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed(started)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      end
    end
  end
end
