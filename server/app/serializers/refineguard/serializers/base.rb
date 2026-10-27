# frozen_string_literal: true

module Refineguard
  module Serializers
    # Base class for the custom endpoints' response payloads
    # Rhino's generated CRUD pipeline serializes through the model's
    # `as_rhino_json`; a hand-written endpoint needs the same discipline, so each
    # resource owns ONE serializer and the controllers ask it for the named shape
    # they need instead of building inline hashes at every call site
    class Base
      # @param record [Object] the resource (or value object) being serialized
      def initialize(record)
        @record = record
      end

      private

      attr_reader :record
    end
  end
end
