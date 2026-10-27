# frozen_string_literal: true

module Api
  # Asset hierarchy import, validate/publish and the ISA-95 tree read model.
  class AssetsController < BaseController
    # POST /api/{organization}/assets/import   (CSV / JSON / XML)
    def import
      return if deny!(AssetPolicy, :import?, Asset)

      content = upload_content
      if content.blank?
        return render_errors([ "A CSV, JSON or XML file is required" ], :unprocessable_entity)
      end

      result = Refineguard::AssetImportService.new(
        organization: current_organization,
        content: content,
        filename: upload_filename
      ).call

      if result.success?
        Refineguard::SecurityAuditWriter.call(
          organization: current_organization, user: current_user,
          action_type: "ASSET_HIERARCHY_IMPORT", severity: "warning", result: "Success",
          entity_affected: "#{result.imported} assets",
          details: { "imported" => result.imported }
        )
        render json: {
          imported: result.imported,
          message: "#{result.imported} asset twin(s) imported successfully."
        }, status: :created
      else
        render json: {
          errors: result.errors,
          error_count: result.errors.length,
          # The exact conflicting rows, so the builder can highlight them.
          conflict_rows: result.conflict_rows
        }, status: :unprocessable_entity
      end
    end

    #  POST /api/{organization}/assets/validate_hierarchy
    def validate_hierarchy
      return if deny!(AssetPolicy, :index?, Asset)

      report = Refineguard::AssetHierarchyService.validate(current_organization)

      Refineguard::SecurityAuditWriter.call(
        organization: current_organization, user: current_user,
        action_type: "ASSET_HIERARCHY_VALIDATE",
        severity: report["valid"] ? "info" : "warning",
        result: report["valid"] ? "Success" : "Failure",
        entity_affected: "#{report['assets_checked']} assets",
        details: { "errors" => report["errors"].length }
      )

      render json: report.merge("published" => report["valid"])
    end

    #  GET /api/{organization}/assets/hierarchy
    def hierarchy
      return if deny!(AssetPolicy, :index?, Asset)

      render json: {
        tree: Refineguard::AssetHierarchyService.tree(current_organization),
        generated_at: Time.current.iso8601
      }
    end
  end
end
