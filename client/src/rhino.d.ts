/**
 * Generated model interfaces for the RefineGuard APM backend.
 *
 * This is the published frontend type-export artifact at the canonical path
 * `client/src/rhino.d.ts` (the location the host build-evidence contract
 * requires). `rails rhino:export_types` normally produces it by shelling out to
 * `openapi-typescript`; the air-gapped build environment has no npm registry
 * access, so it is maintained by hand from the registered Rhino models
 * (`server/app/models/*.rb`) and kept in sync with `server/.rhino/blueprints/`.
 *
 * `client/src/types/rhino.d.ts` is a thin re-export barrel so the existing
 * `@/types/rhino` imports keep resolving to this single source of truth.
 *
 * Every field is optional by design: Rhino policies control which fields each
 * role can actually see.
 */

export interface Asset {
  id?: string | number;
  record_id?: number;
  asset_tag?: string;
  asset_name?: string;
  name?: string;
  unit?: string;
  kind?: string;
  status?: string;
  severity?: string;
  equipment_class?: string;
  equipment_type?: string;
  driver_type?: string;
  criticality_class?: string;
  manufacturer?: string;
  commissioned_on?: string | null;
  plant_unit_id?: number | null;
  parent_asset_id?: number | null;
  hierarchy_path?: string | null;
  bearing_type?: string;
  bearing_de_model?: string;
  bearing_nde_model?: string;
  seal_plan?: string;
  rated_rpm?: number;
  design_speed_rpm?: number;
  rated_flow_m3h?: number;
  max_bearing_temp_c?: number;
  operating_status?: string;
  health_state?: string;
  health?: number;
  health_index?: number;
  health_index_delta?: number;
  iso_severity_category?: string | null;
  rms?: string;
  rms_velocity_mms?: number;
  rms_velocity_delta_pct?: number;
  temp?: string;
  bearing_temp_c?: number;
  bearing_temp_delta_c?: number;
  motor_current_a?: number;
  estimated_rul_days?: number;
  estimated_rul_window?: string;
  rul?: string;
  sample?: string;
  last_sample_at?: string;
  data_completeness_pct?: number;
  monitored?: boolean;
  last_tag_validation_at?: string;
  deleted_at?: string | null;
}

export interface PlantUnit {
  id?: number;
  unit_code?: string;
  name?: string;
  unit_name?: string;
  unit_type?: string;
  refinery_area?: string;
  description?: string;
  throughput_target_bpd?: number;
  rate_percent?: number;
  exposure_usd_per_day?: number;
  derate_recommendation?: string;
  assets_count?: number;
  deleted_at?: string | null;
}

export interface AssetComponent {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  component_name?: string;
  component_type?: string;
  position?: string;
  bearing_model?: string;
  seal_type?: string;
  health_state?: string;
  severity?: string;
  deleted_at?: string | null;
}

export interface FailureMode {
  id?: number;
  iso_code?: string;
  failure_name?: string;
  name?: string;
  code?: string;
  equipment_category?: string;
  severity_weight?: number;
  detection_signature?: string;
  description?: string;
  deleted_at?: string | null;
}

export interface FailureModeAssessment {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  diagnostic_incident_id?: number | null;
  failure_mode_id?: number | null;
  probability?: number;
  confidence_low?: number;
  confidence_high?: number;
  marker_label?: string;
  expected_hz?: number;
  observed_hz?: number;
  amplitude?: number;
  match_score?: number;
  assessed_at?: string;
  severity?: string;
  failure_mode_name?: string;
}

export interface HistorianConnector {
  id?: number;
  connector_name?: string;
  historian_type?: string;
  protocol_type?: string;
  endpoint_url?: string;
  endpoint?: string;
  server_address?: string;
  port?: number;
  polling_interval_seconds?: number;
  status?: string;
  severity?: string;
  last_heartbeat?: string;
  poll_latency_ms?: number;
  latency?: string;
  buffer_depth?: number;
  buffer?: string;
  backfill_queue?: number;
  backfill_committed?: number;
  backfill_total?: number;
  backfill_pending?: number;
  ring_buffer_enabled?: boolean;
  connection_timeout_ms?: number;
  deleted_at?: string | null;
}

export interface HistorianTag {
  id?: number;
  asset_id?: number | null;
  asset_tag?: string;
  asset_component_id?: number | null;
  component_name?: string;
  historian_connector_id?: number | null;
  historian_type?: string;
  source_tag_name?: string;
  tag_path?: string;
  measurement_type?: string;
  engineering_unit?: string;
  scan_rate_ms?: number;
  deadband_val?: number;
  scan_frequency_hz?: number;
  quality_status?: string;
  last_value?: number;
  last_validated_at?: string;
  stale_seconds?: number;
  stale?: boolean;
  healthy?: boolean;
  mapped?: boolean;
  mapping_state?: string;
  compatible?: boolean;
  severity?: string;
  deleted_at?: string | null;
}

