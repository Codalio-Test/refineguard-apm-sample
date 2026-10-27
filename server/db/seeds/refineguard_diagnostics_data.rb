# frozen_string_literal: true

# RefineGuard APM — diagnostics, prognostics and governance demo rows.
#
# Loaded by db/seeds.rb after the plant data. Every row is idempotent.

org = Organization.find_by!(slug: 'demo-org')
admin = User.find_by!(email: 'administrator@example.com')
specialist = User.find_by!(email: 'machinery_specialist@example.com')
planner = User.find_by!(email: 'maintenance_planner@example.com')
superintendent = User.find_by!(email: 'operations_superintendent@example.com')
engineer = User.find_by!(email: 'reliability_engineer@example.com')

asset = ->(tag) { Asset.find_by!(organization: org, asset_tag: tag) }
failure_mode = ->(code) { FailureMode.find_by!(organization: org, iso_code: code) }
tag = ->(path) { HistorianTag.find_by!(organization: org, tag_path: path) }
component = ->(key) { AssetComponent.find_by!(organization: org, component_name: key) }

now = Time.current

# ---------------------------------------------------------------------------
# Asset health indices — latest evaluation per asset (attribution bars)
# ---------------------------------------------------------------------------

health_rows = [
  [ 'P-204A', 28.0, -33.0, 0.97, 'Trip', 0.1482, 0.0910, 3, 'Unacceptable',
   { 'vib_de_env' => { 'status' => 'severe_anomaly', 'weight' => 0.45, 'z_score' => 3.82 },
     'brg_nde_temp' => { 'status' => 'warning', 'weight' => 0.30, 'z_score' => 2.45 },
     'discharge_diff_press' => { 'status' => 'normal', 'weight' => 0.25, 'z_score' => 1.10 } },
   [ { 'label' => 'RMS velocity', 'limit' => 7.1, 'observed' => 8.42, 'unit' => 'mm/s', 'breached' => true },
    { 'label' => 'Bearing temp', 'limit' => 95.0, 'observed' => 96.0, 'unit' => 'degC', 'breached' => true },
    { 'label' => 'Motor current', 'limit' => 340.0, 'observed' => 318.0, 'unit' => 'A', 'breached' => false } ] ],
  [ 'P-101A', 61.0, -33.0, 0.94, 'Alarm', 0.1042, 0.0910, 2, 'Unsatisfactory',
   { 'vib_de_env' => { 'status' => 'severe_anomaly', 'weight' => 0.45, 'z_score' => 3.82 },
     'brg_nde_temp' => { 'status' => 'warning', 'weight' => 0.30, 'z_score' => 2.45 },
     'discharge_diff_press' => { 'status' => 'normal', 'weight' => 0.25, 'z_score' => 1.10 } },
   [ { 'label' => 'RMS velocity', 'limit' => 7.1, 'observed' => 7.82, 'unit' => 'mm/s', 'breached' => true } ] ],
  [ 'C-101B', 54.0, -8.5, 0.71, 'Alert', 0.0720, 0.0810, 1, 'Unsatisfactory',
   { 'shaft_displacement' => { 'status' => 'warning', 'weight' => 0.42, 'z_score' => 2.10 },
     'seal_vent_flow' => { 'status' => 'warning', 'weight' => 0.33, 'z_score' => 1.90 },
     'lube_oil_header_press' => { 'status' => 'normal', 'weight' => 0.25, 'z_score' => 0.60 } },
   [ { 'label' => 'Shaft displacement', 'limit' => 50.0, 'observed' => 32.1, 'unit' => 'um', 'breached' => false } ] ],
  [ 'K-301', 88.5, -0.8, 0.12, 'Normal', 0.0204, 0.0610, 0, 'Good',
   { 'seal_vent_flow' => { 'status' => 'normal', 'weight' => 0.35, 'z_score' => 0.80 },
     'shaft_displacement' => { 'status' => 'normal', 'weight' => 0.40, 'z_score' => 0.45 },
     'lube_oil_header_press' => { 'status' => 'normal', 'weight' => 0.25, 'z_score' => 0.20 } },
   [] ],
  [ 'KT-201', 64.7, -12.1, 0.78, 'Alert', 0.0688, 0.0610, 1, 'Unsatisfactory',
   { 'exhaust_casing_temp' => { 'status' => 'moderate', 'weight' => 0.40, 'z_score' => 1.40 },
     'governor_response_lag' => { 'status' => 'warning', 'weight' => 0.60, 'z_score' => 2.15 } },
   [ { 'label' => 'Exhaust casing temp', 'limit' => 480.0, 'observed' => 462.0, 'unit' => 'degC', 'breached' => false } ] ],
  [ 'P-108C', 84.0, -1.4, 0.11, 'Normal', 0.0210, 0.0610, 0, 'Satisfactory',
   { 'axial_thrust_pos' => { 'status' => 'nominal', 'weight' => 0.50, 'z_score' => 0.15 },
     'motor_winding_temp' => { 'status' => 'nominal', 'weight' => 0.50, 'z_score' => 0.22 } },
   [] ],
  [ 'M-44', 68.0, -6.2, 0.62, 'Alert', 0.0655, 0.0610, 1, 'Satisfactory',
   { 'motor_current' => { 'status' => 'warning', 'weight' => 0.55, 'z_score' => 2.05 },
     'stator_winding_temp' => { 'status' => 'normal', 'weight' => 0.45, 'z_score' => 0.90 } },
   [ { 'label' => 'Motor current', 'limit' => 350.0, 'observed' => 341.0, 'unit' => 'A', 'breached' => false } ] ],
  [ 'P-204B', 96.0, 0.4, 0.04, 'Normal', 0.0091, 0.0610, 0, 'Good',
   { 'vib_de_env' => { 'status' => 'nominal', 'weight' => 0.60, 'z_score' => 0.10 },
     'brg_nde_temp' => { 'status' => 'nominal', 'weight' => 0.40, 'z_score' => 0.20 } }, [] ],
  [ 'P-101B', 95.0, 0.0, 0.05, 'Normal', 0.0095, 0.0610, 0, 'Good',
   { 'vib_de_env' => { 'status' => 'nominal', 'weight' => 0.60, 'z_score' => 0.12 },
     'brg_nde_temp' => { 'status' => 'nominal', 'weight' => 0.40, 'z_score' => 0.18 } }, [] ],
  [ 'P-402', 95.0, 0.1, 0.05, 'Normal', 0.0090, 0.0610, 0, 'Good',
   { 'axial_thrust_pos' => { 'status' => 'nominal', 'weight' => 0.50, 'z_score' => 0.15 },
     'motor_winding_temp' => { 'status' => 'nominal', 'weight' => 0.50, 'z_score' => 0.22 } }, [] ]
]

