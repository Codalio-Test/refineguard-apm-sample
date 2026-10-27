# frozen_string_literal: true

class CreateAssetHealthIndices < ActiveRecord::Migration[8.0]
  def change
    create_table :asset_health_indices do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.datetime :calculated_at
      t.float :health_score
      t.float :health_delta, null: true
      t.float :anomaly_confidence, null: true
      t.string :health_state, null: true, default: "Normal"
      t.json :contributing_factors_json, null: true
      t.json :envelope_checks_json, null: true
      t.float :reconstruction_error, null: true
      t.float :threshold_p99, null: true
      t.integer :consecutive_breach_intervals, null: true, default: 0
      t.string :iso_severity_category, null: true

      t.timestamps
    end
  end
end
