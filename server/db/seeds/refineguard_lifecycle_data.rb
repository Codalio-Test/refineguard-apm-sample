# frozen_string_literal: true

# RefineGuard APM — model lifecycle, prescriptive action, operations and
# governance demo rows. Loaded by db/seeds.rb last.

org = Organization.find_by!(slug: 'demo-org')
admin = User.find_by!(email: 'administrator@example.com')
specialist = User.find_by!(email: 'machinery_specialist@example.com')
planner = User.find_by!(email: 'maintenance_planner@example.com')
superintendent = User.find_by!(email: 'operations_superintendent@example.com')
engineer = User.find_by!(email: 'reliability_engineer@example.com')

asset = ->(tag) { Asset.find_by!(organization: org, asset_tag: tag) }
incident = ->(code) { DiagnosticIncident.find_by!(organization: org, incident_code: code) }
unit = ->(code) { PlantUnit.find_by!(organization: org, unit_code: code) }

now = Time.current

# ---------------------------------------------------------------------------
# Model baselines + golden windows
# ---------------------------------------------------------------------------

baseline_rows = [
  [ 'P-204A', 'v2.4.1-PCA-AE', 'Deep Autoencoder & Principal Component Residual Tracking',
   'Production', true, 'Trained',
   { 'fft_bins' => 512, 'batch_size' => 64, 'latent_dim' => 8, 'learning_rate' => 0.001,
     'anomaly_threshold_std' => 3 },
   { 'precision' => 0.942, 'recall' => 0.918, 'false_alarms' => 0.016, 'lead_time_days' => 18.4,
     'drift' => 0.07, 'coverage' => 0.989 },
   { 'min_precision' => true, 'min_recall' => true, 'max_false_alarm_rate' => true,
     'min_lead_time_days' => true, 'max_drift' => true, 'min_coverage' => true },
   180 ],
  [ 'P-204A', 'v3.8.0-PCA-AE', 'Deep Autoencoder & Principal Component Residual Tracking',
   'Candidate', false, 'Trained',
   { 'fft_bins' => 512, 'batch_size' => 64, 'latent_dim' => 10, 'learning_rate' => 0.0009,
     'anomaly_threshold_std' => 3 },
   { 'precision' => 0.951, 'recall' => 0.927, 'false_alarms' => 0.014, 'lead_time_days' => 19.1,
     'drift' => 0.06, 'coverage' => 0.991 },
   { 'min_precision' => true, 'min_recall' => true, 'max_false_alarm_rate' => true,
     'min_lead_time_days' => true, 'max_drift' => true, 'min_coverage' => true },
   14 ],
  [ 'K-301', 'v1.9.0-VAR-LSTM', 'Vector Autoregression with Long Short-Term Memory',
   'Production', true, 'Trained',
   { 'dropout' => 0.2, 'lstm_units' => [ 64, 32 ], 'loss_metric' => 'MSE', 'sequence_length' => 120 },
   { 'precision' => 0.931, 'recall' => 0.902, 'false_alarms' => 0.022, 'lead_time_days' => 16.7,
     'drift' => 0.08, 'coverage' => 0.981 },
   { 'min_precision' => true, 'min_recall' => true, 'max_false_alarm_rate' => true,
     'min_lead_time_days' => true, 'max_drift' => true, 'min_coverage' => true },
   240 ],
  [ 'KT-201', 'v1.2.0-DTW-OCSVM', 'Dynamic Time Warping One-Class SVM',
   'Production', true, 'Trained',
   { 'nu' => 0.05, 'gamma' => 'scale', 'kernel' => 'rbf' },
   { 'precision' => 0.902, 'recall' => 0.874, 'false_alarms' => 0.031, 'lead_time_days' => 14.2,
     'drift' => 0.09, 'coverage' => 0.968 },
   { 'min_precision' => true, 'min_recall' => true, 'max_false_alarm_rate' => true,
     'min_lead_time_days' => true, 'max_drift' => true, 'min_coverage' => true },
   300 ]
]

baselines = {}
baseline_rows.each do |asset_tag, version, algorithm, status, active, training_status,
                       hyperparameters, metrics, gates, window_days_ago|
  baselines[[ asset_tag, version ]] = upsert(
    ModelBaseline, { organization: org, asset: asset.call(asset_tag), model_version: version },
    algorithm_type: algorithm, status: status, training_status: training_status,
    training_progress: 100,
    hyperparameters_json: hyperparameters, accuracy_metrics_json: metrics, gates_json: gates,
    is_active: active,
    training_window_start: (now - (window_days_ago + 90).days).change(hour: 0, min: 0, sec: 0),
    training_window_end: (now - window_days_ago.days).change(hour: 0, min: 0, sec: 0),
    training_log: "Local training completed on #{window_days_ago} days of post-overhaul golden data.\n",
    approved_by_id: active ? specialist.id : nil,
    approved_at: active ? (now - (window_days_ago - 1).days) : nil,
    promoted_at: active ? (now - (window_days_ago - 1).days) : nil
  )
