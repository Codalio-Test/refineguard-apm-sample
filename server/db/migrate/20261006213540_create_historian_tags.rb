# frozen_string_literal: true

class CreateHistorianTags < ActiveRecord::Migration[8.0]
  def change
    create_table :historian_tags do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true, null: true
      t.references :asset_component, foreign_key: true, null: true
      t.references :historian_connector, foreign_key: true, null: true
      t.string :historian_type
      t.string :source_tag_name
      t.string :tag_path
      t.string :measurement_type, null: true
      t.string :engineering_unit, null: true
      t.integer :scan_rate_ms, null: true, default: 1000
      t.float :deadband_val, null: true
      t.float :scan_frequency_hz, null: true
      t.string :quality_status, null: true, default: "Good"
      t.float :last_value, null: true
      t.datetime :last_validated_at, null: true
      t.integer :stale_seconds, null: true
      t.boolean :mapped, null: true
      t.string :mapping_state, null: true, default: "Unmapped"
      t.boolean :compatible, null: true, default: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
