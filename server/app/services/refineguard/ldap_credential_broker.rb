# frozen_string_literal: true

module Refineguard
  # Offline credential broker for the on-prem Active Directory / LDAP directory
  # The bind itself is delegated to a configurable adapter
  # {Refineguard::Ldap::SimulatedAdapter} — the air-gapped default: verifies
  # the local password store and reports SIMULATED (no directory contacted)
  # {Refineguard::Ldap::DirectoryAdapter} — a real LDAPv3 simple bind over TCP
  # Independently of the adapter, the broker refuses to dial any host that is not
  # on the local OT network, so a misconfiguration can never send refinery
  # credentials to the public internet
  class LdapCredentialBroker
    Result = Refineguard::Ldap::Result

    class << self
      # @return [Result]
      def authenticate(email:, password:, adapter: nil)
        return failure("Credentials are required") if email.blank? || password.blank?

        host = Refineguard::Ldap.configuration.host
        if host.present? && !local_ot_address?(host)
          return failure("Directory endpoint is not on the local OT network")
        end

        (adapter || effective_adapter).bind(email: email, password: password)
      end

      # Zero-outbound guarantee: this broker is the only credential path and it
      # is always pointed at the local OT directory.
      def outbound_network_allowed?
        false
      end

      def directory_configured?
        Refineguard::Ldap.configuration.host.present?
      end

      def offline?
        Refineguard::Ldap.configuration.offline?
      end

      # The directory endpoint in use (never rendered to the client).
      def endpoint
        host = Refineguard::Ldap.configuration.host
        return nil if host.blank?

        "#{host}:#{Refineguard::Ldap.configuration.port}"
      end

      # 'simulated' | 'directory' — whichever adapter is active
      def mode
        Refineguard::Ldap.mode_label
      end

      private

      def effective_adapter
        return Refineguard::Ldap::SimulatedAdapter.new if offline?

        Refineguard::Ldap::Adapter.for
      end

      def failure(message)
        Result.new(authenticated: false, mode: mode, simulated: Refineguard::Ldap.configuration.simulated?,
                   message: message)
      end

      # Only RFC1918 / loopback / .local hosts are considered on-premises.
      def local_ot_address?(host)
        return false if host.blank?
        return true if host.end_with?(".local", ".ot.local", ".internal")

        require "resolv"
        Resolv::IPv4::Regex.match?(host) && private_v4?(host)
      rescue LoadError, ArgumentError
        false
      end

      def private_v4?(host)
        parts = host.split(".").map(&:to_i)
        return false unless parts.length == 4 && parts.all? { |part| part.between?(0, 255) }

        parts[0] == 10 ||
          (parts[0] == 172 && parts[1].between?(16, 31)) ||
          (parts[0] == 192 && parts[1] == 168) ||
          parts[0] == 127
      end
    end
  end
end
