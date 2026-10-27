# frozen_string_literal: true

require "csv"

module Api
  # signed audit evidence export
  # Streams the append-only security trail as JSON or CSV together with a
  # sha256 signature over the ordered hash chain, so a downloaded bundle can be
  # verified offline. Admin-only.
  class SecurityAuditEventsController < BaseController
    # GET /api/{organization}/security_audit_events/export?format=json|csv
    def export
      return if deny!(SecurityAuditEventPolicy, :export?, SecurityAuditEvent)

      events = Rhino.query(SecurityAuditEvent).order(:id).to_a
      signature = chain_signature(events)
      broken = events.reject(&:tamper_proof?).map(&:id)

      case requested_export_format
      when "csv"
        send_data csv_for(events, signature, broken),
                  filename: export_filename("csv"),
                  type: "text/csv",
                  disposition: "attachment"
      else
        render json: {
          "generated_at" => Time.current.iso8601,
          "organization" => current_organization.slug,
          "signature" => signature,
          "signature_algorithm" => "sha256-over-ordered-hash-chain",
          "chain_length" => events.length,
          "tampered_event_ids" => broken,
          "verification" => broken.empty? ? "Chain verified" : "Chain integrity failure",
          "events" => events.map { |event| serializer(event).row }
        }
      end
    end

    private

    # `?format=` collides with the route's `(.:format)` default, which Rails
    # merges into path parameters with higher precedence than the query string.
    # Read the query parameter directly so `?format=csv` really means CSV.
    def requested_export_format
      (request.query_parameters["format"] || params[:export_format] || "json").to_s.downcase
    end

    def serializer(event)
      Refineguard::Serializers::SecurityAuditEventSerializer.new(event)
    end

    def chain_signature(events)
      Digest::SHA256.hexdigest(events.map(&:tamper_proof_hash).join)
    end

    def export_filename(extension)
      "refineguard-security-audit-#{current_organization.slug}-#{Time.current.strftime('%Y%m%d%H%M%S')}.#{extension}"
    end

    def csv_for(events, signature, broken)
      CSV.generate do |csv|
        csv << [ "# RefineGuard APM tamper-evident audit export" ]
        csv << [ "# organization", current_organization.slug ]
        csv << [ "# generated_at", Time.current.iso8601 ]
        csv << [ "# signature_sha256", signature ]
        csv << [ "# verification", broken.empty? ? "Chain verified" : "Chain integrity failure" ]
        csv << []
        csv << Refineguard::Serializers::SecurityAuditEventSerializer::CSV_HEADERS
        events.each { |event| csv << serializer(event).csv_row }
      end
    end
  end
end