export interface TelemetryRecord {
  id?: number;
  historian_tag_id?: number;
  tag_path?: string;
  asset_tag?: string;
  recorded_at?: string;
  recorded_value?: number;
  data_quality_flag?: string;
}

export interface AssetHealthIndex {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  calculated_at?: string;
  health_score?: number;
  health_delta?: number;
  anomaly_confidence?: number;
  health_state?: string;
  severity?: string;
  attribution?: Array<{
    label?: string;
    weight?: number;
    percent?: number;
    z_score?: number | null;
    status?: string | null;
  }>;
  envelope_checks?: Array<{
    label?: string;
    limit?: number;
    observed?: number;
    unit?: string;
    breached?: boolean;
  }>;
  contributing_factors_json?: Record<string, unknown>;
  reconstruction_error?: number;
  threshold_p99?: number;
  consecutive_breach_intervals?: number;
  iso_severity_category?: string;
}

export interface DiagnosticIncident {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  unit?: string;
  failure_mode_id?: number | null;
  incident_code?: string;
  status?: string;
  severity_level?: string;
  health_state?: string;
  severity?: string;
  rul_days_estimate?: number;
  rul_window_low_days?: number;
  rul_window_high_days?: number;
  rul_window?: string;
  rul_confidence_pct?: number;
  pf_interval_days?: number;
  regime?: string;
  regime_confidence_pct?: number;
  root_cause?: string;
  evidence_summary?: string;
  failure_mechanism?: string;
  finding?: string;
  finding_confidence?: number;
  finding_status?: string;
  signed_off_by_id?: number | null;
  signed_off_by_name?: string;
  signed_off_at?: string | null;
  acknowledged_by_id?: number | null;
  acknowledged_by_name?: string;
  acknowledged_at?: string | null;
  sync_status?: string;
  detected_at?: string;
  resolved_at?: string | null;
  deleted_at?: string | null;
}

export interface SpectrumSnapshot {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  historian_tag_id?: number | null;
  captured_at?: string;
  channel?: string;
  line_resolution?: number;
  sample_rate_hz?: number;
  rms_velocity?: number;
  running_speed_hz?: number;
  cursor_hz?: number;
  cursor_amplitude?: number;
  cursor_order?: number;
  delta_baseline?: number;
  spectrum?: Array<{ hz?: number; amplitude?: number }>;
  harmonics?: Array<{
    order?: number;
    expected_hz?: number;
    amplitude?: number;
    relative_amplitude?: number;
  }>;
  bearing_markers?: Array<{
    label?: string;
    order?: number;
    expected_hz?: number;
    observed_hz?: number;
    amplitude?: number;
    match_score?: number;
  }>;
  waterfall?: Array<{
    day_offset?: number;
    captured_at?: string;
    points?: Array<{ hz?: number; amplitude?: number }>;
  }>;
  orbit?: Array<{ angle_deg?: number; x_um?: number; y_um?: number; hz?: number }>;
  waterfall_horizon_days?: number;
  spectrum_json?: unknown;
  harmonics_json?: unknown;
  bearing_markers_json?: unknown;
  waterfall_json?: unknown;
  orbit_json?: unknown;
}

export interface ModelBaseline {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  model_version?: string;
  algorithm_type?: string;
  training_window_start?: string;
  training_window_end?: string;
  hyperparameters_json?: Record<string, unknown>;
  accuracy_metrics_json?: Record<string, number>;
  gates_json?: Record<string, boolean>;
  gates_satisfied?: boolean;
  status?: string;
  training_status?: string;
  training_progress?: number;
  training_log?: string;
  is_active?: boolean;
  approved_by_id?: number | null;
  approved_by_name?: string;
  approved_at?: string | null;
  parent_model_baseline_id?: number | null;
  promoted_at?: string | null;
  deleted_at?: string | null;
}

export interface BaselineWindow {
  id?: number;
  asset_id?: number;
  asset_tag?: string;
  model_baseline_id?: number | null;
  label?: string;
  summary?: string;
  window_start?: string;
  window_end?: string;
  load_percent?: number;
  completeness_percent?: number;
  selected?: boolean;
  eligible?: boolean;
}

export interface PrescriptiveAdvisory {
  id?: number;
  diagnostic_incident_id?: number;
  advisory_code?: string;
  asset_tag?: string;
  asset_id?: number;
  recommended_action?: string;
  recommendation?: string;
  action_steps_json?: string[];
  throttle_percentage?: number;
  parts_required_json?: Record<string, string[]>;
  warehouse_status?: string;
  warehouse_bin?: string;
  parts_lead_time_days?: number;
  urgency?: string;
  status?: string;
  due_within_days?: number;
  standby_asset_id?: number | null;
  standby_asset_tag?: string;
  standby_ready?: boolean | null;
  standby_checks_json?: Array<{ label?: string; passed?: boolean; detail?: string }>;
  derate_approved_by_id?: number | null;
  derate_approved_by_name?: string;
  derate_approved_at?: string | null;
  severity?: string;
  finding?: string;
  rul_window?: string;
  pf_interval_days?: number;
  regime?: string;
  regime_confidence_pct?: number;
  deleted_at?: string | null;
}

