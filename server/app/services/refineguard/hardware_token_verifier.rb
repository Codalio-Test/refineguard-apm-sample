# frozen_string_literal: true

require "openssl"

module Refineguard
  # hardware-token second factor, verified entirely server-side.
  #
  # The locked /login prototype has no extra input field, so the factor is
  # carried out-of-band exactly as an OT badge reader would: the SPA (or the
  # badge middleware in front of it) supplies the 6-digit code in the
  # `X-Hardware-Token` header or the `hardware_token` parameter.
  #
  # A user WITH a registered `hardware_token_secret` (provisioned from the
  # physical token) must present a valid code. A user without one authenticates
  # on the local directory credential alone — the documented air-gapped default.
  class HardwareTokenVerifier
    DRIFT_WINDOWS = 1
    CODE_LENGTH = 6

    class << self
      # @return [Boolean] whether the identity must present a token at all.
      def required_for?(user)
        user.present? && user.hardware_token_secret.present?
      end

      # @param user [User]
      # @param code [String, nil] the presented code
      # @param at [Time]
      # @return [Boolean]
      def verify(user, code, at: Time.current)
        return true unless required_for?(user)
        return false if code.blank?

        normalized = code.to_s.strip
        return false unless normalized.match?(/\A\d{#{CODE_LENGTH}}\z/)

        (-DRIFT_WINDOWS..DRIFT_WINDOWS).any? do |drift|
          secure_compare(normalized, code_for(user, at + (drift * 30)))
        end
      end

      # The code a provisioned token would display for that instant.
      def code_for(user, at = Time.current)
        counter = (at.to_i / 30)
        digest = OpenSSL::HMAC.digest("SHA1", user.hardware_token_secret.to_s, [ counter ].pack("Q>"))
        offset = digest.bytes.last & 0x0F
        binary = digest.byteslice(offset, 4).unpack1("N") & 0x7FFFFFFF
        format("%0#{CODE_LENGTH}d", binary % (10**CODE_LENGTH))
      end

      def secure_compare(candidate, expected)
        return false if candidate.bytesize != expected.bytesize

        candidate.bytes.zip(expected.bytes).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
      end
    end
  end
end
