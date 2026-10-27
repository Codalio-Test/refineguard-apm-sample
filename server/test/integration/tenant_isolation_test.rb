# frozen_string_literal: true

require "test_helper"

# cross-tenant isolation.
#
# Rhino answers 404 (not 403) for an organization the caller is not a member of,
# and a member of two organizations never sees the other tenant's rows.
class TenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
  end

  test "a non-member gets 404 for the organization, not 403" do
    get "/api/demo-org/assets", headers: auth_headers(@outsider)
    assert_response :not_found
    assert_equal "Organization not found", JSON.parse(response.body)["message"]
  end

  test "a member of one organization cannot read the other tenant rows" do
    get "/api/runtime-other-org/assets", headers: auth_headers(@admin)
    assert_response :not_found
  end

  test "an unknown organization slug is a 404" do
    get "/api/no-such-org/assets", headers: auth_headers(@admin)
    assert_response :not_found
  end

  test "records created in one organization are invisible in the other" do
    assert_equal "X-900A", Asset.for_organization(@other_org).first.asset_tag

    get "/api/demo-org/assets", headers: auth_headers(@admin)
    tags = JSON.parse(response.body)["data"].map { |a| a["asset_tag"] }
    assert_not_includes tags, "X-900A"
  end

  test "a cross-organization foreign key is rejected, not silently accepted" do
    # The framework validates belongs_to FKs against the resolved organization.
    post "/api/demo-org/assets",
         params: { asset_tag: "Z-800Z", asset_name: "Cross tenant",
                   plant_unit_id: PlantUnit.create!(organization: @other_org, unit_code: "OTHER",
                                                    unit_name: "Other").id }.to_json,
         headers: json_headers(@admin)

    assert_not_equal 201, response.status
  end

  test "organization_id in the payload is stripped, never trusted" do
    post "/api/demo-org/assets",
         params: { asset_tag: "Z-801Z", asset_name: "Spoof attempt",
                   organization_id: @other_org.id }.to_json,
         headers: json_headers(@admin)
    assert_response :created
    assert_equal @demo_org.id, Asset.find_by(asset_tag: "Z-801Z").organization_id
  end

  test "changing organization_id through update is forbidden" do
    put "/api/demo-org/assets/P-204A",
        params: { organization_id: @other_org.id }.to_json, headers: json_headers(@admin)
    assert_response :forbidden
    assert_equal @demo_org.id, @asset.reload.organization_id
  end

  test "show by asset tag cannot reach another tenant record" do
    get "/api/demo-org/assets/X-900A", headers: auth_headers(@admin)
    assert_response :not_found
  end
end
