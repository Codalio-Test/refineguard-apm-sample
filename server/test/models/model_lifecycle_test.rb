# frozen_string_literal: true

require "test_helper"

# the anomaly baseline retraining and evaluation workbench.
#
# golden window selection (7-30 days post-overhaul)
# local training computes goodness-of-fit + reconstruction-error
#          distributions inside the 60 s budget
# the trained candidate is compared against the validation dataset and
#          deployed with one-click sign-off
# every deployment is logged with model version, author and timestamp
# the training window end is recorded on the baseline
# the evaluation / promotion fields and the golden-window entity exist
class ModelLifecycleTest < ActiveSupport::TestCase
  OVERHAUL_AT = 30.days.ago

  setup do
    @org = Organization.create!(slug: "lifecycle-org", name: "Lifecycle Org")
    @user = User.create!(name: "Elena", email: "elena@example.com", password: "password")
    @asset = Asset.create!(organization: @org, asset_tag: "P-204A", asset_name: "Crude charge pump A",
                           health_state: "Normal", health_index: 96.0)

    # A 7-day golden window 7-30 days after the overhaul, plus a second candidate.
    @golden = BaselineWindow.create!(
      organization: @org, asset: @asset, label: "Golden run (14 d post-overhaul)",
      window_start: OVERHAUL_AT + 7.days, window_end: OVERHAUL_AT + 21.days,
      load_percent: 88.0, completeness_percent: 99.8, selected: true
    )
    BaselineWindow.create!(
      organization: @org, asset: @asset, label: "Turnaround window",
      window_start: OVERHAUL_AT - 20.days, window_end: OVERHAUL_AT - 6.days,
      load_percent: 70.0, completeness_percent: 93.0
    )

    @baseline = ModelBaseline.create!(
      organization: @org, asset: @asset, model_version: "v3.8.0-PCA-AE",
      algorithm_type: "Deep Autoencoder", status: "Candidate", training_status: "Idle"
    )
  end

  # the golden window is selectable, is bounded, and summarises itself for
  # the selector UI.
  test "a golden post-overhaul window is selectable and bounded" do
    assert_equal 2, @asset.baseline_windows.count
    assert_equal true, @golden.selected
    assert_equal true, @golden.eligible # defaulted eligible
    assert_equal 14, ((@golden.window_end - @golden.window_start) / 1.day).round

    summary = @golden.rhino_computed_attributes["summary"]
    assert_match(/Golden run/, summary)
    assert_match(/88% load/, summary)
    assert_match(/99.8% complete/, summary)

    inverted = BaselineWindow.new(organization: @org, asset: @asset, label: "Inverted",
                                  window_start: Time.current, window_end: 1.day.ago)
    assert_not inverted.valid?
    assert inverted.errors[:window_end].any?
  end

  # training runs locally, produces the evaluation
  # surface, and records the window it trained on.
  test "local training produces the evaluation surface inside the budget" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Refineguard::BaselineTrainingService.train(@baseline)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    @baseline.reload

    assert_operator elapsed, :<=, 60, "training must complete inside the 60 s budget"
    assert_equal "Trained", @baseline.training_status
    assert_equal 100, @baseline.training_progress
    assert_match(/Training complete/, @baseline.training_log)

    metrics = @baseline.accuracy_metrics_json
    %w[precision recall false_alarms lead_time_days drift coverage
       reconstruction_error_mean reconstruction_error_std].each do |key|
      assert metrics.key?(key), "accuracy metrics are missing #{key}"
    end
    assert_equal 1, metrics["windows_used"] # only the selected golden window

    assert @baseline.gates_json.any?
    assert @baseline.gates_satisfied?

    # the recorded training window is the golden window, not the default.
    assert_in_delta @golden.window_end.to_i, @baseline.training_window_end.to_i, 1
  end

  # gated promotion is the one-click deploy, archives the
  # previous production model, and writes the audit row.
  test "promotion deploys the candidate and logs version, author and timestamp" do
    previous = ModelBaseline.create!(
      organization: @org, asset: @asset, model_version: "v2.0.0-LEGACY",
      algorithm_type: "Deep Autoencoder", status: "Production", training_status: "Trained",
      is_active: true
    )

    Refineguard::BaselineTrainingService.train(@baseline)
    result = Refineguard::BaselineTrainingService.promote(@baseline.reload, @user)

    assert result[:promoted]
    assert_equal "Production", @baseline.reload.status
    assert_equal true, @baseline.is_active
    assert_equal @user.id, @baseline.approved_by_id
    assert_not_nil @baseline.promoted_at

    assert_equal "Archived", previous.reload.status
    assert_equal false, previous.is_active

    audit = SecurityAuditEvent.where(organization: @org, action_type: "BASELINE_PROMOTION").last
    assert_not_nil audit
    assert_equal @user.email, audit.actor_name # author
    assert_equal "v3.8.0-PCA-AE", audit.details_json["model_version"] # version
    assert audit.details_json["approved_at"].present? # timestamp
  end

  # an untrained candidate cannot be deployed.
  test "an untrained candidate is refused" do
    result = Refineguard::BaselineTrainingService.promote(@baseline, @user)

    assert_not result[:promoted]
    assert_equal "Candidate", @baseline.reload.status
    assert_match(/trained candidate/, result[:errors].first)
  end
end
