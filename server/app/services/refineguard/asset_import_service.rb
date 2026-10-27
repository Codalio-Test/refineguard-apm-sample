# frozen_string_literal: true

module Refineguard
  # Asset hierarchy import (CSV / JSON / XML)
  # Required taxonomy columns: asset_tag, unit_id, equipment_class
  # driver_type, bearing_de_model, bearing_nde_model, rated_rpm. A duplicate
  # asset tag or an invalid parent node rejects the WHOLE file and highlights the
  # exact conflicting rows (line numbers included)
  class AssetImportService < BaseImporter
    REQUIRED_COLUMNS = %w[asset_tag unit_id equipment_class driver_type
                          bearing_de_model bearing_nde_model rated_rpm].freeze
    EQUIPMENT_CLASSES = [ "API 610 Centrifugal Pump", "API 617 Centrifugal Compressor",
                         "Centrifugal Pump", "Centrifugal Compressor",
                         "Steam Turbine", "Electric Motor" ].freeze

    def call
      parsed = parse
      return failure_result([ "Import file is empty" ]) if parsed.empty?

      rows = normalise_rows(parsed)
      errors, conflict_rows = validate_rows(rows)
      return failure_result(errors, rows, conflict_rows: conflict_rows) if errors.any?

      imported = persist_rows(rows)
      Result.new(imported: imported, errors: [], conflict_rows: [], rows: rows)
    rescue ActiveRecord::RecordInvalid => e
      failure_result([ record_message(e) ])
    end

    private

    def required_columns
      REQUIRED_COLUMNS
    end

    def json_root_key
      "assets"
    end

    def xml_supported?
      true
    end

    # Field-level rules for one row, on top of the required-column check
    def row_errors(row, line)
      errors = []
      errors.concat(equipment_class_errors(row, line))
      errors.concat(rpm_errors(row, line))
      errors.concat(unit_errors(row, line))
      errors
    end

    # Whole-file validation

    def validate_rows(rows)
      seen_tags = {}
      errors = []
      conflict_rows = []

      rows.each_with_index do |row, index|
        line = index + 1
        row_errors = validate_row(row, line) + duplicate_errors(row, line, seen_tags)
        errors.concat(row_errors)
        conflict_rows << line if row_errors.any?
      end

      parent = parent_errors(rows, seen_tags)
      [ errors + parent[:errors], (conflict_rows + parent[:conflict_rows]).uniq.sort ]
    end

    def duplicate_errors(row, line, seen_tags)
      tag = row["asset_tag"].to_s.strip
      return [] if tag.blank?

      errors = duplicate_in_file_errors(tag, line, seen_tags)
      if organization.assets.with_discarded.exists?(asset_tag: tag)
        errors << "row #{line}: asset_tag '#{tag}' already exists in this organization"
      end
      errors
    end

    def duplicate_in_file_errors(tag, line, seen_tags)
      return [ "row #{line}: duplicate asset_tag '#{tag}' (also on row #{seen_tags[tag]})" ] if seen_tags.key?(tag)

      seen_tags[tag] = line
      []
    end

    # Parent integrity is validated across the whole file before any write
    def parent_errors(rows, seen_tags)
      errors = []
      conflict_rows = []

      rows.each_with_index do |row, index|
        parent_tag = row["parent_asset_tag"].to_s.strip
        next if parent_tag.blank? || known_parent?(parent_tag, seen_tags)

        errors << "row #{index + 1}: parent asset '#{parent_tag}' is not in the file or the hierarchy"
        conflict_rows << index + 1
      end

      { errors: errors, conflict_rows: conflict_rows }
    end

    def known_parent?(parent_tag, seen_tags)
      seen_tags.key?(parent_tag) || organization.assets.with_discarded.exists?(asset_tag: parent_tag)
    end

    # Persistence + field mapping

    def persist_rows(rows)
      imported = 0
      Asset.transaction do
        rows.each do |row|
          asset = organization.assets.with_discarded
                                  .find_or_initialize_by(asset_tag: row["asset_tag"].to_s.strip)
          asset.assign_attributes(attributes_from(row))
          asset.save!
          imported += 1
        end
      end
      imported
    end

    def equipment_class_errors(row, line)
      klass = row["equipment_class"].to_s.strip
      return [] if klass.blank? || EQUIPMENT_CLASSES.include?(klass)

      [ "row #{line}: equipment_class must be one of #{EQUIPMENT_CLASSES.join(' | ')}" ]
    end

    def rpm_errors(row, line)
      rpm = row["rated_rpm"].to_s.strip
      return [] if rpm.blank?

      Float(rpm)
      []
    rescue ArgumentError, TypeError
      [ "row #{line}: rated_rpm must be numeric" ]
    end

    def unit_errors(row, line)
      unit_ref = row["unit_id"].to_s.strip
      return [] if unit_ref.blank? || resolve_unit(unit_ref)

      [ "row #{line}: unit_id '#{unit_ref}' does not match a plant unit in this organization" ]
    end

    def resolve_unit(reference)
      scope = PlantUnit.where(organization: organization)
      return scope.find_by(id: reference) if reference.match?(/\A\d+\z/)

      scope.find_by(unit_code: reference)
    end

    def attributes_from(row)
      unit = resolve_unit(row["unit_id"].to_s.strip)
      parent_tag = row["parent_asset_tag"].to_s.strip

      {
        plant_unit_id: unit&.id,
        parent_asset_id: parent_tag.presence && parent_asset_id(parent_tag),
        asset_name: (row["asset_name"].presence || row["asset_tag"]).to_s.strip,
        equipment_class: row["equipment_class"].to_s.strip,
        equipment_type: row["equipment_type"].presence,
        driver_type: row["driver_type"].to_s.strip,
        bearing_de_model: row["bearing_de_model"].to_s.strip,
        bearing_nde_model: row["bearing_nde_model"].to_s.strip,
        rated_rpm: row["rated_rpm"].presence && Float(row["rated_rpm"]),
        criticality_class: row["criticality_class"].presence,
        manufacturer: row["manufacturer"].presence,
        seal_plan: row["seal_plan"].presence,
        hierarchy_path: row["hierarchy_path"].presence
      }
    end

    def parent_asset_id(parent_tag)
      organization.assets.with_discarded.find_by(asset_tag: parent_tag)&.id
    end
  end
end
