# frozen_string_literal: true

class CreateSpectrumSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :spectrum_snapshots do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.references :historian_tag, foreign_key: true, null: true
      t.datetime :captured_at
      t.string :channel
      t.bigint :line_resolution, null: true
      t.float :sample_rate_hz, null: true
      t.float :rms_velocity, null: true
      t.float :running_speed_hz, null: true
      t.float :cursor_hz, null: true
      t.float :cursor_amplitude, null: true
      t.float :cursor_order, null: true
      t.float :delta_baseline, null: true
      t.json :spectrum_json, null: true
      t.json :harmonics_json, null: true
      t.json :bearing_markers_json, null: true
      t.json :waterfall_json, null: true
      t.json :orbit_json, null: true
      t.integer :waterfall_horizon_days, null: true

      t.timestamps
    end
  end
end
