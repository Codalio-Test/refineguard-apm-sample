# frozen_string_literal: true

module Refineguard
  module Cmms
    # Persists the outcome of a dispatch attempt and appends the matching audit
    # event. Kept out of the dispatch service so the orchestration stays a thin
    # read of the transmit result
    class DispatchRecorder
      class << self
        # A transmitted work order. `confirmed_at` is only stamped when a REAL
        # remote system confirmed the transmission
        def dispatch!(advisory:, user:, cmms_type:, priority:, required_by:, payload:,
                      transmission:, duration_ms:)
          order = nil
          CmmsWorkOrder.transaction do
            order = CmmsWorkOrder.create!(
              organization: advisory.organization,
              prescriptive_advisory: advisory,
              user: user,
              cmms_type: cmms_type,
              external_order_number: WorkOrderNumber.next(cmms_type),
              sync_status: CmmsWorkOrder::SYNC_DISPATCHED,
              priority: priority,
              required_by: required_by,
              dispatched_at: Time.current,
              confirmed_at: transmission.confirmed ? Time.current : nil,
              work_order_payload: payload.merge("confirmation" => transmission.confirmation),
              material_reservations_json: WorkOrderPayload.reservations_for(advisory)
            )

            advisory.update!(status: PrescriptiveAdvisory::STATUS_DISPATCHED)
          end

          audit(advisory, user, order, cmms_type, duration_ms)
          order
        end

        # A failed transmit: the advisory reverts so the planner can retry
        def failure!(advisory:, user:, cmms_type:, priority:, required_by:, payload:,
                     message:, duration_ms:)
          order = nil
          CmmsWorkOrder.transaction do
            order = CmmsWorkOrder.create!(
              organization: advisory.organization,
              prescriptive_advisory: advisory,
              user: user,
              cmms_type: cmms_type,
              sync_status: CmmsWorkOrder::SYNC_PENDING,
              priority: priority,
              required_by: required_by,
              dispatched_at: nil,
              work_order_payload: payload,
              error_message: message
            )

            advisory.update!(status: PrescriptiveAdvisory::STATUS_READY)
          end

          SecurityAuditWriter.call(
            organization: advisory.organization, user: user,
            action_type: "DISPATCH_WORK_ORDER", severity: "critical", result: "Failure",
            entity_affected: "CmmsWorkOrder:#{order.id}",
            details: { "target_system" => cmms_type, "error" => message, "duration_ms" => duration_ms }
          )
          order
        end

        private

        def audit(advisory, user, order, cmms_type, duration_ms)
          SecurityAuditWriter.call(
            organization: advisory.organization, user: user,
            action_type: "DISPATCH_WORK_ORDER", severity: "warning", result: "Success",
            entity_affected: "CmmsWorkOrder:#{order.id}",
            details: {
              "target_system" => cmms_type,
              "external_order_number" => order.external_order_number,
              "advisory_code" => advisory.advisory_code,
              "duration_ms" => duration_ms
            }
          )
        end
      end
    end
  end
end
