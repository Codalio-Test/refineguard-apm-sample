# frozen_string_literal: true

require "test_helper"

# The ≤50-tag batch validation harness.
#
# Each row reports success, the sample value and the round-trip latency; a tag
# that is invalid, stale beyond 60 s or reporting a bad OPC quality flag is a
# failure row, and an over-size batch is refused before any row is validated.
class TagValidationServiceTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "tagval-org", name: "TagVal Org")
    @connector = HistorianConnector.create!(organization: @org, connector_name: "PI",
                                            historian_type: "OSIsoft_PI", status: "Connected")
  end

  def tag(attrs = {})
    HistorianTag.create!({
      organization: @org, historian_type: "OSIsoft_PI", source_tag_name: "P204A.VIB.OH",
      tag_path: "PI:P204A.VIB.OH", engineering_unit: "mm/s", scan_rate_ms: 1000,
      deadband_val: 0.1, quality_status: "Good", last_value: 8.42, stale_seconds: 8,
      historian_connector: @connector
    }.merge(attrs))
  end

  def service(tags: nil, tag_ids: nil)
    Refineguard::TagValidationService.new(organization: @org, tags: tags, tag_ids: tag_ids)
  end

  test "a healthy persisted tag passes with its sample value and latency" do
    healthy = tag
    result = service.call

    assert result.success?
    row = result.rows.first
    assert row.success
    assert_equal healthy.id, row.tag_id
    assert_equal 8.42, row.value
    assert_equal "Good", row.quality_status
    assert_equal 8, row.stale_seconds
    assert_equal 1, result.passed
    assert_equal 0, result.failed
    assert result.within_budget
    assert_operator result.duration_ms, :>=, 0
  end

  test "a bad quality flag, a stale reading and a missing path each fail the row" do
    tag(quality_status: "Bad - 0 (OPC Quality)")
    tag(tag_path: "PI:P204B.VIB.OH", source_tag_name: "P204B", stale_seconds: 900)

    result = service.call
    messages = result.rows.flat_map(&:errors).join(" ")

    assert_equal 2, result.failed
    assert_match(/quality flag is bad/, messages)
    assert_match(/tag is stale/, messages)

    inline = service(tags: [ { "tag_path" => nil, "historian_type" => "Wonderware" } ]).call
    assert_equal 1, inline.failed
    assert_match(/tag path is required/, inline.rows.first.errors.join(" "))
    assert_match(/historian_type must be/, inline.rows.first.errors.join(" "))
  end

  test "a tag with no stored value falls back to its latest telemetry record" do
    bare = tag(tag_path: "PI:P204C.VIB.OH", source_tag_name: "P204C", last_value: nil)
    TelemetryRecord.create!(organization: @org, historian_tag: bare, recorded_at: 1.minute.ago,
                            recorded_value: 4.2, data_quality_flag: "Good")

    result = service.call
    assert_equal 4.2, result.rows.first.value
  end

  test "an inline payload reuses a persisted tag when it carries an id" do
    persisted = tag
    result = service(tags: [ { "id" => persisted.id, "tag_path" => persisted.tag_path } ]).call

    assert result.success?
    assert_equal persisted.id, result.rows.first.tag_id
  end

  test "a batch larger than the cap is refused wholesale" do
    inline = Array.new(Refineguard::TagValidationService::MAX_TAGS_PER_BATCH + 1) do |index|
      { "historian_type" => "OSIsoft_PI", "source_tag_name" => "T#{index}",
        "tag_path" => "PI:T#{index}", "engineering_unit" => "mm/s", "scan_rate_ms" => 1000,
        "deadband_val" => 0.1 }
    end

    result = service(tags: inline).call

    assert_equal 0, result.passed
    assert_equal 1, result.failed
    assert_match(/at most #{Refineguard::TagValidationService::MAX_TAGS_PER_BATCH}/,
                 result.rows.first.errors.join(" "))
  end

  test "the tag ids filter narrows the persisted population" do
    first = tag
    tag(tag_path: "PI:P204D.VIB.OH", source_tag_name: "P204D", stale_seconds: 5)

    result = service(tag_ids: [ first.id ]).call
    assert_equal 1, result.rows.length
    assert_equal first.id, result.rows.first.tag_id
  end
end
