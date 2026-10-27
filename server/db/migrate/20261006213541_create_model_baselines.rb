# frozen_string_literal: true

class CreateModelBaselines < ActiveRecord::Migration[8.0]
  def change
    create_table :model_baselines do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.string :model_version
      t.string :algorithm_type
      t.datetime :training_window_start, null: true
      t.datetime :training_window_end, null: true
      t.json :hyperparameters_json, null: true
      t.json :accuracy_metrics_json, null: true
      t.json :gates_json, null: true
      t.string :status, default: "Candidate"
      t.string :training_status, null: true, default: "Idle"
      t.integer :training_progress, null: true, default: 0
      t.text :training_log, null: true
      t.boolean :is_active, null: true
      t.references :approved_by, foreign_key: { to_table: :users }, null: true
      t.datetime :approved_at, null: true
      t.references :parent_model_baseline, foreign_key: { to_table: :model_baselines }, null: true
      t.datetime :promoted_at, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
