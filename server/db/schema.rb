# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code
# It's strongly recommended that you check this file into your version control system

ActiveRecord::Schema[8.1].define(version: 2026_10_06_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # A dedicated sequence for CMMS external work-order numbers. Rails does not
  # dump standalone sequences, so it is declared explicitly here so the
  # `db:schema:load` path (which the test suite uses) creates it too
  execute "CREATE SEQUENCE IF NOT EXISTS cmms_work_order_number_seq START WITH 1"

  create_table "asset_components", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.string "component_name"
    t.string "component_type"
    t.string "position"
    t.string "bearing_model"
    t.string "seal_type"
    t.string "health_state", default: "Normal"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_asset_components_on_asset_id"
    t.index ["discarded_at"], name: "index_asset_components_on_discarded_at"
    t.index ["organization_id"], name: "index_asset_components_on_organization_id"
  end

  create_table "asset_health_indices", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.datetime "calculated_at"
    t.float "health_score"
    t.float "health_delta"
    t.float "anomaly_confidence"
    t.string "health_state", default: "Normal"
    t.json "contributing_factors_json"
    t.json "envelope_checks_json"
    t.float "reconstruction_error"
    t.float "threshold_p99"
    t.integer "consecutive_breach_intervals", default: 0
    t.string "iso_severity_category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_asset_health_indices_on_asset_id"
    t.index ["organization_id"], name: "index_asset_health_indices_on_organization_id"
  end

  create_table "assets", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "plant_unit_id"
    t.bigint "parent_asset_id"
    t.string "asset_tag"
    t.string "asset_name"
    t.string "equipment_class"
    t.string "equipment_type"
    t.string "driver_type"
    t.string "criticality_class"
    t.string "manufacturer"
    t.date "commissioned_on"
    t.float "design_speed_rpm"
    t.float "rated_rpm"
    t.float "rated_flow_m3h"
    t.float "max_bearing_temp_c"
    t.string "bearing_type"
    t.string "bearing_de_model"
    t.string "bearing_nde_model"
    t.string "seal_plan"
    t.string "operating_status", default: "Running"
    t.string "health_state", default: "Normal"
    t.float "health_index"
    t.float "health_index_delta"
    t.float "rms_velocity_mms"
    t.float "rms_velocity_delta_pct"
    t.float "bearing_temp_c"
    t.float "bearing_temp_delta_c"
    t.float "motor_current_a"
    t.float "estimated_rul_days"
    t.string "estimated_rul_window"
    t.datetime "last_sample_at"
    t.float "data_completeness_pct"
    t.string "hierarchy_path"
    t.boolean "monitored", default: true
    t.datetime "last_tag_validation_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_assets_on_discarded_at"
    t.index ["organization_id"], name: "index_assets_on_organization_id"
    t.index ["parent_asset_id"], name: "index_assets_on_parent_asset_id"
    t.index ["plant_unit_id"], name: "index_assets_on_plant_unit_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.json "old_values"
    t.json "new_values"
    t.bigint "user_id"
    t.string "user_type"
    t.string "ip_address"
    t.string "user_agent"
    t.bigint "organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "baseline_windows", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.bigint "model_baseline_id"
    t.string "label"
    t.datetime "window_start"
    t.datetime "window_end"
    t.float "load_percent"
    t.float "completeness_percent"
    t.boolean "selected"
    t.boolean "eligible", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_baseline_windows_on_asset_id"
    t.index ["model_baseline_id"], name: "index_baseline_windows_on_model_baseline_id"
    t.index ["organization_id"], name: "index_baseline_windows_on_organization_id"
  end

  create_table "cmms_work_orders", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "prescriptive_advisory_id"
    t.bigint "user_id"
    t.string "cmms_type"
    t.string "external_order_number"
    t.string "sync_status", default: "Pending Sync"
    t.string "priority"
    t.date "required_by"
    t.datetime "dispatched_at"
    t.datetime "confirmed_at"
    t.json "work_order_payload"
    t.json "material_reservations_json"
    t.text "error_message"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_cmms_work_orders_on_discarded_at"
    t.index ["organization_id"], name: "index_cmms_work_orders_on_organization_id"
    t.index ["prescriptive_advisory_id"], name: "index_cmms_work_orders_on_prescriptive_advisory_id"
    t.index ["user_id"], name: "index_cmms_work_orders_on_user_id"
  end

  create_table "diagnostic_incidents", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.bigint "failure_mode_id"
    t.string "incident_code"
    t.string "status", default: "Active"
    t.string "severity_level", default: "Low"
    t.string "health_state", default: "Normal"
    t.float "rul_days_estimate"
    t.float "rul_window_low_days"
    t.float "rul_window_high_days"
    t.float "rul_confidence_pct"
    t.float "pf_interval_days"
    t.string "regime"
    t.float "regime_confidence_pct"
    t.text "root_cause"
    t.text "evidence_summary"
    t.string "failure_mechanism"
    t.float "finding_confidence"
    t.string "finding_status", default: "Draft"
    t.bigint "signed_off_by_id"
    t.datetime "signed_off_at"
    t.bigint "acknowledged_by_id"
    t.datetime "acknowledged_at"
    t.datetime "detected_at"
    t.datetime "resolved_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_by_id"], name: "index_diagnostic_incidents_on_acknowledged_by_id"
    t.index ["asset_id"], name: "index_diagnostic_incidents_on_asset_id"
    t.index ["discarded_at"], name: "index_diagnostic_incidents_on_discarded_at"
    t.index ["failure_mode_id"], name: "index_diagnostic_incidents_on_failure_mode_id"
    t.index ["organization_id"], name: "index_diagnostic_incidents_on_organization_id"
    t.index ["signed_off_by_id"], name: "index_diagnostic_incidents_on_signed_off_by_id"
  end

  create_table "failure_mode_assessments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.bigint "diagnostic_incident_id"
    t.bigint "failure_mode_id"
    t.float "probability"
    t.float "confidence_low"
    t.float "confidence_high"
    t.string "marker_label"
    t.float "expected_hz"
    t.float "observed_hz"
    t.float "amplitude"
    t.float "match_score"
    t.bigint "assigned_to_id"
    t.datetime "assessed_at"
    t.bigint "assessed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessed_by_id"], name: "index_failure_mode_assessments_on_assessed_by_id"
    t.index ["asset_id"], name: "index_failure_mode_assessments_on_asset_id"
    t.index ["assigned_to_id"], name: "index_failure_mode_assessments_on_assigned_to_id"
    t.index ["diagnostic_incident_id"], name: "index_failure_mode_assessments_on_diagnostic_incident_id"
    t.index ["failure_mode_id"], name: "index_failure_mode_assessments_on_failure_mode_id"
    t.index ["organization_id"], name: "index_failure_mode_assessments_on_organization_id"
  end

  create_table "failure_modes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "iso_code"
    t.string "failure_name"
    t.string "equipment_category"
    t.float "severity_weight"
    t.string "detection_signature"
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_failure_modes_on_discarded_at"
    t.index ["organization_id"], name: "index_failure_modes_on_organization_id"
  end

  create_table "historian_connectors", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "connector_name"
    t.string "historian_type"
    t.string "protocol_type"
    t.string "endpoint_url"
    t.string "server_address"
    t.integer "port"
    t.integer "polling_interval_seconds", default: 5
    t.string "status", default: "Connected"
    t.datetime "last_heartbeat"
    t.integer "poll_latency_ms"
    t.bigint "buffer_depth"
    t.integer "backfill_queue"
    t.bigint "backfill_committed"
    t.bigint "backfill_total"
    t.boolean "ring_buffer_enabled", default: true
    t.integer "connection_timeout_ms", default: 3000
    t.string "credentials_ref"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_historian_connectors_on_discarded_at"
    t.index ["organization_id"], name: "index_historian_connectors_on_organization_id"
  end

  create_table "historian_tags", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.bigint "asset_component_id"
    t.bigint "historian_connector_id"
    t.string "historian_type"
    t.string "source_tag_name"
    t.string "tag_path"
    t.string "measurement_type"
    t.string "engineering_unit"
    t.integer "scan_rate_ms", default: 1000
    t.float "deadband_val"
    t.float "scan_frequency_hz"
    t.string "quality_status", default: "Good"
    t.float "last_value"
    t.datetime "last_validated_at"
    t.integer "stale_seconds"
    t.boolean "mapped"
    t.string "mapping_state", default: "Unmapped"
    t.boolean "compatible", default: true
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_component_id"], name: "index_historian_tags_on_asset_component_id"
    t.index ["asset_id"], name: "index_historian_tags_on_asset_id"
    t.index ["discarded_at"], name: "index_historian_tags_on_discarded_at"
    t.index ["historian_connector_id"], name: "index_historian_tags_on_historian_connector_id"
    t.index ["organization_id"], name: "index_historian_tags_on_organization_id"
  end

  create_table "model_baselines", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.string "model_version"
    t.string "algorithm_type"
    t.datetime "training_window_start"
    t.datetime "training_window_end"
    t.json "hyperparameters_json"
    t.json "accuracy_metrics_json"
    t.json "gates_json"
    t.string "status", default: "Candidate"
    t.string "training_status", default: "Idle"
    t.integer "training_progress", default: 0
    t.text "training_log"
    t.boolean "is_active"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.bigint "parent_model_baseline_id"
    t.datetime "promoted_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_model_baselines_on_approved_by_id"
    t.index ["asset_id"], name: "index_model_baselines_on_asset_id"
    t.index ["discarded_at"], name: "index_model_baselines_on_discarded_at"
    t.index ["organization_id"], name: "index_model_baselines_on_organization_id"
    t.index ["parent_model_baseline_id"], name: "index_model_baselines_on_parent_model_baseline_id"
  end

  create_table "org_role_permissions", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "role_id", null: false
    t.json "permissions", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "role_id"], name: "index_org_role_permissions_on_org_role", unique: true
    t.index ["organization_id"], name: "index_org_role_permissions_on_organization_id"
    t.index ["role_id"], name: "index_org_role_permissions_on_role_id"
  end

  create_table "organization_invitations", force: :cascade do |t|
    t.bigint "organization_id"
    t.bigint "role_id"
    t.bigint "invited_by"
    t.string "email", null: false
    t.string "token", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at"
    t.datetime "accepted_at"
    t.string "route_group"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email", "status"], name: "idx_on_organization_id_email_status_74b977d36e"
    t.index ["token"], name: "index_organization_invitations_on_token", unique: true
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "plant_units", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "unit_code"
    t.string "unit_name"
    t.string "unit_type"
    t.string "refinery_area"
    t.text "description"
    t.float "throughput_target_bpd"
    t.float "rate_percent"
    t.decimal "exposure_usd_per_day", precision: 15, scale: 2
    t.text "derate_recommendation"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_plant_units_on_discarded_at"
    t.index ["organization_id"], name: "index_plant_units_on_organization_id"
  end

  create_table "prescriptive_advisories", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "diagnostic_incident_id"
    t.string "advisory_code"
    t.text "recommended_action"
    t.json "action_steps_json"
    t.float "throttle_percentage"
    t.json "parts_required_json"
    t.string "warehouse_status"
    t.string "warehouse_bin"
    t.integer "parts_lead_time_days"
    t.string "urgency", default: "Routine"
    t.string "status", default: "Ready for Dispatch"
    t.integer "due_within_days"
    t.bigint "standby_asset_id"
    t.boolean "standby_ready"
    t.json "standby_checks_json"
    t.bigint "derate_approved_by_id"
    t.datetime "derate_approved_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["derate_approved_by_id"], name: "index_prescriptive_advisories_on_derate_approved_by_id"
    t.index ["diagnostic_incident_id"], name: "index_prescriptive_advisories_on_diagnostic_incident_id"
    t.index ["discarded_at"], name: "index_prescriptive_advisories_on_discarded_at"
    t.index ["organization_id"], name: "index_prescriptive_advisories_on_organization_id"
    t.index ["standby_asset_id"], name: "index_prescriptive_advisories_on_standby_asset_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "security_audit_events", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id"
    t.string "actor_name"
    t.string "actor_role"
    t.string "action_type"
    t.string "entity_affected"
    t.string "source_host"
    t.string "severity", default: "info"
    t.string "result", default: "Success"
    t.datetime "recorded_at"
    t.string "tamper_proof_hash"
    t.string "previous_hash"
    t.json "details_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_security_audit_events_on_organization_id"
    t.index ["user_id"], name: "index_security_audit_events_on_user_id"
  end

  create_table "shift_log_entries", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "plant_unit_id"
    t.bigint "asset_id"
    t.bigint "author_id"
    t.bigint "acknowledged_by_id"
    t.datetime "occurred_at"
    t.string "shift_label"
    t.string "event_type"
    t.string "severity", default: "info"
    t.text "message"
    t.text "unit_status"
    t.text "open_risks"
    t.text "outstanding_actions"
    t.json "procedure_steps_json"
    t.integer "steps_completed", default: 0
    t.integer "steps_total", default: 0
    t.boolean "incoming_ack"
    t.datetime "handover_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_by_id"], name: "index_shift_log_entries_on_acknowledged_by_id"
    t.index ["asset_id"], name: "index_shift_log_entries_on_asset_id"
    t.index ["author_id"], name: "index_shift_log_entries_on_author_id"
    t.index ["organization_id"], name: "index_shift_log_entries_on_organization_id"
    t.index ["plant_unit_id"], name: "index_shift_log_entries_on_plant_unit_id"
  end

  create_table "spectrum_snapshots", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id"
    t.bigint "historian_tag_id"
    t.datetime "captured_at"
    t.string "channel"
    t.bigint "line_resolution"
    t.float "sample_rate_hz"
    t.float "rms_velocity"
    t.float "running_speed_hz"
    t.float "cursor_hz"
    t.float "cursor_amplitude"
    t.float "cursor_order"
    t.float "delta_baseline"
    t.json "spectrum_json"
    t.json "harmonics_json"
    t.json "bearing_markers_json"
    t.json "waterfall_json"
    t.json "orbit_json"
    t.integer "waterfall_horizon_days"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_spectrum_snapshots_on_asset_id"
    t.index ["historian_tag_id"], name: "index_spectrum_snapshots_on_historian_tag_id"
    t.index ["organization_id"], name: "index_spectrum_snapshots_on_organization_id"
  end

  create_table "telemetry_records", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "historian_tag_id"
    t.datetime "recorded_at"
    t.float "recorded_value"
    t.string "data_quality_flag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["historian_tag_id"], name: "index_telemetry_records_on_historian_tag_id"
    t.index ["organization_id"], name: "index_telemetry_records_on_organization_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id"
    t.bigint "role_id", null: false
    t.string "route_group"
    t.json "permissions", default: []
    t.json "granted_permissions", default: []
    t.json "denied_permissions", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, COALESCE(organization_id, (0)::bigint), role_id, COALESCE(route_group, ''::character varying)", name: "index_user_roles_on_user_org_role_group", unique: true
    t.index ["organization_id"], name: "index_user_roles_on_organization_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_token"
    t.string "first_name"
    t.string "last_name"
    t.boolean "approved", default: true, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "failed_login_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "token_last_used_at"
    t.string "hardware_token_secret"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "asset_components", "assets"
  add_foreign_key "asset_components", "organizations"
  add_foreign_key "asset_health_indices", "assets"
  add_foreign_key "asset_health_indices", "organizations"
  add_foreign_key "assets", "assets", column: "parent_asset_id"
  add_foreign_key "assets", "organizations"
  add_foreign_key "assets", "plant_units"
  add_foreign_key "baseline_windows", "assets"
  add_foreign_key "baseline_windows", "model_baselines"
  add_foreign_key "baseline_windows", "organizations"
  add_foreign_key "cmms_work_orders", "organizations"
  add_foreign_key "cmms_work_orders", "prescriptive_advisories"
  add_foreign_key "cmms_work_orders", "users"
  add_foreign_key "diagnostic_incidents", "assets"
  add_foreign_key "diagnostic_incidents", "failure_modes"
  add_foreign_key "diagnostic_incidents", "organizations"
  add_foreign_key "diagnostic_incidents", "users", column: "acknowledged_by_id"
  add_foreign_key "diagnostic_incidents", "users", column: "signed_off_by_id"
  add_foreign_key "failure_mode_assessments", "assets"
  add_foreign_key "failure_mode_assessments", "diagnostic_incidents"
  add_foreign_key "failure_mode_assessments", "failure_modes"
  add_foreign_key "failure_mode_assessments", "organizations"
  add_foreign_key "failure_mode_assessments", "users", column: "assessed_by_id"
  add_foreign_key "failure_mode_assessments", "users", column: "assigned_to_id"
  add_foreign_key "failure_modes", "organizations"
  add_foreign_key "historian_connectors", "organizations"
  add_foreign_key "historian_tags", "asset_components"
  add_foreign_key "historian_tags", "assets"
  add_foreign_key "historian_tags", "historian_connectors"
  add_foreign_key "historian_tags", "organizations"
  add_foreign_key "model_baselines", "assets"
  add_foreign_key "model_baselines", "model_baselines", column: "parent_model_baseline_id"
  add_foreign_key "model_baselines", "organizations"
  add_foreign_key "model_baselines", "users", column: "approved_by_id"
  add_foreign_key "org_role_permissions", "organizations"
  add_foreign_key "org_role_permissions", "roles"
  add_foreign_key "plant_units", "organizations"
  add_foreign_key "prescriptive_advisories", "assets", column: "standby_asset_id"
  add_foreign_key "prescriptive_advisories", "diagnostic_incidents"
  add_foreign_key "prescriptive_advisories", "organizations"
  add_foreign_key "prescriptive_advisories", "users", column: "derate_approved_by_id"
  add_foreign_key "security_audit_events", "organizations"
  add_foreign_key "security_audit_events", "users"
  add_foreign_key "shift_log_entries", "assets"
  add_foreign_key "shift_log_entries", "organizations"
  add_foreign_key "shift_log_entries", "plant_units"
  add_foreign_key "shift_log_entries", "users", column: "acknowledged_by_id"
  add_foreign_key "shift_log_entries", "users", column: "author_id"
  add_foreign_key "spectrum_snapshots", "assets"
  add_foreign_key "spectrum_snapshots", "historian_tags"
  add_foreign_key "spectrum_snapshots", "organizations"
  add_foreign_key "telemetry_records", "historian_tags"
  add_foreign_key "telemetry_records", "organizations"
  add_foreign_key "user_roles", "organizations"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
end
