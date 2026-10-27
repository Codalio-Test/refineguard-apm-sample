# frozen_string_literal: true

module Refineguard
  module Ldap
    # Reads the on-prem directory configuration from the environment
    # REFINEGUARD_LDAP_ADAPTER 'simulated' (default) | 'directory'
    # REFINEGUARD_LDAP_HOST the local OT directory host (blank = local only)
    # REFINEGUARD_LDAP_PORT default 389
    # REFINEGUARD_LDAP_BASE_DN e.g. DC=brr-ot,DC=local
    # REFINEGUARD_LDAP_TIMEOUT_MS real bind timeout (default 3000)
    # REFINEGUARD_LDAP_TLS 'start_tls' (default) | 'ldaps' | 'none'
    # REFINEGUARD_LDAP_ALLOW_PLAINTEXT "1" permits a plaintext bind (TLS 'none')
    # REFINEGUARD_OFFLINE "1" forces the simulated adapter
    class Configuration
      SIMULATED = "simulated"
      DIRECTORY = "directory"

      START_TLS = "start_tls"
      LDAPS = "ldaps"
      PLAINTEXT = "none"

      # Wire name => Ruby transport symbol. An unknown value falls back to the
      # secure default rather than silently downgrading the transport.
      TLS_MODE_NAMES = {
        START_TLS => :start_tls,
        LDAPS => :ldaps,
        PLAINTEXT => :none
      }.freeze

      def adapter_name
        (ENV["REFINEGUARD_LDAP_ADAPTER"].presence || SIMULATED).downcase
      end

      def simulated?
        offline? || adapter_name != DIRECTORY
      end

      def host
        ENV["REFINEGUARD_LDAP_HOST"].presence
      end

      def port
        Integer(ENV.fetch("REFINEGUARD_LDAP_PORT", "389"))
      rescue ArgumentError, TypeError
        389
      end

      def base_dn
        ENV["REFINEGUARD_LDAP_BASE_DN"].presence
      end

      def offline?
        ENV["REFINEGUARD_OFFLINE"].to_s == "1"
      end

      def timeout_s
        Integer(ENV.fetch("REFINEGUARD_LDAP_TIMEOUT_MS", "3000")) / 1000.0
      rescue ArgumentError, TypeError
        3.0
      end

      # The transport the real client uses: :start_tls (default), :ldaps, or :none.
      def tls_mode
        TLS_MODE_NAMES.fetch(tls_mode_name, :start_tls)
      end

      def tls_mode_name
        (ENV["REFINEGUARD_LDAP_TLS"].presence || START_TLS).downcase
      end

      # A plaintext bind must be opted into explicitly; it is never the default.
      def allow_plaintext_bind?
        ENV["REFINEGUARD_LDAP_ALLOW_PLAINTEXT"].to_s == "1"
      end

      # Optional PEM bundle for a private OT certificate authority.
      def ca_file
        ENV["REFINEGUARD_LDAP_CA_FILE"].presence
      end
    end
  end
end
