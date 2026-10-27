# frozen_string_literal: true

module Refineguard
  # Historian tag mapping import (CSV and JSON)
  # Every row must carry a valid `historian_type` (OSIsoft_PI | Honeywell_PHD)
  # `source_tag_name`, `engineering_unit`, `scan_rate_ms` and `deadband_val`
  # Invalid rows are reported individually and nothing is written when any row
  # fails, so a partial import can never half-configure the ingestion layer
  class HistorianTagImporter < BaseImporter
    REQUIRED_COLUMNS = %w[historian_type source_tag_name engineering_unit scan_rate_ms deadband_val].freeze
    OPTIONAL_COLUMNS = %w[tag_path measurement_type asset_id asset_component_id
                          historian_connector_id scan_frequency_hz deadband_val mapped
                          mapping_state].freeze
    ALLOWED_TYPES = HistorianTag::HISTORIAN_TYPES

    def call
      parsed = parse
      return failure_result([ "Import file is empty" ]) if parsed.empty?

      errors, prepared = partition_rows(normalise_rows(parsed))
      return failure_result(errors, prepared) if errors.any?

      created = persist_rows(prepared)
      Result.new(created: created, errors: [], rows: prepared)
    rescue ActiveRecord::RecordInvalid => e
      failure_result([ record_message(e) ])
    end

    private

    def required_columns
      REQUIRED_COLUMNS
    end

    def json_root_key
      "tags"
    end

    def row_errors(row, line)
      errors = []
      errors.concat(historian_type_errors(row, line))
      errors.concat(scan_rate_errors(row, line))
      errors.concat(deadband_errors(row, line))
      errors
    end

    def partition_rows(rows)
      errors = []
      prepared = []

      rows.each_with_index do |row, index|
        row_errors = validate_row(row, index + 1)
        errors.concat(row_errors)
        prepared << row if row_errors.empty?
      end

      [ errors, prepared ]
    end

    def persist_rows(rows)
      created = 0
      HistorianTag.transaction do
        rows.each do |row|
          tag = HistorianTag.find_or_initialize_by(
            organization: organization,
            tag_path: row["tag_path"].presence || default_tag_path(row)
          )
          tag.assign_attributes(attributes_from(row))
          tag.save!
          created += 1
        end
      end
      created
    end

    def historian_type_errors(row, line)
      value = row["historian_type"].to_s.strip
      return [] if value.blank? || ALLOWED_TYPES.include?(value)

      [ "row #{line}: historian_type must be one of #{ALLOWED_TYPES.join(' | ')}" ]
    end

    def scan_rate_errors(row, line)
      value = row["scan_rate_ms"].to_s.strip
      return [] if value.blank? || row["scan_rate_ms"].to_i.positive?

      [ "row #{line}: scan_rate_ms must be a positive integer" ]
    end

    def deadband_errors(row, line)
      value = row["deadband_val"].to_s.strip
      return [] if value.blank? || numeric?(value)

      [ "row #{line}: deadband_val must be numeric" ]
    end

    def numeric?(value)
      Float(value)
      true
    rescue ArgumentError, TypeError
      false
    end

    def default_tag_path(row)
      "#{row['historian_type']}:#{row['source_tag_name']}"
    end

    def attributes_from(row)
      {
        historian_type: row["historian_type"].to_s.strip,
        source_tag_name: row["source_tag_name"].to_s.strip,
        tag_path: row["tag_path"].presence || default_tag_path(row),
        measurement_type: row["measurement_type"].presence,
        engineering_unit: row["engineering_unit"].presence,
        scan_rate_ms: row["scan_rate_ms"].to_i,
        deadband_val: row["deadband_val"].presence && Float(row["deadband_val"]),
        scan_frequency_hz: row["scan_frequency_hz"].presence && Float(row["scan_frequency_hz"]),
        asset_id: row["asset_id"].presence,
        asset_component_id: row["asset_component_id"].presence,
        historian_connector_id: row["historian_connector_id"].presence,
        mapped: row["mapped"].to_s.casecmp("true").zero?,
        mapping_state: row["mapping_state"].presence || (row["asset_id"].present? ? "Mapped" : "Unmapped")
      }
    end
  end
end
