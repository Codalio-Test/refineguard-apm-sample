# frozen_string_literal: true

require "test_helper"

# the loss-free ring buffer contract.
class HistorianBufferServiceTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "buffer-org", name: "Buffer Org")
    @connector = HistorianConnector.create!(
      organization: @org, connector_name: "PI Primary", historian_type: "OSIsoft_PI",
      status: "Connected", poll_latency_ms: 380, connection_timeout_ms: 3000,
      polling_interval_seconds: 5, ring_buffer_enabled: true,
      buffer_depth: 0, backfill_total: 100, backfill_committed: 100
    )
  end

  test "a link exceeding the 3000ms timeout switches to disk-backed buffering" do
    # timeout -> ring buffer engaged.
    result = Refineguard::HistorianBufferService.test_connection(
      @connector, simulated_latency_ms: 5000, pending_points: 4
    )

    assert result[:buffering]
    assert_equal "Buffering", result[:status]
    assert_equal 4, @connector.reload.buffer_depth
    assert_equal 104, @connector.backfill_total
  end

  test "recovery drains the ring buffer with zero lost points" do
    # replayed == buffered and lost == 0.
    Refineguard::HistorianBufferService.test_connection(
      @connector, simulated_latency_ms: 5000, pending_points: 4
    )
    @connector.reload

    result = Refineguard::HistorianBufferService.test_connection(
      @connector, simulated_latency_ms: 300
    )

    assert_not result[:buffering]
    assert_equal 4, result[:replayed]
    assert_equal 0, result[:lost]
    @connector.reload
    assert_equal "Connected", @connector.status
    assert_equal 0, @connector.buffer_depth
    assert_equal @connector.backfill_total, @connector.backfill_committed
  end

  test "ingest buffers while the link is buffering and commits otherwise" do
    assert_equal :committed, Refineguard::HistorianBufferService.ingest(@connector, points: 1)

    @connector.update!(status: "Buffering")
    assert_equal :buffered, Refineguard::HistorianBufferService.ingest(@connector, points: 3)
    assert_equal 3, @connector.reload.buffer_depth
  end
end
