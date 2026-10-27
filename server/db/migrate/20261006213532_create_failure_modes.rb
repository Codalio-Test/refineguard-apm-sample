# frozen_string_literal: true

class CreateFailureModes < ActiveRecord::Migration[8.0]
  def change
    create_table :failure_modes do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :iso_code
      t.string :failure_name
      t.string :equipment_category, null: true
      t.float :severity_weight, null: true
      t.string :detection_signature, null: true
      t.text :description, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
