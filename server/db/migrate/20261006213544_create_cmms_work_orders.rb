# frozen_string_literal: true

class CreateCmmsWorkOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :cmms_work_orders do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :prescriptive_advisory, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.string :cmms_type
      t.string :external_order_number, null: true
      t.string :sync_status, default: "Pending Sync"
      t.string :priority, null: true
      t.date :required_by, null: true
      t.datetime :dispatched_at, null: true
      t.datetime :confirmed_at, null: true
      t.json :work_order_payload, null: true
      t.json :material_reservations_json, null: true
      t.text :error_message, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
