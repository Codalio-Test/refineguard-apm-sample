# frozen_string_literal: true

require "test_helper"

# The air-gapped authentication lifecycle hooks and the offline credential broker.
class AuthHooksTest < ActiveSupport::TestCase
  ENV_KEYS = %w[REFINEGUARD_LDAP_ADAPTER REFINEGUARD_LDAP_HOST REFINEGUARD_LDAP_PORT
                REFINEGUARD_OFFLINE].freeze

  setup do
    @original_env = ENV_KEYS.index_with { |key| ENV[key] }
    @org = Organization.create!(name: "Hooks Org", slug: "hooks-org")
    @role = Role.create!(slug: "admin", name: "Admin")
    @user = User.new(email: "hooks@test.local", name: "Hooks", approved: true)
    @user.password = "password"
    @user.api_token = SecureRandom.hex(32)
    @user.save!
    UserRole.create!(user: @user, organization: @org, role: @role)
  end

  def teardown
    @original_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    super
  end

  def set_env(values)
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  # A minimal stand-in for the ActionDispatch::Request the hooks read metadata from.
  def request_with_token(code)
    Struct.new(:headers, :params, :remote_ip, :user_agent).new(
      { "X-Hardware-Token" => code }, {}, "127.0.0.1", "refineguard-test"
    )
  end

  # ---- lifecycle hooks -----------------------------------------------------

  test "a login without a provisioned token succeeds, audits and stamps the clock" do
    assert_nil Refineguard::AuthHooks.new.after_login(@user, organization: @org)
    assert SecurityAuditEvent.where(organization: @org, action_type: "AUTH_LOGIN").exists?
    assert_not_nil @user.reload.token_last_used_at
  end

  test "a rejected hardware token denies the login and audits the denial" do
    @user.update!(hardware_token_secret: "SHARED-SEED")
    hooks = Refineguard::AuthHooks.new

    assert_raises(Rhino::AuthRejected) do
      hooks.after_login(@user, organization: @org, request: request_with_token("000000"))
    end
    assert SecurityAuditEvent.where(organization: @org,
                                    action_type: "AUTH_SECOND_FACTOR").exists?
  end

  test "the current hardware token is accepted" do
    @user.update!(hardware_token_secret: "SHARED-SEED")
    code = Refineguard::HardwareTokenVerifier.code_for(@user)

    assert_nil Refineguard::AuthHooks.new.after_login(
      @user, organization: @org, request: request_with_token(code)
    )
    assert SecurityAuditEvent.where(organization: @org, action_type: "AUTH_LOGIN").exists?
  end

  test "logout, register and the two password hooks all append to the trail" do
    hooks = Refineguard::AuthHooks.new
    hooks.after_logout(@user, organization: @org)
    hooks.after_register(@user, organization: @org)
    hooks.after_password_recover(@user, organization: @org)
    hooks.after_password_reset(@user, organization: @org)

    %w[AUTH_LOGOUT AUTH_REGISTER AUTH_PASSWORD_RECOVER AUTH_PASSWORD_RESET].each do |type|
      assert SecurityAuditEvent.where(organization: @org, action_type: type).exists?, "missing #{type}"
    end
  end

  test "the hooks fall back to the user's first organization and tolerate no user" do
    hooks = Refineguard::AuthHooks.new
    assert_nil hooks.after_logout(@user, {})
    assert_nil hooks.after_logout(nil, {})
    assert_nil hooks.after_register(nil, {})
    assert_nil hooks.after_password_recover(nil, {})
    assert_nil hooks.after_password_reset(nil, {})
  end

  # ---- hardware token verifier --------------------------------------------

  test "the hardware token is only required for a provisioned identity" do
    assert_not Refineguard::HardwareTokenVerifier.required_for?(@user)
    assert_not Refineguard::HardwareTokenVerifier.required_for?(nil)
    assert Refineguard::HardwareTokenVerifier.verify(@user, nil)

    @user.update!(hardware_token_secret: "SHARED-SEED")
    assert Refineguard::HardwareTokenVerifier.required_for?(@user)
    assert_not Refineguard::HardwareTokenVerifier.verify(@user, nil)
    assert_not Refineguard::HardwareTokenVerifier.verify(@user, "12345")
    assert_not Refineguard::HardwareTokenVerifier.verify(@user, "abcdef")
    assert Refineguard::HardwareTokenVerifier.verify(
      @user, Refineguard::HardwareTokenVerifier.code_for(@user)
    )
    # One window of drift either way is accepted.
    assert Refineguard::HardwareTokenVerifier.verify(
      @user, Refineguard::HardwareTokenVerifier.code_for(@user, 30.seconds.from_now)
    )
    assert_not Refineguard::HardwareTokenVerifier.secure_compare("1", "12")
  end

  # ---- credential broker ---------------------------------------------------

  test "blank credentials are refused before any directory is considered" do
    assert_match(/Credentials are required/,
                 Refineguard::LdapCredentialBroker.authenticate(email: "", password: "").message)
  end

  test "a directory outside the local OT network is never dialled" do
    set_env("REFINEGUARD_LDAP_HOST" => "ldap.corp.example.com")
    result = Refineguard::LdapCredentialBroker.authenticate(email: "a@b.local", password: "x")

    assert_not result.authenticated
    assert_match(/not on the local OT network/, result.message)
    assert_not Refineguard::LdapCredentialBroker.outbound_network_allowed?
  end

  test "the simulated adapter verifies the local store and reports SIMULATED" do
    set_env("REFINEGUARD_LDAP_HOST" => nil)
    wrong = Refineguard::LdapCredentialBroker.authenticate(email: @user.email, password: "nope")
    assert_not wrong.authenticated
    assert_match(/Invalid credentials/, wrong.message)

    missing = Refineguard::LdapCredentialBroker.authenticate(email: "ghost@test.local",
                                                              password: "password")
    assert_not missing.authenticated

    right = Refineguard::LdapCredentialBroker.authenticate(email: @user.email, password: "password")
    assert right.authenticated
    assert right.simulated
    assert_match(/SIMULATED/, right.message)

    @user.update!(locked_at: Time.current)
    locked = Refineguard::LdapCredentialBroker.authenticate(email: @user.email, password: "password")
    assert_not locked.authenticated
    assert_match(/locked/, locked.message)
  end

  test "the broker reports its configuration and mode" do
    set_env("REFINEGUARD_LDAP_HOST" => "127.0.0.1", "REFINEGUARD_LDAP_PORT" => "389")
    assert Refineguard::LdapCredentialBroker.directory_configured?
    assert_equal "127.0.0.1:389", Refineguard::LdapCredentialBroker.endpoint
    assert_equal "simulated", Refineguard::LdapCredentialBroker.mode
    assert_not Refineguard::LdapCredentialBroker.offline?

    set_env("REFINEGUARD_OFFLINE" => "1")
    assert Refineguard::LdapCredentialBroker.offline?

    set_env("REFINEGUARD_LDAP_HOST" => nil, "REFINEGUARD_OFFLINE" => nil)
    assert_nil Refineguard::LdapCredentialBroker.endpoint
    assert_not Refineguard::LdapCredentialBroker.directory_configured?
  end

  test "an explicit adapter is used when one is injected" do
    adapter = Refineguard::Ldap::SimulatedAdapter.new
    result = Refineguard::LdapCredentialBroker.authenticate(email: @user.email, password: "password",
                                                            adapter: adapter)
    assert result.authenticated
  end
end
