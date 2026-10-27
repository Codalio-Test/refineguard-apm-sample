# frozen_string_literal: true

require "test_helper"

# The shared importer base and the two concrete importers.
#
# Format detection (extension and content sniffing), the parser paths (CSV, JSON
# with a root key, XML) and the per-row domain rules are all pinned here.
class ImporterTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "import-org", name: "Import Org")
    @unit = PlantUnit.create!(organization: @org, unit_code: "CDU-1", unit_name: "CDU 1")
    @connector = HistorianConnector.create!(organization: @org, connector_name: "PI",
                                            historian_type: "OSIsoft_PI", status: "Connected")
  end

  def asset_importer(content, filename: nil, format: nil)
    Refineguard::AssetImportService.new(organization: @org, content: content,
                                        filename: filename, format: format)
  end

  def tag_importer(content, filename: nil, format: nil)
    Refineguard::HistorianTagImporter.new(organization: @org, content: content,
                                          filename: filename, format: format)
  end

  def asset_row(overrides = {})
    { "asset_tag" => "P-101A", "unit_id" => "CDU-1", "equipment_class" => "Centrifugal Pump",
      "driver_type" => "Electric Motor", "bearing_de_model" => "SKF 6314",
      "bearing_nde_model" => "SKF 7314", "rated_rpm" => "1795" }.merge(overrides)
  end

  # ---- shared base behaviour ------------------------------------------------

  test "empty content is refused with a readable message" do
    assert_equal [ "Import file is empty" ], asset_importer("").call.errors
    assert_equal [ "Import file is empty" ], tag_importer("").call.errors
  end

  test "malformed JSON and CSV are treated as empty" do
    assert_equal [ "Import file is empty" ], asset_importer("{ not json", format: :json).call.errors
    assert_equal [ "Import file is empty" ], asset_importer("\"unterminated", format: :csv).call.errors
  end

  test "the format is sniffed from the content when the filename is unhelpful" do
    json = asset_importer([ asset_row ].to_json).call
    assert_equal 1, json.imported

    xml = <<~XML
      <assets><asset asset_tag="P-101B" unit_id="CDU-1" equipment_class="Centrifugal Pump"
      driver_type="Electric Motor" bearing_de_model="SKF 6314" bearing_nde_model="SKF 7314"
      rated_rpm="1795" /></assets>
    XML
    assert_equal 1, asset_importer(xml).call.imported
  end

  test "a JSON payload under the declared root key is unwrapped" do
    payload = { "assets" => [ asset_row ] }.to_json
    assert_equal 1, asset_importer(payload, filename: "assets.json").call.imported

    tags = { "tags" => [ { "historian_type" => "OSIsoft_PI", "source_tag_name" => "T1",
                           "engineering_unit" => "mm/s", "scan_rate_ms" => "1000",
                           "deadband_val" => "0.1" } ] }.to_json
    assert_equal 1, tag_importer(tags, filename: "tags.json").call.created
  end

  test "an unknown extension falls back to sniffing and the CSV extension wins" do
    csv = "asset_tag,unit_id,equipment_class,driver_type,bearing_de_model,bearing_nde_model,rated_rpm\n" \
          "P-101C,CDU-1,Centrifugal Pump,Electric Motor,SKF 6314,SKF 7314,1795\n"
    assert_equal 1, asset_importer(csv, filename: "assets.CSV").call.imported
  end

  # ---- asset hierarchy ------------------------------------------------------

  test "a missing required column rejects the file and flags the row" do
    result = asset_importer([ asset_row("driver_type" => "") ].to_json, filename: "a.json").call

    assert_not result.success?
    assert_match(/missing required column\(s\) driver_type/, result.errors.join(" "))
    assert_equal [ 1 ], result.conflict_rows
  end

  test "an unknown equipment class, a non-numeric rpm and an unknown unit are rejected" do
    result = asset_importer(
      [ asset_row, asset_row("asset_tag" => "P-102A", "equipment_class" => "Reciprocating Thing"),
        asset_row("asset_tag" => "P-103A", "rated_rpm" => "fast"),
        asset_row("asset_tag" => "P-104A", "unit_id" => "NOPE") ].to_json, filename: "a.json"
    ).call

    joined = result.errors.join(" ")
    assert_not result.success?
    assert_match(/equipment_class must be one of/, joined)
    assert_match(/rated_rpm must be numeric/, joined)
    assert_match(/unit_id 'NOPE' does not match/, joined)
  end

  test "a duplicate tag inside the file and an existing tag are both rejected" do
    Asset.create!(organization: @org, asset_tag: "P-777A", asset_name: "Existing", monitored: true)

    result = asset_importer(
      [ asset_row, asset_row, asset_row("asset_tag" => "P-777A") ].to_json, filename: "a.json"
    ).call

    joined = result.errors.join(" ")
    assert_match(/duplicate asset_tag 'P-101A' \(also on row 1\)/, joined)
    assert_match(/already exists in this organization/, joined)
  end

  test "a parent tag missing from both the file and the hierarchy is rejected" do
    result = asset_importer([ asset_row("parent_asset_tag" => "GHOST-1") ].to_json,
                            filename: "a.json").call

    assert_match(/parent asset 'GHOST-1' is not in the file or the hierarchy/,
                 result.errors.join(" "))
  end

  test "a parent tag present earlier in the file is accepted" do
    result = asset_importer(
      [ asset_row("asset_tag" => "P-200"), asset_row("asset_tag" => "P-201", "parent_asset_tag" => "P-200") ].to_json,
      filename: "a.json"
    ).call

    assert result.success?
    assert_equal 2, result.imported
    assert_equal Asset.find_by(asset_tag: "P-200").id, Asset.find_by(asset_tag: "P-201").parent_asset_id
  end

  test "a numeric unit reference resolves to its plant unit" do
    result = asset_importer([ asset_row("unit_id" => @unit.id.to_s) ].to_json,
                            filename: "a.json").call

    assert result.success?
    assert_equal @unit.id, Asset.find_by(asset_tag: "P-101A").plant_unit_id
  end

  # ---- historian tags -------------------------------------------------------

  test "an unknown historian type, a non-positive scan rate and a non-numeric deadband fail" do
    rows = [
      { "historian_type" => "Wonderware", "source_tag_name" => "T1", "engineering_unit" => "mm/s",
        "scan_rate_ms" => "1000", "deadband_val" => "0.1" },
      { "historian_type" => "OSIsoft_PI", "source_tag_name" => "T2", "engineering_unit" => "mm/s",
        "scan_rate_ms" => "0", "deadband_val" => "x" }
    ]

    result = tag_importer(rows.to_json, filename: "tags.json").call
    joined = result.errors.join(" ")

    assert_not result.success?
    assert_match(/historian_type must be one of/, joined)
    assert_match(/scan_rate_ms must be a positive integer/, joined)
    assert_match(/deadband_val must be numeric/, joined)
  end

  test "a valid tag row persists with its mapping state" do
    rows = [ { "historian_type" => "Honeywell_PHD", "source_tag_name" => "T9",
               "engineering_unit" => "degC", "scan_rate_ms" => "5000", "deadband_val" => "0.5",
               "historian_connector_id" => @connector.id } ]

    result = tag_importer(rows.to_json, filename: "tags.json").call

    assert result.success?
    assert_equal 1, result.created
    tag = HistorianTag.find_by(source_tag_name: "T9")
    assert_equal "Honeywell_PHD:T9", tag.tag_path
    assert_equal "Unmapped", tag.mapping_state
    assert_not tag.mapped
  end

  test "an explicitly mapped tag row records its mapping" do
    asset = Asset.create!(organization: @org, asset_tag: "P-500A", asset_name: "Mapped pump",
                          monitored: true)
    rows = [ { "historian_type" => "OSIsoft_PI", "source_tag_name" => "T10", "tag_path" => "PI:T10",
               "engineering_unit" => "mm/s", "scan_rate_ms" => "1000", "deadband_val" => "0.1",
               "mapped" => "true", "asset_id" => asset.id.to_s } ]

    assert_equal 1, tag_importer(rows.to_json, filename: "tags.json").call.created
    tag = HistorianTag.find_by(tag_path: "PI:T10")
    assert tag.mapped
    assert_equal "Mapped", tag.mapping_state
    assert_equal asset.id, tag.asset_id
  end
end
