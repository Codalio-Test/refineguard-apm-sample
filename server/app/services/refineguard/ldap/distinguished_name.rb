# frozen_string_literal: true

module Refineguard
  module Ldap
    # RFC 4514 distinguished-name string escaping.
    #
    # An LDAP DN is assembled by string interpolation, so any value that comes
    # from user input (an email address here) MUST be escaped first, or a crafted
    # address can inject additional RDNs and change which principal is bound.
    # See RFC 4514 §2.4: `"`, `+`, `,`, `;`, `<`, `>`, `\` and `=` are escaped
    # wherever they appear; a leading `#` or space and a trailing space are
    # escaped too.
    module DistinguishedName
      ESCAPED_ANYWHERE = [ '"', "+", ",", ";", "<", ">", "\\", "=" ].freeze

      class << self
        # @param value [String] the raw attribute value (e.g. an email address)
        # @return [String] the value safe to interpolate into a DN
        def escape(value)
          characters = value.to_s.chars
          characters.each_with_index.map do |character, index|
            escape_character(character, index, characters.length)
          end.join
        end

        private

        def escape_character(character, index, length)
          return "\\00" if character == "\0"
          return "\\#{character}" if ESCAPED_ANYWHERE.include?(character)
          return "\\#{character}" if leading_special?(character, index)
          return "\\#{character}" if trailing_space?(character, index, length)

          character
        end

        def leading_special?(character, index)
          index.zero? && (character == " " || character == "#")
        end

        def trailing_space?(character, index, length)
          index == length - 1 && character == " "
        end
      end
    end
  end
end
