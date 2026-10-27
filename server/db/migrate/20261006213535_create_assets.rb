# frozen_string_literal: true

class CreateAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :assets do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :plant_unit, foreign_key: true, null: true
      t.references :parent_asset, foreign_key: { to_table: :assets }, null: true
      t.string :asset_tag
      t.string :asset_name
      t.string :equipment_class, null: true
      t.string :equipment_type, null: true
      t.string :driver_type, null: true
      t.string :criticality_class, null: true
      t.string :manufacturer, null: true
      t.date :commissioned_on, null: true
      t.float :design_speed_rpm, null: true
      t.float :rated_rpm, null: true
      t.float :rated_flow_m3h, null: true
      t.float :max_bearing_temp_c, null: true
      t.string :bearing_type, null: true
      t.string :bearing_de_model, null: true
      t.string :bearing_nde_model, null: true
      t.string :seal_plan, null: true
      t.string :operating_status, null: true, default: "Running"
      t.string :health_state, null: true, default: "Normal"
      t.float :health_index, null: true
      t.float :health_index_delta, null: true
      t.float :rms_velocity_mms, null: true
      t.float :rms_velocity_delta_pct, null: true
      t.float :bearing_temp_c, null: true
      t.float :bearing_temp_delta_c, null: true
      t.float :motor_current_a, null: true
      t.float :estimated_rul_days, null: true
      t.string :estimated_rul_window, null: true
      t.datetime :last_sample_at, null: true
      t.float :data_completeness_pct, null: true
      t.string :hierarchy_path, null: true
      t.boolean :monitored, null: true, default: true
      t.datetime :last_tag_validation_at, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
