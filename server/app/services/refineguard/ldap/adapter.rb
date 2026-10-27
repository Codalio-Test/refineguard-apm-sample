# frozen_string_literal: true

module Refineguard
  module Ldap
    # Contract every credential adapter implements. The API and the UI render
    # `SIMULATED` whenever {#simulated?} is true
    class Adapter
      # The adapter selected by configuration. Defaults to the simulated
      # stand-in, so an unconfigured deployment never claims a directory bind
      def self.for(configuration = Refineguard::Ldap.configuration)
        configuration.simulated? ? SimulatedAdapter.new : DirectoryAdapter.new
      end

      def name
        "adapter"
      end

      def simulated?
        false
      end

      def bind(email:, password:)
        raise NotImplementedError, "#{self.class} must implement #bind"
      end
    end
  end
end
