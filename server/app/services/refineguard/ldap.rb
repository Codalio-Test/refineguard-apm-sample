# frozen_string_literal: true

module Refineguard
  # The on-prem LDAP / Active Directory credential path and the adapter
  # selection that decides whether a bind is real or simulated
  module Ldap
    class << self
      def configuration
        Configuration.new
      end

      def adapter
        Adapter.for(configuration)
      end

      # 'simulated' | 'directory' — the label the API and UI surface
      def mode_label
        configuration.simulated? ? Configuration::SIMULATED : Configuration::DIRECTORY
      end
    end
  end
end
