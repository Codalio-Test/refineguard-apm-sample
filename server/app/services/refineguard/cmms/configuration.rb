# frozen_string_literal: true

module Refineguard
  module Cmms
    # Reads the on-prem CMMS bridge configuration from the environment
    # REFINEGUARD_CMMS_ADAPTER 'simulated' (default) | 'http'
    # REFINEGUARD_CMMS_URL the real bridge endpoint (required for 'http')
    # REFINEGUARD_CMMS_TIMEOUT_MS the real network timeout in ms (default 3000)
    class Configuration
      SIMULATED = "simulated"
      HTTP = "http"

      def adapter_name
        (ENV["REFINEGUARD_CMMS_ADAPTER"].presence || SIMULATED).downcase
      end

      def simulated?
        adapter_name != HTTP
      end

      def endpoint
        ENV["REFINEGUARD_CMMS_URL"].presence
      end

      def timeout_ms
        Integer(ENV.fetch("REFINEGUARD_CMMS_TIMEOUT_MS", "3000"))
      rescue ArgumentError, TypeError
        3000
      end
    end
  end
end