health_rows.each do |asset_tag, score, delta, confidence, state, error, p99, breaches, iso, factors, envelope|
  upsert(AssetHealthIndex, { organization: org, asset: asset.call(asset_tag),
                             calculated_at: now.change(sec: 0) },
         health_score: score, health_delta: delta, anomaly_confidence: confidence,
         health_state: state, contributing_factors_json: factors,
         envelope_checks_json: envelope, reconstruction_error: error, threshold_p99: p99,
         consecutive_breach_intervals: breaches, iso_severity_category: iso)
end

# ---------------------------------------------------------------------------
# Diagnostic incidents
# ---------------------------------------------------------------------------

incident_rows = [
  { asset: 'P-204A', failure_mode: 'ISO14224-MECH-BRG-BPFO', code: 'INC-24018',
    status: 'Active', severity_level: 'High', health_state: 'Trip',
    rul: 8.5, low: 6.0, high: 11.0, conf: 90.0, pf: 21.0,
    regime: 'heavy', regime_conf: 96.2,
    root_cause: 'Stage 2 bearing outer race spall on the outboard angular contact pair.',
    evidence: 'Discrete non-synchronous peaks at BPFO with 1X sidebands; defect energy emerged 9 days ago and accelerated after a cavitation surge.',
    mechanism: 'Stage 2 Bearing Outer Race Spall - Outboard Bearing',
    finding_confidence: 0.89, finding_status: 'Signed off',
    detected_at: now - 3.days, signed_off: true, acknowledged: true },
  { asset: 'C-101B', failure_mode: 'ISO14224-MECH-ALIGN-ANG', code: 'INC-24021',
    status: 'Investigating', severity_level: 'Medium', health_state: 'Alert',
    rul: 22.0, low: 18.0, high: 26.0, conf: 88.0, pf: 34.0,
    regime: 'medium', regime_conf: 91.4,
    root_cause: 'Suspected angular misalignment across the turbine-compressor spool.',
    evidence: 'Prominent 2X radial and axial components with rising seal vent flow.',
    mechanism: 'Angular & Parallel Shaft Misalignment',
    finding_confidence: 0.66, finding_status: 'Draft',
    detected_at: now - 2.days, signed_off: false, acknowledged: true },
  { asset: 'KT-201', failure_mode: nil, code: 'INC-24022',
    status: 'Active', severity_level: 'Medium', health_state: 'Alert',
    rul: 42.0, low: 36.0, high: 48.0, conf: 84.0, pf: 51.0,
    regime: 'medium', regime_conf: 88.0,
    root_cause: nil, evidence: nil, mechanism: nil,
    finding_confidence: nil, finding_status: 'Draft',
    detected_at: now - 5.days, signed_off: false, acknowledged: false },
  { asset: 'M-44', failure_mode: nil, code: 'INC-24023',
    status: 'Active', severity_level: 'Medium', health_state: 'Alert',
    rul: 61.0, low: 48.0, high: 74.0, conf: 82.0, pf: 68.0,
    regime: 'light', regime_conf: 85.5,
    root_cause: nil, evidence: nil, mechanism: nil,
    finding_confidence: nil, finding_status: 'Draft',
    detected_at: now - 1.day, signed_off: false, acknowledged: false },
  { asset: 'P-101A', failure_mode: 'ISO14224-MECH-BRG-BPFO', code: 'INC-24010',
    status: 'Under Investigation', severity_level: 'High', health_state: 'Alarm',
    rul: 18.5, low: 14.0, high: 22.0, conf: 90.0, pf: 26.0,
    regime: 'medium', regime_conf: 90.1,
    root_cause: 'Outboard bearing angular contact pair degradation.',
    evidence: 'Elevated 1X harmonic amplitude surge with 3.82 sigma deviation on drive-end enveloping.',
    mechanism: 'Stage 2 Bearing Outer Race Spall',
    finding_confidence: 0.84, finding_status: 'Signed off',
    detected_at: now - 3.days - 1.hour, signed_off: true, acknowledged: true },
  { asset: 'P-108C', failure_mode: 'ISO14224-HYDR-CAVIT-SUCT', code: 'INC-24005',
    status: 'Resolved', severity_level: 'Low', health_state: 'Normal',
    rul: 120.0, low: 110.0, high: 130.0, conf: 86.0, pf: 140.0,
    regime: 'light', regime_conf: 92.0,
    root_cause: 'Transient suction recirculation cleared by strainer clean.',
    evidence: 'Broadband noise floor rise between 1 kHz and 5 kHz, since resolved.',
    mechanism: 'Hydraulic Cavitation & Recirculation',
    finding_confidence: 0.72, finding_status: 'Signed off',
    detected_at: now - 40.days, signed_off: true, acknowledged: true }
]

