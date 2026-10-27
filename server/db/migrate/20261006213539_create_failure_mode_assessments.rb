# frozen_string_literal: true

class CreateFailureModeAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :failure_mode_assessments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, foreign_key: true
      t.references :diagnostic_incident, foreign_key: true, null: true
      t.references :failure_mode, foreign_key: true, null: true
      t.float :probability
      t.float :confidence_low, null: true
      t.float :confidence_high, null: true
      t.string :marker_label, null: true
      t.float :expected_hz, null: true
      t.float :observed_hz, null: true
      t.float :amplitude, null: true
      t.float :match_score, null: true
      t.references :assigned_to, foreign_key: { to_table: :users }, null: true
      t.datetime :assessed_at
      t.references :assessed_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end
  end
end