end

window_rows = [
  [ 'P-204A', 2, 'Apr 02', 88.0, 99.8, false, true ],
  [ 'P-204A', 8, 'Apr 08', 91.0, 99.6, true, true ],
  [ 'P-204A', 14, 'Apr 14', 87.0, 100.0, true, true ],
  [ 'P-204A', 21, 'Apr 21', 79.0, 96.4, false, false ],
  [ 'K-301', 30, 'Mar 30', 93.0, 99.2, true, true ],
  [ 'K-301', 37, 'Apr 06', 90.0, 98.7, false, true ]
]

window_rows.each do |asset_tag, days_ago, label, load, completeness, selected, eligible|
  upsert(
    BaselineWindow,
    { organization: org, asset: asset.call(asset_tag), label: label },
    model_baseline_id: baselines.values.find { |b| b.asset_id == asset.call(asset_tag).id }&.id,
    window_start: (now - (days_ago + 6).days).change(hour: 0, min: 0, sec: 0),
    window_end: (now - days_ago.days).change(hour: 0, min: 0, sec: 0),
    load_percent: load, completeness_percent: completeness,
    selected: selected, eligible: eligible
  )
end

# ---------------------------------------------------------------------------
# Prescriptive advisories
# ---------------------------------------------------------------------------

advisory_rows = [
  { incident: 'INC-24018', code: 'ADV-2024-0891', status: 'Ready for Dispatch',
    urgency: 'Urgent Action Required', throttle: 15.0, due: 6,
    recommendation: 'Replace the outboard angular contact bearing pair (SKF 7314 BECBM) and inspect Plan 53B seal flush piping. Switch load to P-204B before the next Alarm breach.',
    steps: [ 'Start standby pump P-204B and confirm stable discharge pressure',
            'Isolate P-204A and depressurise the seal plan',
            'Remove and replace the outboard bearing pair',
            'Inspect Plan 53B barrier fluid and strainer',
            'Laser-align the coupling before return to service' ],
    warehouse_status: 'In stock', warehouse_bin: 'C-14', lead_time: 2,
    parts: { 'bearings' => [ 'SKF 7314 BECBM Pair' ], 'seals' => [ 'John Crane API 682 Type A O-ring Kit' ],
             'lubricant' => [ 'Mobil DTE 25 Hydraulic Oil (20 Liters)' ] },
    standby: 'P-204B', standby_ready: true },
  { incident: 'INC-24021', code: 'ADV-2024-0892', status: 'Ready for Dispatch',
    urgency: 'Routine', throttle: 0.0, due: 14,
    recommendation: 'Schedule a laser shaft alignment check on the turbine-compressor spool during the next planned nitrogen blowdown cycle. Inspect diaphragm coupling disc packs for fretting fatigue.',
    steps: [ 'Raise the work request against the FCC spool',
            'Verify coupling disc pack availability',
            'Laser-align to within 0.05 mm offset' ],
    warehouse_status: 'In stock', warehouse_bin: 'B-07', lead_time: 5,
    parts: { 'shims' => [ '316SS Precision Pre-Cut Shims 0.05mm - 2.0mm Kit' ],
             'coupling_bolts' => [ 'Rexnord Thomas Series 71 Bolt Kit M16x80 Grade 10.9' ] },
    standby: nil, standby_ready: nil },
  { incident: 'INC-24010', code: 'ADV-2024-0880', status: 'Ready for Dispatch',
    urgency: 'Urgent Action Required', throttle: 8.0, due: 12,
    recommendation: 'Reduce P-101A throughput and switch load to hot-standby P-101B. Mobilise mechanical maintenance for drive-end bearing replacement during the upcoming de-rate window.',
    steps: [ 'Switch charge duty to P-101B',
            'Reduce P-101A speed to 70%',
            'Replace drive-end bearing set',
            'Verify seal flush plan 53B' ],
    warehouse_status: 'Partially available', warehouse_bin: 'C-14', lead_time: 21,
    parts: { 'bearings' => [ 'SKF 7314 BECBM Pair' ], 'seals' => [ 'Flowserve Cartridge Seal Kit' ] },
    standby: 'P-101B', standby_ready: true }
]

