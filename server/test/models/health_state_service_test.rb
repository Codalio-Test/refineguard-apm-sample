# frozen_string_literal: true

require "test_helper"

# the automatic health-state transition.
class HealthStateServiceTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "health-org", name: "Health Org")
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Pump A",
                           health_state: "Normal", health_index: 88.0)
  end

  def index_row(error:)
    AssetHealthIndex.create!(
      organization: @org, asset: @asset, calculated_at: Time.current,
      health_score: 88.0, health_state: "Normal",
      reconstruction_error: error, threshold_p99: 0.09
    )
  end

  test "three consecutive p99 breaches transition Normal to Alert" do
    # reconstruction error > p99 for 3 consecutive intervals.
    row = index_row(error: 0.12)

    3.times { Refineguard::HealthStateService.evaluate(row) }

    assert_equal 3, row.reload.consecutive_breach_intervals
    assert_equal "Alert", row.health_state
    assert_equal "Alert", @asset.reload.health_state
  end

  test "two breaches do not transition, and a clean interval resets the counter" do
    row = index_row(error: 0.12)
    2.times { Refineguard::HealthStateService.evaluate(row) }
    assert_equal 2, row.reload.consecutive_breach_intervals
    assert_equal "Normal", row.health_state

    row.update!(reconstruction_error: 0.01)
    Refineguard::HealthStateService.evaluate(row)
    assert_equal 0, row.reload.consecutive_breach_intervals
    assert_equal "Normal", row.health_state
  end
end
