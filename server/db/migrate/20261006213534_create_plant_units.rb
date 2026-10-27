# frozen_string_literal: true

class CreatePlantUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :plant_units do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :unit_code
      t.string :unit_name
      t.string :unit_type, null: true
      t.string :refinery_area, null: true
      t.text :description, null: true
      t.float :throughput_target_bpd, null: true
      t.float :rate_percent, null: true
      t.float :exposure_usd_per_day, null: true
      t.text :derate_recommendation, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