advisories = {}
advisory_rows.each do |row|
  advisories[row[:code]] = upsert(
    PrescriptiveAdvisory, { organization: org, advisory_code: row[:code] },
    diagnostic_incident: incident.call(row[:incident]),
    recommended_action: row[:recommendation],
    action_steps_json: row[:steps],
    throttle_percentage: row[:throttle],
    parts_required_json: row[:parts],
    warehouse_status: row[:warehouse_status], warehouse_bin: row[:warehouse_bin],
    parts_lead_time_days: row[:lead_time],
    urgency: row[:urgency], status: row[:status], due_within_days: row[:due],
    standby_asset_id: row[:standby] && asset.call(row[:standby]).id,
    standby_ready: row[:standby_ready],
    standby_checks_json: row[:standby_ready] ? [
      { 'key' => 'lube_oil_level', 'label' => 'Lube oil level', 'passed' => true,
        'observed_at' => now.iso8601, 'detail' => 'Within limits' },
      { 'key' => 'motor_heater', 'label' => 'Motor space heater', 'passed' => true,
        'observed_at' => now.iso8601, 'detail' => 'Energised' },
      { 'key' => 'isolation_valve', 'label' => 'Suction/discharge isolation valve', 'passed' => true,
        'observed_at' => now.iso8601, 'detail' => 'Free and stroked' },
      { 'key' => 'seal_flush', 'label' => 'Seal flush plan availability', 'passed' => true,
        'observed_at' => now.iso8601, 'detail' => 'Barrier fluid at level' }
    ] : nil
  )
end

# ---------------------------------------------------------------------------
# CMMS work orders
# ---------------------------------------------------------------------------

work_order_rows = [
  [ 'ADV-2024-0891', 'SAP PM', 'SAP-WO-88029144', 'Dispatched', 'Priority 2 - Urgent (Within 7 Days)',
   6, { 'priority' => 'Priority 2 - Urgent (Within 7 Days)', 'order_type' => 'PM02',
        'short_text' => 'RefineGuard APM: replace outboard bearing on P-204A',
        'work_center' => 'MECH-01', 'planner_group' => 'REL-ROT',
        'equipment_number' => 'P-204A', 'iso_failure_code' => 'ISO14224-MECH-BRG-BPFO',
        'functional_location' => 'BRR Complex / CDU-1 / Charge Train A / P-204A' },
   [ { 'item' => 'SKF 7314 BECBM Pair', 'warehouse_bin' => 'C-14', 'status' => 'In stock' } ], nil ],
  [ 'ADV-2024-0892', 'IBM Maximo', 'MAX-WO-109432', 'Pending Sync', 'Priority 3 - Routine',
   30, { 'siteid' => 'REFINERY_AREA_C', 'assetnum' => 'C-101B', 'work_type' => 'CM',
        'wopriority' => 3, 'description' => 'Laser alignment verification - elevated 2X harmonic' },
   [], 'CMMS connector did not acknowledge within 3000ms' ]
]

work_order_rows.each do |advisory_code, cmms_type, order_number, sync_status, priority,
                         required_in_days, payload, reservations, error|
  dispatched = sync_status == 'Dispatched'

  upsert(
    CmmsWorkOrder, { organization: org, external_order_number: order_number },
    prescriptive_advisory: advisories.fetch(advisory_code),
    user: planner,
    cmms_type: cmms_type, sync_status: sync_status, priority: priority,
    required_by: (now + required_in_days.days).to_date,
    dispatched_at: dispatched ? (now - 2.days) : nil,
    confirmed_at: dispatched ? (now - 2.days) : nil,
    work_order_payload: payload,
    material_reservations_json: reservations,
    error_message: error
  )
end

# ---------------------------------------------------------------------------
# Operations shift log
# ---------------------------------------------------------------------------

shift_rows = [
  [ 0, '10:42', 'Day shift', 'Alert acknowledgement', 'critical',
   'P-204A bearing alarm acknowledged', 'CDU-1', 'P-204A',
   'Charge train A running on P-204A at reduced rate', 4, 5, 'Lockout pending on P-204A' ],
  [ 0, '09:18', 'Day shift', 'Derate approval', 'warning',
   'CDU-1 charge rate reduced 8%', 'CDU-1', 'P-204A',
   'Charge rate reduced to 84% of design', 2, 4, 'Confirm pump changeover window' ],
  [ 0, '07:04', 'Night shift', 'Historian backfill', 'info',
   'PI historian backfill committed with zero lost points', 'CDU-1', nil,
   'Ingestion nominal', 0, 0, nil ],
  [ 0, '06:12', 'Night shift', 'Standby switchover', 'warning',
   'P-101B warmed up and ready for changeover', 'CDU-1', 'P-101B',
   'Standby ready', 3, 3, 'Await superintendent approval' ],
  [ 1, '22:35', 'Evening shift', 'Maintenance lockout', 'info',
   'Pending maintenance lockout scheduled for KT-201 governor inspection', 'FCC-2', 'KT-201',
   'Main air blower train running', 0, 3, 'Governor inspection pending' ]
]

