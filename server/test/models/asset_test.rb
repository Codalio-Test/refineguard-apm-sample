# frozen_string_literal: true

require "test_helper"

# Asset model contract.
class AssetModelTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "model-org", name: "Model Org")
    @unit = PlantUnit.create!(organization: @org, unit_code: "CDU-1", unit_name: "CDU 1")
  end

  test "asset_tag and asset_name are required" do
    # the required writable scalar the host contract proves 422 with.
    asset = Asset.new(organization: @org)
    assert_not asset.valid?
    assert_includes asset.errors[:asset_tag], "can't be blank"
    assert_includes asset.errors[:asset_name], "can't be blank"
  end

  test "asset_tag is unique per organization but reusable across organizations" do
    # the tag is the tenant-scoped identity behind /assets/:tag.
    Asset.create!(organization: @org, asset_tag: "P-201A", asset_name: "A")
    duplicate = Asset.new(organization: @org, asset_tag: "P-201A", asset_name: "B")
    assert_not duplicate.valid?
    assert duplicate.errors[:asset_tag].any?

    other = Organization.create!(slug: "model-org-2", name: "Other")
    assert Asset.new(organization: other, asset_tag: "P-201A", asset_name: "C").valid?
  end

  test "member routes resolve the record by asset_tag, not the primary key" do
    # `/assets/P-101A/health-summary` carries the tag.
    assert_equal "asset_tag", Asset.rhino_resolved_route_key
  end

  test "severity vocabulary matches the locked SeverityBadge keys" do
    # Trip|Alarm -> critical, Alert -> warning, Normal -> healthy.
    expectations = { "Trip" => "critical", "Alarm" => "critical", "Alert" => "warning",
                     "Normal" => "healthy", nil => "info" }
    expectations.each do |state, badge|
      assert_equal badge, Refineguard::Severity.badge(state), "state #{state.inspect}"
    end
  end

  test "computed attributes carry the prototype contract keys" do
    # the fleet table reads id/name/unit/health/rms/temp/rul/sample.
    # Asserted on the computed-attribute hash: `as_rhino_json` additionally applies
    # the policy whitelist, and an anonymous user is (correctly) permitted nothing.
    asset = Asset.create!(
      organization: @org, plant_unit: @unit, asset_tag: "P-204A", asset_name: "Crude charge pump A",
      equipment_class: "Centrifugal Pump", health_state: "Trip", health_index: 28.0,
      rms_velocity_mms: 8.42, bearing_temp_c: 96.0, estimated_rul_window: "6–11 d",
      last_sample_at: Time.current - 12.seconds
    )

    json = asset.rhino_computed_attributes
    assert_equal "P-204A", json["id"]
    assert_equal asset.id, json["record_id"]
    assert_equal "Crude charge pump A", json["name"]
    assert_equal "CDU-1", json["unit"]
    assert_equal 28.0, json["health"]
    assert_equal "8.42", json["rms"]
    assert_equal "96", json["temp"]
    assert_equal "6–11 d", json["rul"]
    assert_equal "critical", json["severity"]
    assert_equal "Critical", json["status"]
    assert_equal "Centrifugal Pump", json["kind"]
  end

  test "an anonymous caller serializes only the route key" do
    # The engine layers the policy whitelist over the computed attributes; with
    # no authenticated user AssetPolicy permits nothing, so nothing leaks except
    # the route key the engine always keeps responses routable with.
    asset = Asset.create!(organization: @org, plant_unit: @unit, asset_tag: "P-205A",
                          asset_name: "Anonymous check", health_state: "Normal",
                          manufacturer: "Sulzer")
    json = asset.as_rhino_json
    assert_equal %w[asset_tag], json.keys
    assert_equal "P-205A", json["asset_tag"]
  end

  test "iso_severity_category follows ISO 10816 vibration zones" do
    # each card displays the ISO 10816 severity category.
    asset = Asset.new(organization: @org, asset_tag: "X", asset_name: "X")
    { 1.5 => "Good", 5.0 => "Satisfactory", 9.0 => "Unsatisfactory", 12.0 => "Unacceptable" }.each do |v, expected|
      asset.rms_velocity_mms = v
      assert_equal expected, asset.iso_severity_category
    end
    asset.rms_velocity_mms = nil
    assert_nil asset.iso_severity_category
  end

  test "sample_age_label formats the last-sample column" do
    asset = Asset.new(organization: @org, last_sample_at: Time.current - 12.seconds)
    assert_equal "12 s", asset.sample_age_label
    asset.last_sample_at = Time.current - 300.seconds
    assert_equal "5 min", asset.sample_age_label
    asset.last_sample_at = nil
    assert_nil asset.sample_age_label
  end

  test "health_index is bounded to 0..100" do
    asset = Asset.new(organization: @org, asset_tag: "X", asset_name: "X", health_index: 140.0)
    assert_not asset.valid?
    assert asset.errors[:health_index].any?
  end
end
