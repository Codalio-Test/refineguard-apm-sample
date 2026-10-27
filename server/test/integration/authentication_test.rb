# frozen_string_literal: true

require "test_helper"

#
# the air-gapped authentication contract.
class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
  end

  # local directory credentials authenticate and return a bearer token.
  test "seeded identities log in and receive their organization slug" do
    {
      "administrator@example.com" => "demo-org",
      "viewer@example.com" => "demo-org",
      "outsider@example.com" => "runtime-other-org"
    }.each do |email, slug|
      post "/api/auth/login",
           params: { email: email, password: "password" }.to_json,
           headers: { "Content-Type" => "application/json" }

      assert_response :ok, "#{email} should authenticate"
      body = JSON.parse(response.body)
      assert body["token"].present?
      assert_equal slug, body["organization_slug"]
    end
  end

  test "invalid credentials return 401 and do not leak whether the account exists" do
    post "/api/auth/login",
         params: { email: "administrator@example.com", password: "nope" }.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized

    post "/api/auth/login",
         params: { email: "ghost@example.com", password: "nope" }.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
    assert_equal JSON.parse(response.body)["message"], "Invalid credentials"
  end

  # 5 consecutive failures lock the account.
  test "five consecutive failures lock the account" do
    5.times do
      post "/api/auth/login",
           params: { email: "viewer@example.com", password: "wrong" }.to_json,
           headers: { "Content-Type" => "application/json" }
      assert_response :unauthorized
    end

    viewer = User.find_by!(email: "viewer@example.com")
    assert viewer.locked?
    assert_operator viewer.failed_login_attempts, :>=, User::LOCKOUT_THRESHOLD

    post "/api/auth/login",
         params: { email: "viewer@example.com", password: "password" }.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :forbidden
  end

  # the hardware token is required once an identity has one.
  test "a provisioned hardware token is required and verified server-side" do
    engineer = User.find_by!(email: "reliability_engineer@example.com")
    engineer.update!(hardware_token_secret: "SHARED-SECRET")

    post "/api/auth/login",
         params: { email: engineer.email, password: "password" }.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :forbidden

    code = Refineguard::HardwareTokenVerifier.code_for(engineer.reload)
    post "/api/auth/login",
         params: { email: engineer.email, password: "password" }.to_json,
         headers: { "Content-Type" => "application/json", "X-Hardware-Token" => code }
    assert_response :ok
  end

  test "the credential broker never dials outside the local OT network" do
    # zero outbound network requests.
    assert_not Refineguard::LdapCredentialBroker.outbound_network_allowed?

    original = ENV["REFINEGUARD_LDAP_HOST"]
    ENV["REFINEGUARD_LDAP_HOST"] = "ldap.corp.example.com"
    result = Refineguard::LdapCredentialBroker.authenticate(
      email: "administrator@example.com", password: "password"
    )
    assert_not result.authenticated
    assert_match(/local OT network/, result.message)
  ensure
    ENV["REFINEGUARD_LDAP_HOST"] = original
  end

  # a token idle beyond 30 minutes is revoked with 401.
  test "a token idle for more than 30 minutes is rejected with 401" do
    admin = User.find_by!(email: "administrator@example.com")
    admin.update_columns(token_last_used_at: 31.minutes.ago)
    token = admin.reload.api_token

    get "/api/demo-org/assets", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
    assert_not_equal token, admin.reload.api_token
    # The engine's own controllers keep their existing `{ message: ... }` body;
    # only the custom endpoints adopt the shared `{ errors: [...] }` envelope.
    assert_equal "Session expired after 30 minutes of inactivity.",
                 JSON.parse(response.body)["message"]
  end

  # protected routes answer 401 without a token.
  test "protected routes require a bearer token" do
    %w[assets asset_components prescriptive_advisories diagnostic_incidents].each do |slug|
      get "/api/demo-org/#{slug}"
      assert_response :unauthorized, "#{slug} must require authentication"
    end

    get "/api/demo-org/dashboard/fleet_overview"
    assert_response :unauthorized
  end

  test "logout revokes the token" do
    admin = User.find_by!(email: "administrator@example.com")
    token = admin.reload.api_token

    post "/api/auth/logout", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :ok

    get "/api/demo-org/assets", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end
end
