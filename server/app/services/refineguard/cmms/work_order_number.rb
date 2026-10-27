# frozen_string_literal: true

module Refineguard
  module Cmms
    # Allocates external work-order numbers from a database sequence, so the
    # number is concurrency-safe and monotonic instead of derived from the row id
    class WorkOrderNumber
      SEQUENCE_NAME = "cmms_work_order_number_seq"

      class << self
        def next(cmms_type)
          format("%<prefix>s-%<sequence>06d", prefix: prefix(cmms_type), sequence: next_value)
        end

        private

        def prefix(cmms_type)
          cmms_type.to_s.include?("Maximo") ? "MAX-WO" : "SAP-WO"
        end

        def next_value
          ActiveRecord::Base.connection.select_value("SELECT nextval('#{SEQUENCE_NAME}')")
        end
      end
    end
  end
end
