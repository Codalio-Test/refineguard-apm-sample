# frozen_string_literal: true

module Refineguard
  # the "run locally" training job behind the retraining workbench.
  class BaselineTrainingJob < ApplicationJob
    queue_as :default

    def perform(model_baseline_id)
      baseline = ModelBaseline.find_by(id: model_baseline_id)
      return if baseline.nil?

      Rhino.for_user(nil).in_organization(baseline.organization).run do
        Refineguard::BaselineTrainingService.train(baseline)
      end
    end
  end
end
