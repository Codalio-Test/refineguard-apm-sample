# frozen_string_literal: true

module Refineguard
  # The on-prem CMMS bridge (SAP PM / IBM Maximo) and the adapter selection that
  # decides whether a dispatch is transmitted for real or simulated
  module Cmms
    class << self
      def configuration
        Configuration.new
      end

      def adapter
        Adapter.for(configuration)
      end
    end
  end
end
