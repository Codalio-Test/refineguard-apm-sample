# frozen_string_literal: true

require "test_helper"

# the runtime seed contract.
#
# roles, one membership per role (so `useRoles` is never empty), and
#           OrgRolePermission rows matching the blueprint action matrix
# the PRD `sample_data` rows AND the prototype-narrative rows, with the
#           health/severity every locked fixture key resolves against
#
# The seed is loaded inside each test (the suite is transactional, so each example
# starts from an empty database) and rolled back afterwards.
class SeedsContractTest < ActionDispatch::IntegrationTest
  def run_seed
    silence_warnings { capture_io { load Rails.root.join("db/seeds.rb") } }
  end

  # the permission chain the SPA and every policy depends on.
  test "the seed creates the blueprint roles, a membership per role and the permission matrix" do
    run_seed

    expected_roles = %w[admin reliability_engineer machinery_specialist maintenance_planner
                        operations_superintendent]
    assert_equal expected_roles.sort, Role.where(slug: expected_roles).pluck(:slug).sort

    # `useRoles()` reads the current user's roles in the current org; with no
    # UsersRole row for a role that hook resolves to an empty list and every
    # role-gated control disappears. One identity per role fixes that.
    demo_org = Organization.find_by!(slug: "demo-org")
    expected_roles.each do |slug|
      role = Role.find_by!(slug: slug)
      assert UserRole.joins(:user).where(organization: demo_org, role: role).exists?,
             "no identity holds #{slug} in demo-org — useRoles() would be empty for that persona"
    end

    # The engine treats the literal `admin` slug as privileged.
    assert Role.exists?(slug: "admin")

    # The permission rows must match the blueprint's action matrix, not be
    # default-deny. `assets` carries the host-runtime contract, so it is the
    # sharpest probe: admin full CRUD, reliability_engineer read-only.
    admin_permissions = OrgRolePermission.find_by!(organization: demo_org,
                                                   role: Role.find_by!(slug: "admin")).permissions
    %w[assets.index assets.show assets.store assets.update assets.destroy
       assets.trashed assets.restore assets.forceDelete].each do |permission|
      assert_includes admin_permissions, permission
    end

    engineer_permissions = OrgRolePermission.find_by!(
      organization: demo_org, role: Role.find_by!(slug: "reliability_engineer")
    ).permissions
    assert_includes engineer_permissions, "assets.index"
    assert_not_includes engineer_permissions, "assets.store"
  end

  # the demo data both the PRD and the locked prototype fixtures need.
  test "the seed loads the PRD sample_data and the prototype-narrative assets" do
    run_seed

    demo_org = Organization.find_by!(slug: "demo-org")
    tags = Asset.where(organization: demo_org).pluck(:asset_tag)

    # PRD `sample_data` assets, verbatim.
    %w[P-101A K-301 P-402 KT-201].each do |tag|
      assert_includes tags, tag, "#{tag} from the PRD sample_data is missing"
    end

    # Prototype-narrative hero rows: every locked fixture key must resolve.
    %w[P-204A C-101B P-108C].each do |tag|
      assert_includes tags, tag, "#{tag} from the prototype narrative is missing"
    end

    # The hero asset carries the health / RUL the locked deep link renders, and its
    # severity maps onto the badge vocabulary.
    hero = Asset.find_by!(organization: demo_org, asset_tag: "P-204A")
    assert_equal "Trip", hero.health_state
    assert_equal 28.0, hero.health_index
    assert_equal "critical", hero.severity
    assert_equal 8.5, hero.estimated_rul_days
    assert_not_nil hero.plant_unit

    # The four operating units the unit filter / risk matrix key on.
    assert_equal %w[ALKY-4 CDU-1 FCC-2 HCU-3],
                 PlantUnit.where(organization: demo_org).pluck(:unit_code).sort

    # The air-gap badges read real connectors.
    assert HistorianConnector.where(organization: demo_org, status: "Connected").exists?

    # Every tag-keyed deep link resolves because the route key is the tag.
    assert_equal "asset_tag", Asset.rhino_resolved_route_key

    # The tag-keyed route itself works against seeded data.
    get "/api/demo-org/assets/P-204A", headers: auth_headers(User.find_by!(email: "administrator@example.com"))
    assert_response :ok
    assert_equal "P-204A", JSON.parse(response.body)["id"]
  end
end