shift_rows.each do |days_ago, time, shift_label, event_type, severity, message, unit_code,
                    asset_tag, unit_status, steps_completed, steps_total, outstanding|
  occurred = (now - days_ago.days).change(hour: time.split(':').first.to_i,
                                          min: time.split(':').last.to_i, sec: 0)

  upsert(
    ShiftLogEntry,
    { organization: org, occurred_at: occurred, message: message },
    plant_unit_id: unit.call(unit_code).id,
    asset_id: asset_tag && asset.call(asset_tag).id,
    author_id: superintendent.id,
    acknowledged_by_id: days_ago.zero? ? engineer.id : nil,
    shift_label: shift_label, event_type: event_type, severity: severity,
    unit_status: unit_status,
    open_risks: 'P-204A bearing degradation under active mitigation',
    outstanding_actions: outstanding,
    procedure_steps_json: (1..steps_total).map do |step|
      { 'step' => step, 'label' => "Standby procedure step #{step}",
        'completed' => step <= steps_completed }
    end,
    steps_completed: steps_completed, steps_total: steps_total,
    incoming_ack: days_ago.positive?,
    handover_completed_at: days_ago.positive? ? occurred + 20.minutes : nil
  )
end

# ---------------------------------------------------------------------------
# Tamper-evident security trail (append-only, hash-chained)
# ---------------------------------------------------------------------------

if SecurityAuditEvent.where(organization: org).count.zero?
  Refineguard::SecurityAuditWriter.call(
    organization: org, user: admin,
    action_type: 'AIR_GAP_MODEL_IMPORT', severity: 'warning', result: 'Success',
    entity_affected: 'ModelBaseline:v1.2.0-DTW-OCSVM', source_host: 'RG-NODE1',
    recorded_at: now - 3.days,
    details: { 'media_source' => 'Read-Only Optical Data Diode (DVD-R)',
               'signature_verified' => true,
               'pkg_checksum_sha256' => '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a' }
  )
  Refineguard::SecurityAuditWriter.call(
    organization: org, user: engineer,
    action_type: 'OVERRIDE_HEALTH_BASELINE', severity: 'critical', result: 'Success',
    entity_affected: 'ModelBaseline:v2.4.1-PCA-AE', source_host: 'ENG-WS14',
    recorded_at: now - 2.days,
    details: { 'reason' => 'Post-lube-oil change recalibration approved by Reliability Superintendent',
               'operator_role' => 'Lead Reliability Engineer' }
  )
  Refineguard::SecurityAuditWriter.call(
    organization: org, user: engineer,
    action_type: 'ACKNOWLEDGE', severity: 'info', result: 'Success',
    entity_affected: 'INC-24018', source_host: 'ENG-WS14',
    recorded_at: now - 1.day,
    details: { 'status' => 'Under Investigation', 'asset_tag' => 'P-204A' }
  )
  Refineguard::SecurityAuditWriter.call(
    organization: org,
    action_type: 'AUTH_FAILURE', severity: 'warning', result: 'Failure',
    entity_affected: 'svc.pi', source_host: 'RG-NODE1', recorded_at: now - 6.hours,
    details: { 'reason' => 'invalid hardware token', 'failed_login_attempts' => 1 }
  )
  Refineguard::SecurityAuditWriter.call(
    organization: org, user: planner,
    action_type: 'DISPATCH_WORK_ORDER', severity: 'warning', result: 'Success',
    entity_affected: 'CmmsWorkOrder:SAP-WO-88029144', source_host: 'PLAN-WS02',
    recorded_at: now - 2.days,
    details: { 'target_system' => 'SAP PM', 'external_order_number' => 'SAP-WO-88029144' }
  )
end

puts "Seeded lifecycle data: #{ModelBaseline.where(organization: org).count} baselines, " \
     "#{PrescriptiveAdvisory.where(organization: org).count} advisories, " \
     "#{ShiftLogEntry.where(organization: org).count} shift log entries, " \
     "#{SecurityAuditEvent.where(organization: org).count} security audit events"
