# frozen_string_literal: true

module Refineguard
  module Cmms
    # The outcome of one transmit attempt
    # `confirmed` is only ever true when a REAL remote system acknowledged the
    # work order, so the dispatch flow can leave `confirmed_at` empty until a
    # genuine confirmation arrives
    Transmission = Struct.new(:transmitted, :confirmed, :confirmation, :error, keyword_init: true) do
      def success?
        transmitted && (error.nil? || error.to_s.empty?)
      end
    end
  end
end
