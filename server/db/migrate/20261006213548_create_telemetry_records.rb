# frozen_string_literal: true

class CreateTelemetryRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :telemetry_records do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :historian_tag, foreign_key: true
      t.datetime :recorded_at
      t.float :recorded_value
      t.string :data_quality_flag, null: true

      t.timestamps
    end
  end
end
