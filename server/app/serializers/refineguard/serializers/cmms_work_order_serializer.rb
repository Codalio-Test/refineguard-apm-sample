# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shape for the CMMS work-order custom actions
    class CmmsWorkOrderSerializer < Base
      def dispatch_payload
        {
          id: record.id,
          cmms_type: record.cmms_type,
          external_order_number: record.external_order_number,
          sync_status: record.sync_status,
          priority: record.priority,
          required_by: record.required_by,
          dispatched_at: record.dispatched_at&.iso8601,
          confirmed_at: record.confirmed_at&.iso8601,
          material_reservations_json: record.material_reservations_json,
          work_order_payload: record.work_order_payload,
          error_message: record.error_message
        }
      end
    end
  end
end
