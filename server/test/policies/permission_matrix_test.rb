# frozen_string_literal: true

require "test_helper"

#
# the blueprint permission matrix,
# asserted action by action (every "Only <roles> can access <route>" criterion).
#
# The matrix is read from `.rhino/blueprints/*.yaml`, so the test fails if a
# blueprint's `permissions:` block and the seeded permission chain ever drift
# apart (the classic default-deny bug).
class PermissionMatrixTest < ActionDispatch::IntegrationTest
  # Mutation coverage: the permission decisions of every feature policy are
  # asserted action by action here, so a wrong gate or attribute surface is killed.
  cover "AssetPolicy"
  cover "PrescriptiveAdvisoryPolicy"
  cover "DiagnosticIncidentPolicy"
  cover "CmmsWorkOrderPolicy"
  cover "HistorianConnectorPolicy"
  cover "SecurityAuditEventPolicy"

  setup do
    setup_runtime
    @actors = {
      "admin" => @admin,
      "reliability_engineer" => @engineer,
      "machinery_specialist" => @specialist,
      "maintenance_planner" => @planner,
      "operations_superintendent" => @superintendent
    }
  end

  test "every blueprint role/action grants exactly what the policy decides" do
    matrix = RefineguardTestData.blueprint_permissions

    RefineguardTestData.model_slugs.each do |slug|
      model = Rhino.config.resolve_model(slug)
      policy_class = "#{model.name}Policy".safe_constantize || Rhino::ResourcePolicy

      RefineguardTestData::ROLES.each do |role_slug|
        actions = (matrix[role_slug] || {})[slug] || []
        user = @actors[role_slug]

        RequestStore.store[:rhino_organization] = @demo_org
        RequestStore.store[:rhino_current_user] = user

        {
          index?: "index", show?: "show", create?: "store",
          update?: "update", destroy?: "destroy", view_trashed?: "trashed",
          restore?: "restore", force_delete?: "forceDelete"
        }.each do |method, action|
          policy = policy_class.new(user, model.new)
          expected = actions.include?(action)
          assert_equal expected, policy.public_send(method),
                       "#{role_slug} #{slug}.#{action} (#{method}) should be #{expected}"
        end
      end
    end
  end

  test "a user with no membership in the organization is default-deny" do
    # no UserRole row in demo-org => every action denied.
    outsider_in_demo = User.find_by!(email: "outsider@example.com")
    RequestStore.store[:rhino_organization] = @demo_org

    %w[assets.index assets.show assets.store].each do |permission|
      assert_not outsider_in_demo.has_permission?(permission, @demo_org)
    end
  end

  test "deny always wins over a granted role action" do
    # The layered resolution contract: (role ∪ granted) − denied.
    role = @roles["machinery_specialist"]
    record = UserRole.find_by!(user: @specialist, organization: @demo_org, role: role)
    record.update!(denied_permissions: [ "assets.store" ])

    assert_not @specialist.reload.has_permission?("assets.store", @demo_org)
    assert @specialist.has_permission?("assets.index", @demo_org)
  end

  # The audit trail is append-only: its blueprint grants no create/update action
  # and no writable fields, and the policy must match that exactly — not hand out
  # `["*"]` while the blueprint grants nothing.
  test "the audit trail grants no writable fields, matching its blueprint" do
    RequestStore.store[:rhino_organization] = @demo_org
    RequestStore.store[:rhino_current_user] = @admin
    policy = SecurityAuditEventPolicy.new(@admin, SecurityAuditEvent.new)

    assert_equal [], policy.permitted_attributes_for_create(@admin)
    assert_equal [], policy.permitted_attributes_for_update(@admin)
    assert_not policy.create?
    assert_not policy.update?
    assert policy.index?
    assert policy.show?
  end
end
