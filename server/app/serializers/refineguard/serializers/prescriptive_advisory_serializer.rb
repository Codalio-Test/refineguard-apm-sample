# frozen_string_literal: true

module Refineguard
  module Serializers
    # Response shapes for the prescriptive-advisory custom actions
    class PrescriptiveAdvisorySerializer < Base
      # the derate sign-off the shift handover log records
      def derate_approval
        {
          id: record.id,
          status: record.status,
          throttle_percentage: record.throttle_percentage,
          derate_approved_by_id: record.derate_approved_by_id,
          derate_approved_at: record.derate_approved_at&.iso8601,
          shift_log_written: true
        }
      end

      # the generated standby switchover advisory. `record` is the
      # switchover advisory returned by StandbyCheckService
      def standby_switchover
        {
          id: record.id,
          advisory_code: record.advisory_code,
          standby_asset_id: record.standby_asset_id,
          standby_asset_tag: record.standby_asset&.asset_tag,
          standby_ready: record.standby_ready,
          standby_checks_json: record.standby_checks_json,
          urgency: record.urgency,
          status: record.status
        }
      end
    end
  end
end
