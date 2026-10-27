# frozen_string_literal: true

require "test_helper"

# historian tag staleness and quality gating.
class HistorianTagModelTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "tag-org", name: "Tag Org")
  end

  def build(overrides = {})
    HistorianTag.new({
      organization: @org, historian_type: "OSIsoft_PI", source_tag_name: "P204A.VIB.OH",
      tag_path: "PI:P204A.VIB.OH", engineering_unit: "mm/s", scan_rate_ms: 1000,
      deadband_val: 0.1, quality_status: "Good"
    }.merge(overrides))
  end

  test "required mapping fields are validated" do
    # historian_type / source_tag_name / tag_path are mandatory.
    tag = HistorianTag.new(organization: @org)
    assert_not tag.valid?
    assert_includes tag.errors[:historian_type], "can't be blank"
    assert_includes tag.errors[:source_tag_name], "can't be blank"
    assert_includes tag.errors[:tag_path], "can't be blank"
  end

  test "historian_type is restricted to the supported historians" do
    assert_not build(historian_type: "Wonderware").valid?
    assert build(historian_type: "Honeywell_PHD").valid?
  end

  test "a bad OPC quality flag blocks twin activation" do
    # red row, blocks activation.
    tag = build(quality_status: "Bad - 0 (OPC Quality)")
    assert tag.bad_quality?
    assert_not tag.healthy?
    assert_equal "critical", tag.rhino_computed_attributes["severity"]
  end

  test "staleness beyond 60 seconds blocks twin activation" do
    # stale > 60 s flags the row.
    stale = build(tag_path: "PI:STALE", source_tag_name: "STALE", stale_seconds: 412)
    fresh = build(tag_path: "PI:FRESH", source_tag_name: "FRESH", stale_seconds: 8)

    assert stale.stale?
    assert_not stale.healthy?
    assert_not fresh.stale?
    assert fresh.healthy?
  end

  test "staleness is computed from last_validated_at when the column is blank" do
    # the fallback path for rows never polled.
    tag = build(tag_path: "PI:COMPUTED", source_tag_name: "COMPUTED",
                last_validated_at: Time.current - 90.seconds)
    assert_equal 90, tag.computed_stale_seconds
    assert tag.stale?
  end

  test "tag_path is unique per organization" do
    build.save!
    duplicate = build(source_tag_name: "OTHER")
    assert_not duplicate.valid?
    assert duplicate.errors[:tag_path].any?
  end
end
