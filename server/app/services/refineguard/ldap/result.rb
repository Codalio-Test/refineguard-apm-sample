# frozen_string_literal: true

module Refineguard
  module Ldap
    # The outcome of one credential bind. `simulated` is true whenever no real
    # directory was contacted, so the API and the UI can render SIMULATED
    Result = Struct.new(:authenticated, :mode, :simulated, :message, keyword_init: true)
  end
end
