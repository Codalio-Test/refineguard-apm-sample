# frozen_string_literal: true

class CreateDiagnosticIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :diagnostic_incidents do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.references :failure_mode, foreign_key: true, null: true
      t.string :incident_code, null: true
      t.string :status, default: "Active"
      t.string :severity_level, null: true, default: "Low"
      t.string :health_state, null: true, default: "Normal"
      t.float :rul_days_estimate, null: true
      t.float :rul_window_low_days, null: true
      t.float :rul_window_high_days, null: true
      t.float :rul_confidence_pct, null: true
      t.float :pf_interval_days, null: true
      t.string :regime, null: true
      t.float :regime_confidence_pct, null: true
      t.text :root_cause, null: true
      t.text :evidence_summary, null: true
      t.string :failure_mechanism, null: true
      t.float :finding_confidence, null: true
      t.string :finding_status, null: true, default: "Draft"
      t.references :signed_off_by, foreign_key: { to_table: :users }, null: true
      t.datetime :signed_off_at, null: true
      t.references :acknowledged_by, foreign_key: { to_table: :users }, null: true
      t.datetime :acknowledged_at, null: true
      t.datetime :detected_at
      t.datetime :resolved_at, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
