# frozen_string_literal: true

require "csv"
require "rexml/document"

module Refineguard
  # Shared behaviour for the file importers (asset hierarchy, historian tags)
  # Owns the row-result contract, the format detection and the parse step, plus
  # the common "required column(s) missing" validation, so each concrete importer
  # only declares its columns and its domain rules
  class BaseImporter
    Result = Struct.new(:imported, :created, :errors, :conflict_rows, :rows, keyword_init: true) do
      def success?
        errors.empty?
      end
    end

    def initialize(organization:, content:, format: nil, filename: nil)
      @organization = organization
      @content = content.to_s
      @format = format || detect_format(filename)
    end

    private

    attr_reader :organization, :content

    # Subclass hooks

    def required_columns
      []
    end

    def json_root_key
      nil
    end

    def xml_supported?
      false
    end

    def xml_row_xpath
      "//asset"
    end

    # Extra per-row validation, on top of the required-column check
    def row_errors(_row, _line)
      []
    end

    # Format detection + parsing

    def detect_format(filename)
      name = filename.to_s.downcase
      return :json if name.end_with?(".json")
      return :xml if xml_supported? && name.end_with?(".xml")
      return :csv if name.end_with?(".csv")

      sniff_format
    end

    def sniff_format
      stripped = content.lstrip
      return :json if stripped.start_with?("{", "[")
      return :xml if xml_supported? && stripped.start_with?("<")

      :csv
    end

    def parse
      case @format
      when :json then parse_json
      when :xml then parse_xml
      else parse_csv
      end
    end

    def parse_json
      parsed = JSON.parse(content)
      parsed = parsed[json_root_key] if json_root_key && parsed.is_a?(Hash) && parsed.key?(json_root_key)
      Array(parsed).map { |row| row.is_a?(Hash) ? row : {} }
    rescue JSON::ParserError
      []
    end

    def parse_csv
      CSV.parse(content, headers: true).map(&:to_h)
    rescue CSV::MalformedCSVError
      []
    end

    def parse_xml
      doc = REXML::Document.new(content)
      doc.elements.to_a(xml_row_xpath).map do |element|
        element.attributes.each_attribute.to_h { |attr| [ attr.name, attr.value ] }
               .merge(element.elements.to_a.to_h { |child| [ child.name, child.text.to_s.strip ] })
      end
    rescue REXML::ParseException
      []
    end

    # Validation + small helpers

    # Base validation: required columns plus the subclass rules
    def validate_row(row, line)
      missing = missing_required_columns(row)
      errors = missing.any? ? [ "row #{line}: missing required column(s) #{missing.join(', ')}" ] : []
      errors + row_errors(row, line)
    end

    def missing_required_columns(row)
      required_columns.reject { |column| row[column].to_s.strip.present? }
    end

    def normalise_rows(parsed)
      parsed.map { |row| row.transform_keys(&:to_s) }
    end

    def failure_result(errors, rows = [], conflict_rows: [])
      Result.new(errors: errors, rows: rows, conflict_rows: conflict_rows)
    end

    def record_message(error)
      "#{error.record.class.name}: #{error.record.errors.full_messages.join(', ')}"
    end
  end
end
