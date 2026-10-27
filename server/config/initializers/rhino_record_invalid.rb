# frozen_string_literal: true

# Rhino's legacy model-validation create path only reports errors for fields that
# were actually submitted, so an empty (or partially populated) payload reaches
# `create!` and the resulting ActiveRecord::RecordInvalid escapes as a raw 500.
#
# `to_prepare` re-registers the rescue after every reload in development.
Rails.application.config.to_prepare do
  Rhino::ResourcesController.rescue_from(ActiveRecord::RecordInvalid) do |e|
    render json: { errors: e.record.errors.to_hash }, status: :unprocessable_entity
  end
end
