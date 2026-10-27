# frozen_string_literal: true

class CreateBaselineWindows < ActiveRecord::Migration[8.0]
  def change
    create_table :baseline_windows do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.references :model_baseline, foreign_key: true, null: true
      t.string :label
      t.datetime :window_start
      t.datetime :window_end
      t.float :load_percent, null: true
      t.float :completeness_percent, null: true
      t.boolean :selected, null: true
      t.boolean :eligible, null: true, default: true

      t.timestamps
    end
  end
end
