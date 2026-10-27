# frozen_string_literal: true

class CreatePrescriptiveAdvisories < ActiveRecord::Migration[8.0]
  def change
    create_table :prescriptive_advisories do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :diagnostic_incident, foreign_key: true
      t.string :advisory_code, null: true
      t.text :recommended_action, null: true
      t.json :action_steps_json, null: true
      t.float :throttle_percentage, null: true
      t.json :parts_required_json, null: true
      t.string :warehouse_status, null: true
      t.string :warehouse_bin, null: true
      t.integer :parts_lead_time_days, null: true
      t.string :urgency, null: true, default: "Routine"
      t.string :status, default: "Ready for Dispatch"
      t.integer :due_within_days, null: true
      t.references :standby_asset, foreign_key: { to_table: :assets }, null: true
      t.boolean :standby_ready, null: true
      t.json :standby_checks_json, null: true
      t.references :derate_approved_by, foreign_key: { to_table: :users }, null: true
      t.datetime :derate_approved_at, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