export interface CmmsWorkOrder {
  id?: number;
  prescriptive_advisory_id?: number;
  asset_tag?: string;
  user_id?: number | null;
  cmms_type?: string;
  external_order_number?: string;
  sync_status?: string;
  priority?: string;
  required_by?: string | null;
  dispatched_at?: string | null;
  confirmed_at?: string | null;
  work_order_payload?: Record<string, unknown>;
  material_reservations_json?: Array<Record<string, unknown>>;
  error_message?: string | null;
  severity?: string;
  deleted_at?: string | null;
}

export interface SecurityAuditEvent {
  id?: number;
  user_id?: number | null;
  actor_name?: string;
  actor?: string;
  actor_role?: string;
  role?: string;
  action_type?: string;
  entity_affected?: string;
  object?: string;
  source_host?: string;
  host?: string;
  severity?: string;
  result?: string;
  recorded_at?: string;
  timestamp?: string;
  tamper_proof_hash?: string;
  previous_hash?: string;
  tamper_proof?: boolean;
  details_json?: Record<string, unknown>;
}

export interface ShiftLogEntry {
  id?: number;
  plant_unit_id?: number | null;
  unit?: string;
  asset_id?: number | null;
  asset_tag?: string;
  author_id?: number | null;
  author_name?: string;
  acknowledged_by_id?: number | null;
  occurred_at?: string;
  timestamp?: string;
  shift_label?: string;
  event_type?: string;
  severity?: string;
  message?: string;
  unit_status?: string;
  open_risks?: string;
  outstanding_actions?: string;
  procedure_steps_json?: Array<{ step?: number; label?: string; completed?: boolean }>;
  steps_completed?: number;
  steps_total?: number;
  steps_percent?: number;
  incoming_ack?: boolean;
  handover_completed_at?: string | null;
}

export interface User {
  id?: number;
  name?: string;
  display_name?: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  approved?: boolean;
  profile_completed?: boolean;
  role_slugs?: string[];
  sign_in_count?: number;
  last_sign_in_at?: string | null;
}

export interface Role {
  id?: number;
  name?: string;
  slug?: string;
  description?: string;
}

export interface Organization {
  id?: number;
  name?: string;
  slug?: string;
  description?: string;
}

/** Fleet overview aggregate. */
export interface FleetOverview {
  kpis: Array<{ label: string; value: number | null; note: string; direction: string }>;
  totals: Record<string, number>;
  unit_risk: Array<{ name: string; exposure_percent: number | null }>;
  generated_at: string;
}

/** Active anomaly queue row. `id` is the asset tag. */
export interface ActiveAnomaly {
  id: string;
  record_id: number;
  issue: string;
  age: string;
  severity: string;
  asset_tag: string;
  status: string;
  rul_window: string | null;
  detected_at: string | null;
}

/** Unit risk matrix. */
export interface UnitRiskMatrix {
  rows: Array<Record<string, unknown>>;
  risk_cells: Array<Record<string, unknown>>;
  derate_recommendation: string | null;
  severity: string;
  generated_at: string;
}

/** On-prem system health. */
export interface SystemHealthMetric {
  name: string;
  /** null whenever the value was not actually measured. */
  value: string | null;
  status: "measured" | "not_measured";
}

export interface SystemHealthVolume {
  name: string;
  /** null whenever the volume was not actually read. */
  percent: number | null;
  status: "measured" | "not_measured";
}

export interface SystemHealth {
  metrics: SystemHealthMetric[];
  services: Array<{ name: string; status: string }>;
  storage: SystemHealthVolume[];
  events: string[];
  warnings: string[];
  ingestion: {
    buffer_depth: number;
    backfill_pending: number;
    connectors: Array<Record<string, unknown>>;
  };
  backup: { last_run_at: string | null; status: string; retention_days: number | null };
  generated_at: string;
}

/** Nested ISA-95 hierarchy node. */
export interface HierarchyNode {
  id: string;
  record_id: number | null;
  label: string;
  name?: string;
  node_type: 'complex' | 'unit' | 'asset' | 'component';
  asset_tag?: string;
  equipment_class?: string;
  health_state: string;
  severity: string;
  health_index?: number | null;
  children: HierarchyNode[];
}

export interface TagValidationRow {
  tag_id: number | null;
  tag_path: string | null;
  success: boolean;
  value: number | null;
  latency_ms: number | null;
  quality_status: string | null;
  stale_seconds: number | null;
  errors: string[];
}
