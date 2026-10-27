# frozen_string_literal: true

module Api
  # Historian tag mapping import and the batch validation harness.
  class HistorianTagsController < BaseController
    # POST /api/{organization}/historian_tags/import   (multipart file or raw body)
    def import
      return if deny!(HistorianTagPolicy, :import?, HistorianTag)

      content = upload_content
      if content.blank?
        return render_errors([ "A CSV or JSON file is required" ], :unprocessable_entity)
      end

      result = Refineguard::HistorianTagImporter.new(
        organization: current_organization,
        content: content,
        filename: upload_filename
      ).call

      if result.success?
        Refineguard::SecurityAuditWriter.call(
          organization: current_organization, user: current_user,
          action_type: "HISTORIAN_TAG_IMPORT", severity: "warning", result: "Success",
          entity_affected: "#{result.created} historian tags",
          details: { "created" => result.created }
        )
        render json: {
          created: result.created,
          message: "#{result.created} historian tag mapping(s) imported successfully."
        }, status: :created
      else
        render json: { errors: result.errors, error_count: result.errors.length },
               status: :unprocessable_entity
      end
    end

    #  POST /api/{organization}/historian_tags/validate_batch
    def validate_batch
      return if deny!(HistorianTagPolicy, :validate_batch?, HistorianTag)

      tags = params[:tags]
      tag_ids = params[:tag_ids]

      if tags.blank? && tag_ids.blank?
        # Validate the whole mapped population when the client asks for a sweep.
        result = Refineguard::TagValidationService.new(organization: current_organization).call
      else
        result = Refineguard::TagValidationService.new(
          organization: current_organization,
          tags: tags,
          tag_ids: tag_ids
        ).call
      end

      render json: {
        duration_ms: result.duration_ms,
        budget_ms: Refineguard::TagValidationService::LATENCY_BUDGET_MS,
        within_budget: result.within_budget,
        passed: result.passed,
        failed: result.failed,
        success: result.success?,
        results: result.rows.map { |row|
          Refineguard::Serializers::TagValidationRowSerializer.new(row).row
        }
      }
    end
  end
end