incidents = {}
incident_rows.each do |row|
  record = upsert(
    DiagnosticIncident, { organization: org, incident_code: row[:code] },
    asset: asset.call(row[:asset]),
    failure_mode: row[:failure_mode] && failure_mode.call(row[:failure_mode]),
    status: row[:status], severity_level: row[:severity_level], health_state: row[:health_state],
    rul_days_estimate: row[:rul], rul_window_low_days: row[:low],
    rul_window_high_days: row[:high], rul_confidence_pct: row[:conf],
    pf_interval_days: row[:pf], regime: row[:regime], regime_confidence_pct: row[:regime_conf],
    root_cause: row[:root_cause], evidence_summary: row[:evidence],
    failure_mechanism: row[:mechanism], finding_confidence: row[:finding_confidence],
    finding_status: row[:finding_status],
    signed_off_by_id: row[:signed_off] ? specialist.id : nil,
    signed_off_at: row[:signed_off] ? (now - 2.days) : nil,
    acknowledged_by_id: row[:acknowledged] ? engineer.id : nil,
    acknowledged_at: row[:acknowledged] ? (now - 2.days - 4.hours) : nil,
    detected_at: row[:detected_at],
    resolved_at: row[:status] == 'Resolved' ? (now - 38.days) : nil
  )
  incidents[row[:code]] = record
