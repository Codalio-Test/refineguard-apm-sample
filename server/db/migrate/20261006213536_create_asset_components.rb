# frozen_string_literal: true

class CreateAssetComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :asset_components do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.string :component_name
      t.string :component_type, null: true
      t.string :position, null: true
      t.string :bearing_model, null: true
      t.string :seal_type, null: true
      t.string :health_state, null: true, default: "Normal"
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
