# frozen_string_literal: true

# Store plant-unit exposure as exact money, and give the CMMS bridge a real
# database sequence for external work-order numbers instead of the previous
# `id * 7 + 2341` arithmetic
class AddDispatchSequenceAndDecimalExposure < ActiveRecord::Migration[8.1]
  def up
    # A dedicated sequence so the external order number is allocated by the
    # database (concurrency-safe, monotonic) rather than derived from the row id
    execute 'CREATE SEQUENCE IF NOT EXISTS cmms_work_order_number_seq START WITH 1'

    change_column :plant_units, :exposure_usd_per_day, :decimal, precision: 15, scale: 2
  end

  def down
    execute 'DROP SEQUENCE IF EXISTS cmms_work_order_number_seq'

    change_column :plant_units, :exposure_usd_per_day, :float
  end
end
