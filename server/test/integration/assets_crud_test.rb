# frozen_string_literal: true

require "test_helper"

# The host runtime contract for the contract-carrying resource: `assets`.
#
#   * admin            -> full CRUD (201 / 200 / 204)
#   * reliability_engineer -> read-only (403 on every write)
#   * empty payload    -> 422 with per-field errors
class AssetsCrudTest < ActionDispatch::IntegrationTest
  setup do
    setup_runtime
  end

  test "admin can create, read, update, soft-delete, restore and force-delete" do
    post "/api/demo-org/assets",
         params: { asset_tag: "Z-900Z", asset_name: "Probe pump",
                   equipment_class: "Centrifugal Pump" }.to_json,
         headers: json_headers(@admin)
    assert_response :created
    created = JSON.parse(response.body)
    assert_equal "Z-900Z", created["id"]
    assert_equal "Z-900Z", created["asset_tag"]

    get "/api/demo-org/assets/Z-900Z", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal "Probe pump", JSON.parse(response.body)["asset_name"]

    put "/api/demo-org/assets/Z-900Z",
        params: { operating_status: "Standby" }.to_json, headers: json_headers(@admin)
    assert_response :ok
    assert_equal "Standby", JSON.parse(response.body)["operating_status"]

    delete "/api/demo-org/assets/Z-900Z", headers: auth_headers(@admin)
    assert_response :no_content

    get "/api/demo-org/assets/trashed", headers: auth_headers(@admin)
    assert_response :ok
    assert_includes JSON.parse(response.body)["data"].map { |a| a["asset_tag"] }, "Z-900Z"

    post "/api/demo-org/assets/Z-900Z/restore", headers: auth_headers(@admin)
    assert_response :ok

    get "/api/demo-org/assets/Z-900Z", headers: auth_headers(@admin)
    assert_response :ok
  end

  test "force-delete permanently removes an already discarded record" do
    # The engine only reaches discarded records from the force-delete route, so
    # the sequence is soft-delete first, then purge.
    post "/api/demo-org/assets",
         params: { asset_tag: "Z-905Z", asset_name: "Purge probe" }.to_json,
         headers: json_headers(@admin)
    assert_response :created

    delete "/api/demo-org/assets/Z-905Z", headers: auth_headers(@admin)
    assert_response :no_content

    delete "/api/demo-org/assets/Z-905Z/force-delete", headers: auth_headers(@admin)
    assert_response :no_content
    assert_nil Asset.with_discarded.find_by(asset_tag: "Z-905Z")
  end

  test "an empty payload is rejected with 422 and per-field errors" do
    post "/api/demo-org/assets", params: {}.to_json, headers: json_headers(@admin)
    assert_response :unprocessable_entity

    errors = JSON.parse(response.body)["errors"]
    assert errors.key?("asset_tag")
    assert errors.key?("asset_name")
  end

  test "a duplicate asset_tag is rejected with 422" do
    post "/api/demo-org/assets",
         params: { asset_tag: "P-204A", asset_name: "Duplicate" }.to_json,
         headers: json_headers(@admin)
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].key?("asset_tag")
  end

  test "read-only roles cannot create, update or delete" do
    # reliability_engineer has index/show only.
    post "/api/demo-org/assets",
         params: { asset_tag: "Z-901Z", asset_name: "Nope" }.to_json,
         headers: json_headers(@engineer)
    assert_response :forbidden

    put "/api/demo-org/assets/P-204A",
        params: { operating_status: "Standby" }.to_json, headers: json_headers(@engineer)
    assert_response :forbidden

    delete "/api/demo-org/assets/P-204A", headers: auth_headers(@engineer)
    assert_response :forbidden
  end

  test "machinery_specialist may create but only with its permitted field set" do
    # the specialist's create_fields are an explicit whitelist.
    post "/api/demo-org/assets",
         params: { asset_tag: "Z-902Z", asset_name: "Specialist pump",
                   equipment_class: "Centrifugal Pump" }.to_json,
         headers: json_headers(@specialist)
    assert_response :created

    post "/api/demo-org/assets",
         params: { asset_tag: "Z-903Z", asset_name: "With health",
                   health_index: 50.0 }.to_json,
         headers: json_headers(@specialist)
    assert_response :forbidden
    assert_match(/health_index/, JSON.parse(response.body)["message"])
  end

  test "index rows carry the prototype contract keys" do
    get "/api/demo-org/assets", headers: auth_headers(@admin)
    assert_response :ok

    row = JSON.parse(response.body)["data"].find { |a| a["asset_tag"] == "P-204A" }
    assert_not_nil row
    assert_equal "P-204A", row["id"]
    assert_equal "CDU-1", row["unit"]
    assert_equal 28.0, row["health"]
    assert_equal "critical", row["severity"]
    assert_equal "8.42", row["rms"]
  end

  test "a held-back field is absent for the role the policy hides it from" do
    # operations_superintendent hides manufacturer/bearing models.
    get "/api/demo-org/assets", headers: auth_headers(@superintendent)
    assert_response :ok
    row = JSON.parse(response.body)["data"].first
    assert_not row.key?("manufacturer")
    assert_not row.key?("bearing_nde_model")

    get "/api/demo-org/assets", headers: auth_headers(@admin)
    row = JSON.parse(response.body)["data"].first
    assert row.key?("manufacturer")
  end

  test "asset_tag is a whitelisted filter for the tag-keyed deep links" do
    # useAssetByTag resolves tag -> record with this filter.
    get "/api/demo-org/assets?filter[asset_tag]=P-204A", headers: auth_headers(@admin)
    assert_response :ok
    rows = JSON.parse(response.body)["data"]
    assert_equal 1, rows.length
    assert_equal "P-204A", rows.first["asset_tag"]
  end

  test "attributes are paginated with the X-* headers the client parses" do
    get "/api/demo-org/assets?per_page=1", headers: auth_headers(@admin)
    assert_response :ok
    assert response.headers["X-Total"].present?
    assert_equal "1", response.headers["X-Per-Page"]
  end
end
