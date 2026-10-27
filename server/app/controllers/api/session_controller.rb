# frozen_string_literal: true

module Api
  # GET /api/:organization/me
  # The engine's login response is only `{ token, organization_slug }` — it carries
  # no user object — so the SPA has no server-side source for the signed-in user's
  # roles. The flat-route shell needs them to filter navigation and to gate
  # role-restricted screens, and inventing them client-side would be a
  # security-relevant lie: the sidebar would either hide everything or show
  # everything
  # This endpoint answers with the current user, their role slugs *in this
  # organization*, and the organization itself. It sits behind the same tenant
  # gates as every generated CRUD route: `resolve_organization!` resolves the
  # organization from the URL segment against `organizations.slug`, returns the
  # information-hiding 404 for an unknown organization or a non-member, and
  # `authenticate_user!` requires the bearer token.
  class SessionController < BaseController
    def show
      render json: Refineguard::Serializers::SessionSerializer.new(current_user,
                                                                   current_organization).render,
             status: :ok
    end
  end
end
