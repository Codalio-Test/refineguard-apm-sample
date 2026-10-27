# frozen_string_literal: true

module Refineguard
  module Ldap
    # The clearly-labelled stand-in used when no directory adapter is
    # configured. It verifies the local password store and reports SIMULATED
    # it performs NO directory bind, and says so in the result and the audit log
    class SimulatedAdapter < Adapter
      def name
        "simulated"
      end

      def simulated?
        true
      end

      def bind(email:, password:)
        user = User.find_by(email: email)
        return failure("Invalid credentials") if user.nil?
        return failure("Account locked after repeated failed attempts") if user.locked?
        return failure("Invalid credentials") unless user.authenticate(password)

        Result.new(
          authenticated: true,
          mode: "simulated",
          simulated: true,
          message: "SIMULATED: verified against the local credential store; no directory was contacted."
        )
      end

      private

      def failure(message)
        Result.new(authenticated: false, mode: "simulated", simulated: true, message: message)
      end
    end
  end
end
