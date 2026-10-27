# frozen_string_literal: true

require "test_helper"

# LDAP directory transport safety.
#
# The real adapter must not put a credential on the wire unencrypted unless that
# is explicitly opted into, and the bind DN must be assembled from an
# RFC 4514-escaped principal so a crafted email cannot inject extra RDNs.
class LdapDirectoryAdapterTest < ActiveSupport::TestCase
  ENV_KEYS = %w[REFINEGUARD_LDAP_ADAPTER REFINEGUARD_LDAP_HOST REFINEGUARD_LDAP_PORT
                REFINEGUARD_LDAP_BASE_DN REFINEGUARD_LDAP_TLS
                REFINEGUARD_LDAP_ALLOW_PLAINTEXT REFINEGUARD_OFFLINE].freeze

  setup { @original_env = ENV_KEYS.index_with { |key| ENV[key] } }
  teardown { @original_env.each { |key, value| ENV[key] = value } }

  def set_env(values)
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  # ---- RFC 4514 escaping --------------------------------------------------

  test "escape leaves an ordinary address untouched" do
    assert_equal "operator.name@brr-ot.local",
                 Refineguard::Ldap::DistinguishedName.escape("operator.name@brr-ot.local")
  end

  test "escape neutralises every RFC 4514 special character" do
    assert_equal 'smith\, john@x', Refineguard::Ldap::DistinguishedName.escape("smith, john@x")
    assert_equal 'a\+b@x', Refineguard::Ldap::DistinguishedName.escape("a+b@x")
    assert_equal '\#hash@x', Refineguard::Ldap::DistinguishedName.escape("#hash@x")
    assert_equal 'x\;y@x', Refineguard::Ldap::DistinguishedName.escape("x;y@x")
    assert_equal 'a\<b\>c@x', Refineguard::Ldap::DistinguishedName.escape("a<b>c@x")
    assert_equal 'a\=b@x', Refineguard::Ldap::DistinguishedName.escape("a=b@x")
    assert_equal 'q\"q@x', Refineguard::Ldap::DistinguishedName.escape('q"q@x')
  end

  test "escape handles leading/trailing space, backslash and NUL" do
    assert_equal '\ leading@x', Refineguard::Ldap::DistinguishedName.escape(" leading@x")
    assert_equal 'trailing\ ', Refineguard::Ldap::DistinguishedName.escape("trailing ")
    assert_equal 'back\\\\slash@x', Refineguard::Ldap::DistinguishedName.escape("back\\slash@x")
    assert_equal 'a\\00b', Refineguard::Ldap::DistinguishedName.escape("a\0b")
    assert_equal "", Refineguard::Ldap::DistinguishedName.escape("")
  end

  # ---- transport safety ---------------------------------------------------

  test "a plaintext bind is refused when TLS is not configured" do
    set_env("REFINEGUARD_LDAP_HOST" => "127.0.0.1", "REFINEGUARD_LDAP_TLS" => "none",
            "REFINEGUARD_LDAP_ALLOW_PLAINTEXT" => nil)

    result = Refineguard::Ldap::DirectoryAdapter.new.bind(email: "a@b.local", password: "x")

    assert_not result.authenticated
    assert_match(/Refusing a plaintext LDAP bind/, result.message)
  end

  test "an unset transport defaults to StartTLS rather than plaintext" do
    set_env("REFINEGUARD_LDAP_TLS" => nil)
    assert_equal :start_tls, Refineguard::Ldap.configuration.tls_mode
    assert_equal false, Refineguard::Ldap.configuration.allow_plaintext_bind?
  end

  test "the configured TLS mode is the transport the client is built with" do
    set_env("REFINEGUARD_LDAP_TLS" => "ldaps")
    assert_equal :ldaps, directory_client_tls

    set_env("REFINEGUARD_LDAP_TLS" => "start_tls")
    assert_equal :start_tls, directory_client_tls

    set_env("REFINEGUARD_LDAP_TLS" => "none")
    assert_equal :none, directory_client_tls
  end

  test "the bind DN escapes the principal before the configured base" do
    set_env("REFINEGUARD_LDAP_BASE_DN" => "DC=brr-ot,DC=local")
    assert_equal "cn=smith\\, john@x,DC=brr-ot,DC=local", directory_bind_dn("smith, john@x")

    set_env("REFINEGUARD_LDAP_BASE_DN" => nil)
    assert_equal "a\\+b@x", directory_bind_dn("a+b@x")
  end

  private

  # Reach the adapter's private seams directly — this asserts the wiring without
  # opening a socket.
  def directory_client_tls
    Refineguard::Ldap::DirectoryAdapter.new.send(:client, "127.0.0.1").tls
  end

  def directory_bind_dn(email)
    Refineguard::Ldap::DirectoryAdapter.new.send(:bind_dn, email)
  end
end