end

# ---------------------------------------------------------------------------
# Physical fingerprint / classifier assessments (P-204A hero row)
# ---------------------------------------------------------------------------

snapshot_speed_hz = 29.92 # 1795 rpm
kinematic = Refineguard::BearingKinematics.markers('SKF 7314 BECBM', snapshot_speed_hz).index_by { |m| m['label'] }

assessment_rows = [
  [ 'P-204A', 'ISO14224-MECH-BRG-BPFO', 87.0, 'BPFO' ],
  [ 'P-204A', 'ISO14224-MECH-ALIGN-ANG', 41.0, '2X' ],
  [ 'P-204A', 'ISO14224-MECH-BRG-BPFI', 24.0, 'BPFI' ],
  [ 'P-204A', 'ISO14224-HYDR-CAVIT-SUCT', 8.0, '1X-5X broadband' ],
  [ 'C-101B', 'ISO14224-MECH-ALIGN-ANG', 63.0, '2X' ]
]

assessment_rows.each do |asset_tag, iso, probability, marker_label|
  marker = kinematic[marker_label]
  expected = marker ? marker['expected_hz'] : 2.0 * snapshot_speed_hz
  observed = expected ? (expected * (1 + ((100 - probability) / 1000.0))).round(2) : nil

  upsert(
    FailureModeAssessment,
    { organization: org, asset: asset.call(asset_tag),
      failure_mode: failure_mode.call(iso), assessed_at: now.change(sec: 0) },
    diagnostic_incident_id: incidents.values.find { |i| i.asset_id == asset.call(asset_tag).id }&.id,
    probability: probability,
    confidence_low: (probability * 0.92).round(1),
    confidence_high: [ probability * 1.06, 99.9 ].min.round(1),
    marker_label: marker_label,
    expected_hz: expected,
    observed_hz: observed,
    amplitude: (0.4 + probability / 100.0).round(3),
    match_score: (probability / 100.0).round(3),
    assessed_by_id: specialist.id
  )
end

# ---------------------------------------------------------------------------
# Spectrum snapshots (FFT / waterfall / orbit) for the spectral workbench
# ---------------------------------------------------------------------------

def spectrum_points(speed_hz, base_amplitude, band_noise: 0.02)
  # 1X–10X harmonics plus a broadband floor, which is what the classifier and
  # the harmonic cursor read.
  points = (1..10).map do |order|
    { 'hz' => (order * speed_hz).round(2), 'amplitude' => (base_amplitude / order.to_f).round(4) }
  end

  (20..120).each do |step|
    hz = (step * 20.0).round(2)
    noise = band_noise * (1 + Math.sin(step.to_f / 3.0).abs)
    noise *= 3.1 if hz.between?(1000.0, 5000.0) # cavitation band
    points << { 'hz' => hz, 'amplitude' => noise.round(5) }
  end

  points.sort_by { |p| p['hz'] }
end

