# frozen_string_literal: true

module Api
  # Local baseline training and gated promotion.
  class ModelBaselinesController < BaseController
    # POST /api/{organization}/model_baselines/:id/train
    def train
      baseline = Rhino.query(ModelBaseline).find_by(id: params[:id])
      return render_errors([ "Model baseline not found" ], :not_found) if baseline.nil?

      return if deny!(ModelBaselinePolicy, :train?, baseline)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Refineguard::BaselineTrainingService.train(baseline)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      Refineguard::SecurityAuditWriter.call(
        organization: current_organization, user: current_user,
        action_type: "BASELINE_TRAINING", severity: "info", result: "Success",
        entity_affected: "#{baseline.model_version} (#{baseline.asset&.asset_tag})",
        details: { "duration_ms" => duration_ms, "training_status" => baseline.training_status }
      )

      render json: Refineguard::Serializers::ModelBaselineSerializer.new(baseline)
                       .training(duration_ms: duration_ms, budget_ms: 60_000)
    end

    # POST /api/{organization}/model_baselines/:id/promote
    def promote
      baseline = Rhino.query(ModelBaseline).find_by(id: params[:id])
      return render_errors([ "Model baseline not found" ], :not_found) if baseline.nil?

      return if deny!(ModelBaselinePolicy, :promote?, baseline)

      result = Refineguard::BaselineTrainingService.promote(baseline, current_user)

      unless result[:promoted]
        return render json: { errors: result[:errors], promoted: false },
                      status: :unprocessable_entity
      end

      render json: Refineguard::Serializers::ModelBaselineSerializer.new(baseline).promotion
    end
  end
end
