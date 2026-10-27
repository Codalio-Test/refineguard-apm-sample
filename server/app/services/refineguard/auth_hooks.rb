# frozen_string_literal: true

module Refineguard
  # The air-gapped authentication lifecycle hooks.
  # Registered on the `:default` route group in config/initializers/rhino.rb
  # which is the legacy unprefixed `POST /api/auth/*` set. Everything here runs
  # offline: the credential broker only ever binds a local OT directory, the
  # second factor is verified with a local HMAC, and every outcome is appended to
  # the tamper-evident security trail.
  class AuthHooks < Rhino::AuthHooks
    def after_login(user, context = {})
      organization = context[:organization] || user.organizations.first
      request = context[:request]

      unless HardwareTokenVerifier.verify(user, presented_token(request))
        audit(request, organization, user, "AUTH_SECOND_FACTOR", severity: "warning",
                                                            result: "Denied",
                                                            details: { "reason" => "hardware token rejected" })
        raise Rhino::AuthRejected.new("Hardware token verification failed", status: 403)
      end

      user.register_successful_login!
      user.update_columns(token_last_used_at: Time.current) if user.class.column_names.include?("token_last_used_at")

      audit(request, organization, user, "AUTH_LOGIN", severity: "info", result: "Success",
                                                   details: { "mode" => Refineguard::Ldap.mode_label })
      nil
    end

    def after_logout(user, context = {})
      organization = context[:organization] || user&.organizations&.first
      audit(context[:request], organization, user, "AUTH_LOGOUT", severity: "info", result: "Success")
      nil
    end

    def after_register(user, context = {})
      organization = context[:organization] || user&.organizations&.first
      audit(context[:request], organization, user, "AUTH_REGISTER", severity: "warning",
                                                        result: "Success")
      nil
    end

    def after_password_recover(user, context = {})
      organization = context[:organization] || user&.organizations&.first
      audit(context[:request], organization, user, "AUTH_PASSWORD_RECOVER", severity: "warning",
                                                                    result: "Success")
      nil
    end

    def after_password_reset(user, context = {})
      organization = context[:organization] || user&.organizations&.first
      audit(context[:request], organization, user, "AUTH_PASSWORD_RESET", severity: "warning",
                                                                 result: "Success")
      nil
    end

    private

    # The badge reader supplies the code out-of-band.
    def presented_token(request)
      return nil unless request

      (request.headers["X-Hardware-Token"] || request.params[:hardware_token]).presence
    end

    def audit(request, organization, user, action_type, severity:, result:, details: nil)
      SecurityAuditWriter.call_with_request(
        request: request,
        organization: organization,
        user: user,
        action_type: action_type,
        severity: severity,
        result: result,
        entity_affected: user&.email,
        details: details
      )
    rescue StandardError
      # Auditing must never break the auth response path.
      nil
    end
  end
end