def harmonic_rows(speed_hz, base_amplitude)
  (1..10).map do |order|
    amplitude = (base_amplitude / order.to_f).round(4)
    {
      'order' => order,
      'expected_hz' => (order * speed_hz).round(2),
      'amplitude' => amplitude,
      'relative_amplitude' => (amplitude / base_amplitude).round(4)
    }
  end
end

def bearing_marker_rows(kinematic, deviation: 1.004)
  kinematic.values.map do |marker|
    expected = marker['expected_hz']
    observed = (expected * deviation).round(2)
    {
      'label' => marker['label'],
      'order' => marker['order'],
      'expected_hz' => expected,
      'observed_hz' => observed,
      'amplitude' => (0.12 + (5.24 - marker['order']).abs / 40.0).round(4),
      'match_score' => (1.0 - ((observed - expected).abs / expected)).clamp(0.0, 1.0).round(4)
    }
  end
end

def waterfall_rows(speed_hz, base_amplitude, slices: 30)
  (0...slices).map do |index|
    factor = 0.46 + (index.to_f / slices) # degradation ramp
    {
      'day_offset' => index - slices,
      'captured_at' => (Time.current - (slices - index).days).iso8601,
      'points' => (1..5).map do |order|
        { 'hz' => (order * speed_hz).round(2),
          'amplitude' => (base_amplitude / order.to_f * factor).round(4) }
      end
    }
  end
end

def orbit_rows(speed_hz)
  (0..71).map do |step|
    angle = step * 5.0 * Math::PI / 180.0
    {
      'angle_deg' => (step * 5.0),
      'x_um' => (28.0 * Math.cos(angle) + 4.2 * Math.cos(2 * angle)).round(3),
      'y_um' => (22.0 * Math.sin(angle) + 3.1 * Math.sin(2 * angle)).round(3),
      'hz' => speed_hz
    }
  end
end

spectrum_rows = [
  [ 'P-204A', 'OB Horizontal', 65_536, 29.92, 8.42, 59.6, 0.62, 2.0, 3.18, 'PI:P204A.VIB.OH' ],
  [ 'P-204A', 'OB Vertical', 65_536, 29.92, 6.91, 59.6, 0.44, 2.0, 2.44, 'PI:P204A.VIB.OV' ],
  [ 'P-204A', 'OB Axial', 65_536, 29.92, 4.22, 29.9, 0.31, 1.0, 1.62, 'PI:P204A.VIB.AX' ],
  [ 'C-101B', 'OB Horizontal', 32_768, 113.33, 5.18, 113.3, 0.38, 1.0, 1.21, 'PI:C101B.VIB.IB' ]
]

spectrum_rows.each do |asset_tag, channel, resolution, speed_hz, rms, cursor_hz, cursor_amp,
                       cursor_order, delta, tag_path|
  upsert(
    SpectrumSnapshot,
    { organization: org, asset: asset.call(asset_tag), channel: channel,
      captured_at: now.change(min: 0, sec: 0) },
    historian_tag_id: tag.present? && HistorianTag.find_by(organization: org, tag_path: tag_path)&.id,
    line_resolution: resolution, sample_rate_hz: (speed_hz * 200).round(1),
    rms_velocity: rms, running_speed_hz: speed_hz,
    cursor_hz: cursor_hz, cursor_amplitude: cursor_amp, cursor_order: cursor_order,
    delta_baseline: delta,
    spectrum_json: spectrum_points(speed_hz, rms * 0.09),
    harmonics_json: harmonic_rows(speed_hz, rms * 0.09),
    bearing_markers_json: bearing_marker_rows(kinematic),
    waterfall_json: waterfall_rows(speed_hz, rms * 0.09),
    orbit_json: orbit_rows(speed_hz),
    waterfall_horizon_days: 30
  )
end

puts "Seeded diagnostics: #{DiagnosticIncident.where(organization: org).count} incidents, " \
     "#{SpectrumSnapshot.where(organization: org).count} spectrum snapshots"
