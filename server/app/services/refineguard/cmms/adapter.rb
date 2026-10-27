# frozen_string_literal: true

module Refineguard
  module Cmms
    # Contract every CMMS adapter implements
    # The API and the UI render `SIMULATED` whenever {#simulated?} is true, and
    # {#budget_ms} is nil for an adapter that makes no network call (so the
    # "within N ms" claim is only ever made for a timed, real transmission)
    class Adapter
      # The adapter selected by configuration. Defaults to the simulated
      # stand-in, so an unconfigured deployment can never claim a transmission
      def self.for(configuration = Refineguard::Cmms.configuration)
        configuration.simulated? ? SimulatedAdapter.new : HttpAdapter.new
      end

      def name
        "adapter"
      end

      def simulated?
        false
      end

      # The real network budget in ms, or nil when no network call is made
      def budget_ms
        nil
      end

      def transmit(_payload)
        raise NotImplementedError, "#{self.class} must implement #transmit"
      end
    end
  end
end
