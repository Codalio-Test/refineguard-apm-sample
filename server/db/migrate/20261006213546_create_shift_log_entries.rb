# frozen_string_literal: true

class CreateShiftLogEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :shift_log_entries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :plant_unit, foreign_key: true, null: true
      t.references :asset, foreign_key: true, null: true
      t.references :author, foreign_key: { to_table: :users }, null: true
      t.references :acknowledged_by, foreign_key: { to_table: :users }, null: true
      t.datetime :occurred_at
      t.string :shift_label, null: true
      t.string :event_type, null: true
      t.string :severity, null: true, default: "info"
      t.text :message, null: true
      t.text :unit_status, null: true
      t.text :open_risks, null: true
      t.text :outstanding_actions, null: true
      t.json :procedure_steps_json, null: true
      t.integer :steps_completed, null: true, default: 0
      t.integer :steps_total, null: true, default: 0
      t.boolean :incoming_ack, null: true
      t.datetime :handover_completed_at, null: true

      t.timestamps
    end
  end
end
