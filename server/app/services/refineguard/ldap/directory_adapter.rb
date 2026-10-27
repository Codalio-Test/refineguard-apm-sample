# frozen_string_literal: true

module Refineguard
  module Ldap
    # The real client adapter: performs a genuine LDAP simple bind against the
    # configured on-prem directory (see {Refineguard::Ldap::Client})
    #
    # Transport safety: the bind is refused outright when the configured
    # transport is plaintext and plaintext has not been explicitly opted into, so
    # credentials are never put on the wire unencrypted by accident. The bind DN
    # is assembled from an RFC 4514-escaped email so a crafted address cannot
    # inject additional RDNs.
    class DirectoryAdapter < Adapter
      PLAINTEXT_REFUSAL =
        "Refusing a plaintext LDAP bind: configure REFINEGUARD_LDAP_TLS=start_tls (or 'ldaps'), " \
        "or set REFINEGUARD_LDAP_ALLOW_PLAINTEXT=1 to opt in deliberately."

      def name
        "directory"
      end

      def bind(email:, password:)
        host = Refineguard::Ldap.configuration.host
        return failure("Directory endpoint is not configured") if host.blank?
        return failure(PLAINTEXT_REFUSAL) if plaintext_refused?

        outcome = client(host).simple_bind(dn: bind_dn(email), password: password)
        return authenticated if outcome.success

        failure(outcome.message)
      rescue StandardError => e
        failure("Directory bind failed: #{e.message}")
      end

      private

      def plaintext_refused?
        Refineguard::Ldap.configuration.tls_mode == :none &&
          !Refineguard::Ldap.configuration.allow_plaintext_bind?
      end

      def client(host)
        Refineguard::Ldap::Client.new(
          host: host,
          port: Refineguard::Ldap.configuration.port,
          timeout: Refineguard::Ldap.configuration.timeout_s,
          tls: Refineguard::Ldap.configuration.tls_mode
        )
      end

      # Prefer the configured base DN; fall back to the escaped principal. The
      # email is escaped per RFC 4514 because it is interpolated into the DN.
      def bind_dn(email)
        base = Refineguard::Ldap.configuration.base_dn
        principal = Refineguard::Ldap::DistinguishedName.escape(email)
        return principal if base.blank?

        "cn=#{principal},#{base}"
      end

      def authenticated
        Result.new(authenticated: true, mode: "directory", simulated: false, message: "Authenticated")
      end

      def failure(message)
        Result.new(authenticated: false, mode: "directory", simulated: false, message: message)
      end
    end
  end
end
