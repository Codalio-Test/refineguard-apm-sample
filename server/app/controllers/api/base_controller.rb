# frozen_string_literal: true

module Api
  # Base class for RefineGuard's non-CRUD endpoints
  # Every custom controller re-establishes the two invariants Rhino's generated
  # CRUD pipeline gives for free
  # 1. the organization comes from the URL segment resolved against
  # `organizations.slug` (never from a client-supplied body/param), and a
  # user without a membership in it gets the information-hiding 404
  # 2. data access goes through `Rhino.query`, which fails closed
  # (`Rhino::MissingTenantContext`) rather than leaking every tenant's rows
  # Authorization is always an explicit per-resource policy gate; the resolver
  # scopes ROWS, policies authorize ACCESS.
  class BaseController < ActionController::API
    include Rhino::RouteGroupContext
    include Pundit::Authorization

    rhino_route_group :tenant

    # Every custom endpoint answers with ONE error shape
    # `{ "errors": ["message", ...] }` and the matching status, so a client reads
    # the same key whether the failure came from the 401/403/404 gates here or
    # from a validation failure inside an action.
    rescue_from Pundit::NotAuthorizedError do |_e|
      render_errors([ "This action is unauthorized." ], :forbidden)
    end

    rescue_from Rhino::MissingTenantContext do |_e|
      render_errors([ "Organization context is required." ], :bad_request)
    end

    before_action :resolve_organization!
    before_action :authenticate_user!

    # 30-minute idle session expiry. The guard is also mixed into the engine's
    # generated CRUD/auth controllers; it lives here so a custom endpoint cannot
    # be reached by a token that the rest of the API would already reject
    include SessionIdleGuard

    private

    def resolve_organization!
      identifier = params[:organization]
      if identifier.blank?
        return render_errors([ "Organization not found" ], :not_found)
      end

      column = Rhino.config.multi_tenant[:organization_identifier_column] || "id"
      organization = Organization.find_by(column => identifier)

      if organization.nil?
        return render_errors([ "Organization not found" ], :not_found)
      end

      if current_user && !current_user.user_roles.exists?(organization_id: organization.id)
        return render_errors([ "Organization not found" ], :not_found)
      end

      request.env["rhino.organization"] = organization
      RequestStore.store[:rhino_organization] = organization
    end

    def authenticate_user!
      return if current_user

      render_errors([ "Unauthenticated." ], :unauthorized)
    end

    def current_user
      @current_user ||= begin
        token = request.headers["Authorization"]&.sub(/\ABearer /, "")
        if token.present? && User.column_names.include?("api_token")
          user = User.find_by_api_token(token)
          RequestStore.store[:rhino_current_user] = user if user
          user
        end
      end
    end

    def current_organization
      request.env["rhino.organization"]
    end

    # Explicit policy gate. Rendering happens here so callers can `return if`
    # @return [Boolean] true when the action was denied (a response was rendered)
    def deny!(policy_class, action, record)
      policy = policy_class.new(current_user, record)
      return false if policy.public_send(action)

      render_errors([ "This action is unauthorized." ], :forbidden)
      true
    end

    # The single error envelope for every custom endpoint
    # @param messages [Array<String>] one or more human-readable messages
    def render_errors(messages, status)
      render json: { errors: Array(messages).map(&:to_s) }, status: status
    end

    # The uploaded file or raw body of an import request.
    def upload_content
      upload = params[:file] || params[:import] || params[:template]
      return upload.read if upload.respond_to?(:read)
      return upload.to_s if upload.is_a?(String)

      raw = request.raw_post
      raw.presence
    end

    def upload_filename
      upload = params[:file] || params[:import] || params[:template]
      upload.respond_to?(:original_filename) ? upload.original_filename : params[:filename]
    end
  end
end
