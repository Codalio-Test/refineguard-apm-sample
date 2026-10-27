# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Refineguard
  module Cmms
    # The real client: POSTs the work-order payload to the on-prem bridge and
    # only reports `confirmed` when the remote returns a success status. The
    # network call is what makes the timeout budget meaningful
    class HttpAdapter < Adapter
      def name
        "http"
      end

      def budget_ms
        Refineguard::Cmms.configuration.timeout_ms
      end

      def transmit(payload)
        endpoint = Refineguard::Cmms.configuration.endpoint
        return failure("CMMS endpoint is not configured") if endpoint.blank?

        uri = URI.parse(endpoint)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                   **timeouts) do |http|
          http.request(post_request(uri, payload))
        end
        interpret(response)
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
        failure("CMMS bridge did not acknowledge within #{budget_ms}ms")
      rescue StandardError => e
        failure(e.message)
      end

      private

      def post_request(uri, payload)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json
        request
      end

      def timeouts
        seconds = Refineguard::Cmms.configuration.timeout_ms / 1000.0
        { open_timeout: seconds, read_timeout: seconds }
      end

      def interpret(response)
        body = parse_body(response.body)
        return failure("CMMS bridge rejected the request (#{response.code})") unless response.is_a?(Net::HTTPSuccess)

        Transmission.new(
          transmitted: true,
          confirmed: true,
          confirmation: {
            "order_number" => body["order_number"] || body["external_order_number"],
            "response" => body
          }
        )
      end

      def parse_body(raw)
        JSON.parse(raw.to_s)
      rescue JSON::ParserError
        {}
      end

      def failure(message)
        Transmission.new(transmitted: false, confirmed: false, error: message)
      end
    end
  end
end
