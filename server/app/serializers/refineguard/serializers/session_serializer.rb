# frozen_string_literal: true

module Refineguard
  module Serializers
    # The signed-in identity payload for `GET /api/:organization/me`
    # Answers with the current user, their role slugs IN THIS organization, the
    # organization itself, and which credential / CMMS adapters are live (so the
    # UI can render SIMULATED rather than implying a real directory bind or CMMS
    # transmission)
    class SessionSerializer < Base
      def initialize(user, organization)
        super(user)
        @organization = organization
      end

      def render
        {
          user: user_attributes,
          organization: organization_attributes,
          authentication: authentication_attributes
        }
      end

      private

      attr_reader :organization

      def user_attributes
        {
          id: record.id,
          name: record.name,
          display_name: record.display_name,
          email: record.email,
          first_name: record.first_name,
          last_name: record.last_name,
          approved: record.approved,
          profile_completed: record.profile_completed,
          role_slugs: role_slugs
        }
      end

      # Roles held in the CURRENT organization only. `user.roles` spans every
      # tenant the user belongs to, so reading it here would hand the browser
      # another tenant's role names
      def role_slugs
        record.user_roles
              .where(organization_id: organization.id)
              .includes(:role)
              .map { |membership| membership.role&.slug }
              .compact
              .uniq
      end

      def organization_attributes
        { id: organization.id, name: organization.name, slug: organization.slug }
      end

      def authentication_attributes
        {
          ldap: adapter_attributes(Refineguard::Ldap.mode_label,
                                   Refineguard::Ldap.configuration.simulated?),
          cmms: adapter_attributes(Refineguard::Cmms.configuration.adapter_name,
                                   Refineguard::Cmms.configuration.simulated?)
        }
      end

      def adapter_attributes(adapter, simulated)
        { adapter: adapter, simulated: simulated }
      end
    end
  end
end
