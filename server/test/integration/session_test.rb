# frozen_string_literal: true

require "test_helper"

# the flat-route SPA resolves the signed-in identity (and the
# role that decides its landing route) from `GET /api/:organization/me`.
#
# The engine's login response carries only `{ token, organization_slug }`, so
# without this endpoint the browser resolves `roles: []` for everybody — the
# sidebar then hides every role-gated item and every role-gated route bounces.
#
# The endpoint is deliberately tenant-scoped: a user with no membership in the
# requested organization gets the information-hiding 404, and the role slugs are
# read for the requested organization only, never across tenants.
class SessionTest < ActionDispatch::IntegrationTest
  test "returns the administrator identity and role for the requested organization" do
    setup_runtime

    get "/api/#{@demo_org.slug}/me", headers: auth_headers(@admin)

    assert_response :ok
    body = json_body
    assert_equal "administrator@example.com", body.dig("user", "email")
    assert_equal [ "admin" ], body.dig("user", "role_slugs")
    assert_equal @demo_org.slug, body.dig("organization", "slug")
    assert_equal @demo_org.name, body.dig("organization", "name")
  end

  test "returns the operations superintendent role so that persona lands on its unit risk matrix" do
    setup_runtime

    get "/api/#{@demo_org.slug}/me", headers: auth_headers(@superintendent)

    assert_response :ok
    assert_equal [ "operations_superintendent" ], json_body.dig("user", "role_slugs")
  end

  test "reads the role slugs for the requested organization, not across tenants" do
    setup_runtime
    # Same human, two memberships: admin in demo-org, reliability_engineer elsewhere.
    member = create_user("dual-role@example.com", @roles["admin"], @demo_org)
    UserRole.create!(user: member, organization: @other_org, role: @roles["reliability_engineer"])

    get "/api/#{@demo_org.slug}/me", headers: auth_headers(member)
    assert_response :ok
    assert_equal [ "admin" ], json_body.dig("user", "role_slugs")

    get "/api/#{@other_org.slug}/me", headers: auth_headers(member)
    assert_response :ok
    assert_equal [ "reliability_engineer" ], json_body.dig("user", "role_slugs")
  end

  test "answers 401 without a bearer token" do
    setup_runtime

    get "/api/#{@demo_org.slug}/me"

    assert_response :unauthorized
  end

  test "hides an organization the caller is not a member of" do
    setup_runtime

    get "/api/#{@demo_org.slug}/me", headers: auth_headers(@outsider)

    assert_response :not_found
  end

  test "hides an unknown organization" do
    setup_runtime

    get "/api/no-such-org/me", headers: auth_headers(@admin)

    assert_response :not_found
  end

  test "never serializes the bearer token" do
    setup_runtime

    get "/api/#{@demo_org.slug}/me", headers: auth_headers(@admin)

    assert_response :ok
    refute_includes response.body, @admin.reload.api_token
  end
end
