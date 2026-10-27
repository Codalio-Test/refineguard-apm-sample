# frozen_string_literal: true

module Refineguard
  # 5-attempt account lockout around the built-in login endpoint.
  #
  # Prepended onto Rhino::AuthController so `super` still performs the real
  # password check (and therefore still issues the bearer token). This wrapper
  # adds the offline credential-broker bind, counts consecutive failures and
  # locks the identity, and appends every outcome to the security trail.
  module AuthControllerExtensions
    LOCKOUT_MESSAGE = "Account locked after 5 consecutive failed attempts. " \
                      "Contact the OT system administrator."

    def login
      email = params[:email].to_s.strip
      user = User.find_by(email: email)
      organization = user&.organizations&.first
      request = self.request

      if user&.locked?
        Refineguard::SecurityAuditWriter.call_with_request(
          request: request, organization: organization, user: user,
          action_type: "AUTH_LOGIN", severity: "critical", result: "Denied",
          entity_affected: email, details: { "reason" => "account locked" }
        )
        return render json: { message: LOCKOUT_MESSAGE }, status: :forbidden
      end

      broker = Refineguard::LdapCredentialBroker.authenticate(email: email, password: params[:password].to_s)

      unless broker.authenticated
        register_failure(user, organization, request, email, broker.message)
        return render json: { message: broker.message }, status: :unauthorized
      end

      super

      # `super` renders; inspect what it produced to decide the counter action.
      if response.status == 200
        user&.update_columns(failed_login_attempts: 0) if user
      elsif response.status == 401 && user
        register_failure(user, organization, request, email, "Invalid credentials")
      end
    end

    private

    def register_failure(user, organization, request, email, reason)
      return if user.nil?

      user.register_failed_login! if user.respond_to?(:register_failed_login!)

      Refineguard::SecurityAuditWriter.call_with_request(
        request: request, organization: organization, user: user,
        action_type: "AUTH_FAILURE", severity: "warning", result: "Failure",
        entity_affected: email,
        details: {
          "reason" => reason,
          "failed_login_attempts" => user.failed_login_attempts,
          "locked" => user.locked?
        }
      )
    rescue StandardError
      nil
    end
  end
end
