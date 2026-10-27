# frozen_string_literal: true

module Refineguard
  module Cmms
    # The clearly-labelled stand-in used when no CMMS bridge is configured
    # It performs NO network call: it reports the payload as handed to the
    # simulated connector and NEVER confirms, so `confirmed_at` stays empty and
    # both the API and the UI surface SIMULATED
    class SimulatedAdapter < Adapter
      SIMULATED_MESSAGE =
        "SIMULATED: no CMMS endpoint is configured; the work order was not transmitted " \
        "and is not confirmed."

      def name
        "simulated"
      end

      def simulated?
        true
      end

      def transmit(_payload)
        Transmission.new(
          transmitted: true,
          confirmed: false,
          confirmation: { "simulated" => true, "message" => SIMULATED_MESSAGE },
          error: nil
        )
      end
    end
  end
end
