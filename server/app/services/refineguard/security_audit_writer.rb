# frozen_string_literal: true

require "digest"

module Refineguard
  # the append-only, tamper-evident audit writer.
  #
  # Every row chains to its predecessor:
  #
  #   tamper_proof_hash = sha256(previous_hash + canonical_payload)
  #
  # and `previous_hash` is the hash of the newest existing row for the
  # organization. Nothing in the API can write or mutate a SecurityAuditEvent —
  # no role holds `security_audit_events.store/update/destroy` — so this service
  # is the only write path.
  #
  # Callers: the auth lifecycle hooks (login/logout/failure/lockout), the
  # retention training service, the CMMS dispatch service, the anomaly
  # acknowledgement transition and the derate approval flow.
  class SecurityAuditWriter
    # Sentinel used when the request/console provides no user agent or host.
    UNKNOWN_HOST = "unknown"

    class << self
      # Append one immutable event.
      #
      # @param organization [Organization, nil]
      # @param action_type [String] e.g. 'LOGIN', 'ACKNOWLEDGE', 'DISPATCH_WORK_ORDER'
      # @param user [User, nil]
      # @param actor_role [String, nil]
      # @param entity_affected [String, nil]
      # @param severity [String] info|warning|critical
      # @param result [String] Success|Failure|Denied
      # @param source_host [String, nil]
      # @param details [Hash, nil]
      # @return [SecurityAuditEvent, nil]
      def call(organization:, action_type:, user: nil, actor_role: nil, entity_affected: nil,
               severity: "info", result: "Success", source_host: nil, details: nil,
               recorded_at: Time.current)
        return nil if organization.nil?

        previous = SecurityAuditEvent.for_organization(organization).order(:id).last
        previous_hash = previous&.tamper_proof_hash

        event = SecurityAuditEvent.new(
          organization: organization,
          user: user,
          actor_name: user&.email || "service",
          actor_role: actor_role || role_slug_for(user, organization),
          action_type: action_type,
          entity_affected: entity_affected,
          source_host: source_host || UNKNOWN_HOST,
          severity: severity,
          result: result,
          recorded_at: recorded_at,
          previous_hash: previous_hash,
          details_json: details
        )
        event.tamper_proof_hash = Digest::SHA256.hexdigest(
          "#{previous_hash}#{event.canonical_payload}"
        )
        event.save!
        event
      end

      # Append from a controller/action context, pulling the request metadata.
      #
      # @param request [ActionDispatch::Request, nil]
      def call_with_request(request:, **kwargs)
        if request
          kwargs[:source_host] ||= request.remote_ip
          kwargs[:details] = (kwargs[:details] || {}).merge(
            "ip_address" => request.remote_ip,
            "user_agent" => request.user_agent
          )
        end
        call(**kwargs)
      end

      # Verify the whole chain for an organization. Returns the ids of any row
      # whose hash does not match its recomputed value.
      def verify_chain(organization)
        SecurityAuditEvent.for_organization(organization).order(:id).each_with_object([]) do |event, broken|
          broken << event.id unless event.tamper_proof?
        end
      end

      private

      def role_slug_for(user, organization)
        return nil unless user.respond_to?(:role_slug_for_validation)

        user.role_slug_for_validation(organization)
      end
    end
  end
end
