# frozen_string_literal: true

# RefineGuard APM — demo plant data for the `demo-org` tenant.
#
# Seeded from two sources, both required:
#   * the PRD `sample_data` rows (plant units, failure modes, connectors,
#     assets P-101A / K-301 / P-402 / KT-201, components, baselines, incidents,
#     health indices, historian tags, advisories, telemetry, work orders), and
#   * the locked UI prototype's narrative rows (P-204A, C-101B, P-108C, M-44)
#     with matching health/severity so every fixture key and every tag-keyed
#     deep link resolves.
#
# Everything is idempotent: find-or-initialise + assign + save.

org = Organization.find_by!(slug: 'demo-org')
other_org = Organization.find_by!(slug: 'runtime-other-org')
admin = User.find_by!(email: 'administrator@example.com')
specialist = User.find_by!(email: 'machinery_specialist@example.com')
planner = User.find_by!(email: 'maintenance_planner@example.com')
superintendent = User.find_by!(email: 'operations_superintendent@example.com')
engineer = User.find_by!(email: 'reliability_engineer@example.com')

now = Time.current

# ---------------------------------------------------------------------------
# Plant units
# ---------------------------------------------------------------------------

units = {
  'CDU-1' => upsert(PlantUnit, { organization: org, unit_code: 'CDU-1' },
                    unit_name: 'Atmospheric Crude Distillation Unit 1',
                    unit_type: 'Crude Distillation (CDU)',
                    refinery_area: 'Area A - Crude Fractionation',
                    description: 'Primary distillation unit processing 180,000 BPD heavy sour crude.',
                    throughput_target_bpd: 180_000.0, rate_percent: 92.0,
                    exposure_usd_per_day: 418_000.0,
                    derate_recommendation: 'Reduce CDU-1 charge rate by 8% until P-204A bearing inspection completes.'),
  'FCC-2' => upsert(PlantUnit, { organization: org, unit_code: 'FCC-2' },
                    unit_name: 'Fluid Catalytic Cracking Unit',
                    unit_type: 'Conversion (FCCU)',
                    refinery_area: 'Area C - Conversion Complex',
                    description: 'Catalytic gas oil conversion unit with wet gas compression system.',
                    throughput_target_bpd: 92_000.0, rate_percent: 88.0,
                    exposure_usd_per_day: 302_000.0,
                    derate_recommendation: nil),
  'HCU-3' => upsert(PlantUnit, { organization: org, unit_code: 'HCU-3' },
                    unit_name: 'Hydrocracker Complex',
                    unit_type: 'Hydroprocessing (HCU)',
                    refinery_area: 'Area B - Distillate Hydroprocessing',
                    description: 'High-pressure recycle gas compression and hydrotreating complex at 85 barg.',
                    throughput_target_bpd: 74_000.0, rate_percent: 96.0,
                    exposure_usd_per_day: 74_000.0,
                    derate_recommendation: nil),
  'ALKY-4' => upsert(PlantUnit, { organization: org, unit_code: 'ALKY-4' },
                     unit_name: 'Alkylation & Acid Plant',
                     unit_type: 'Alkylation (ALKY)',
                     refinery_area: 'Area D - Utilities & Offsites',
                     description: 'Depropanizer circulation and high-pressure BFW distribution.',
                     throughput_target_bpd: 21_000.0, rate_percent: 100.0,
                     exposure_usd_per_day: 41_000.0,
                     derate_recommendation: nil)
}

# ---------------------------------------------------------------------------
# ISO 14224 failure modes
# ---------------------------------------------------------------------------

failure_modes = {
  'ISO14224-MECH-BRG-BPFO' => upsert(FailureMode, { organization: org, iso_code: 'ISO14224-MECH-BRG-BPFO' },
                                     failure_name: 'Rolling Element Bearing Outer Race Defect (BPFO)',
                                     equipment_category: 'Centrifugal Pump',
                                     severity_weight: 0.85,
                                     detection_signature: 'Discrete non-synchronous peaks at BPFO harmonics with 1X sidebands',
                                     description: 'Fatigue spalling and micro-pitting on the stationary outer ring raceway emitting periodic impact peaks at calculated BPFO harmonics.'),
  'ISO14224-MECH-ALIGN-ANG' => upsert(FailureMode, { organization: org, iso_code: 'ISO14224-MECH-ALIGN-ANG' },
                                      failure_name: 'Angular & Parallel Shaft Misalignment',
                                      equipment_category: 'General Rotating Machinery',
                                      severity_weight: 0.70,
                                      detection_signature: 'Prominent 2X running speed radial and axial components',
                                      description: 'Coupling angular offset resulting in prominent 2X running speed radial and axial vibration components.'),
  'ISO14224-HYDR-CAVIT-SUCT' => upsert(FailureMode, { organization: org, iso_code: 'ISO14224-HYDR-CAVIT-SUCT' },
                                       failure_name: 'Hydraulic Cavitation & Recirculation',
                                       equipment_category: 'Centrifugal Pump',
                                       severity_weight: 0.80,
                                       detection_signature: 'Broadband noise floor rise between 1 kHz and 5 kHz',
                                       description: 'NPSH margin deficiency producing vapor bubble collapse and high-frequency broadband noise in the 2 kHz to 8 kHz band.'),
  'ISO14224-SEAL-DGS-CONTAM' => upsert(FailureMode, { organization: org, iso_code: 'ISO14224-SEAL-DGS-CONTAM' },
                                       failure_name: 'Dry Gas Seal Face Contamination / Grooving',
                                       equipment_category: 'Centrifugal Compressor',
                                       severity_weight: 0.95,
                                       detection_signature: 'Elevated primary vent leakage flow with slow upward drift',
                                       description: 'Liquid aerosol or particulate ingress into spiral-grooved dynamic gas seal faces causing excessive primary vent leakage.'),
  'ISO14224-MECH-BRG-BPFI' => upsert(FailureMode, { organization: org, iso_code: 'ISO14224-MECH-BRG-BPFI' },
                                     failure_name: 'Rolling Element Bearing Inner Race Defect (BPFI)',
                                     equipment_category: 'Centrifugal Pump',
                                     severity_weight: 0.88,
                                     detection_signature: 'Discrete non-synchronous peaks at BPFI harmonics with 1X sidebands',
                                     description: 'Fatigue spalling on the rotating inner ring raceway producing discrete BPFI harmonics.'),
  'ISO14224-MECH-UNBAL-1X' => upsert(FailureMode, { organization: org, iso_code: 'ISO14224-MECH-UNBAL-1X' },
                                     failure_name: 'Rotor Unbalance',
                                     equipment_category: 'General Rotating Machinery',
                                     severity_weight: 0.65,
                                     detection_signature: 'Dominant 1X running speed amplitude with low axial content',
                                     description: 'Mass eccentricity producing a dominant 1X running-speed vibration component.')
}

# ---------------------------------------------------------------------------
# Historian connectors
# ---------------------------------------------------------------------------

connectors = {
  'PI Primary' => upsert(HistorianConnector, { organization: org, connector_name: 'PI Primary' },
                         historian_type: 'OSIsoft_PI',
                         protocol_type: 'PI Web API',
                         endpoint_url: 'pi01.ot.local',
                         server_address: '10.120.44.15', port: 5450,
                         polling_interval_seconds: 5, status: 'Connected',
                         last_heartbeat: now, poll_latency_ms: 380,
                         buffer_depth: 0, backfill_queue: 0,
                         backfill_committed: 1_284_500, backfill_total: 1_284_500,
                         ring_buffer_enabled: true, connection_timeout_ms: 3000,
                         credentials_ref: 'vault://ot/pi-primary'),
  'PHD Backup' => upsert(HistorianConnector, { organization: org, connector_name: 'PHD Backup' },
                         historian_type: 'Honeywell_PHD',
                         protocol_type: 'OPC HDA',
                         endpoint_url: 'phd02.ot.local',
                         server_address: '10.120.45.20', port: 3150,
                         polling_interval_seconds: 10, status: 'Connected',
                         last_heartbeat: now, poll_latency_ms: 742,
                         buffer_depth: 0, backfill_queue: 0,
                         backfill_committed: 640_120, backfill_total: 640_120,
                         ring_buffer_enabled: true, connection_timeout_ms: 3000,
                         credentials_ref: 'vault://ot/phd-backup'),
  'Exaquantum Utilities' => upsert(HistorianConnector, { organization: org, connector_name: 'Exaquantum Utilities' },
                                   historian_type: 'Yokogawa_Exaquantum',
                                   protocol_type: 'OPC UA Secure Binary',
                                   endpoint_url: 'exq01.ot.local',
                                   server_address: '10.120.46.10', port: 4840,
                                   polling_interval_seconds: 5, status: 'Connected',
                                   last_heartbeat: now, poll_latency_ms: 402,
                                   buffer_depth: 0, backfill_queue: 0,
                                   backfill_committed: 210_000, backfill_total: 210_000,
                                   ring_buffer_enabled: true, connection_timeout_ms: 3000,
                                   credentials_ref: 'vault://ot/exaquantum')
}

# ---------------------------------------------------------------------------
# Assets — PRD sample_data + the locked prototype's narrative rows
# ---------------------------------------------------------------------------

asset_rows = [
  # Prototype narrative hero rows.
  { tag: 'P-204A', name: 'Crude charge pump A', unit: 'CDU-1',
    equipment_class: 'Centrifugal Pump', equipment_type: 'Centrifugal Pump (Overhung OH2)',
    driver_type: 'Electric Motor', criticality_class: 'Production critical',
    manufacturer: 'Sulzer', commissioned_on: Date.new(2018, 3, 18),
    rated_rpm: 1795.0, design_speed_rpm: 1795.0, rated_flow_m3h: 1_240.0,
    max_bearing_temp_c: 95.0,
    bearing_type: 'SKF 7314 BECBM Angular Contact & 6314 Deep Groove',
    bearing_de_model: 'SKF 6314 C3', bearing_nde_model: 'SKF 7314 BECBM',
    seal_plan: 'API Plan 53B (Pressurized Barrier System)',
    operating_status: 'Degraded', health_state: 'Trip',
    health_index: 28.0, health_index_delta: -33.0,
    rms_velocity_mms: 8.42, rms_velocity_delta_pct: 41.0,
    bearing_temp_c: 96.0, bearing_temp_delta_c: 11.4, motor_current_a: 318.0,
    estimated_rul_days: 8.5, estimated_rul_window: '6–11 d',
    last_sample_at: now - 12.seconds, data_completeness_pct: 98.4,
    hierarchy_path: 'BRR Complex / CDU-1 / Charge Train A / P-204A' },
  { tag: 'P-204B', name: 'Crude charge pump B (standby)', unit: 'CDU-1',
    equipment_class: 'Centrifugal Pump', equipment_type: 'Centrifugal Pump (Overhung OH2)',
    driver_type: 'Electric Motor', criticality_class: 'Production critical',
    manufacturer: 'Sulzer', commissioned_on: Date.new(2018, 3, 18),
    rated_rpm: 1795.0, design_speed_rpm: 1795.0, rated_flow_m3h: 1_240.0,
    max_bearing_temp_c: 95.0,
    bearing_type: 'SKF 7314 BECBM Angular Contact & 6314 Deep Groove',
    bearing_de_model: 'SKF 6314 C3', bearing_nde_model: 'SKF 7314 BECBM',
    seal_plan: 'API Plan 53B (Pressurized Barrier System)',
    operating_status: 'Standby', health_state: 'Normal',
    health_index: 96.0, health_index_delta: 0.4,
    rms_velocity_mms: 1.12, rms_velocity_delta_pct: 0.3,
    bearing_temp_c: 41.0, bearing_temp_delta_c: 0.5, motor_current_a: 0.0,
    estimated_rul_days: 365.0, estimated_rul_window: '365 d',
    last_sample_at: now - 18.seconds, data_completeness_pct: 99.4,
    hierarchy_path: 'BRR Complex / CDU-1 / Charge Train A / P-204B' },
  { tag: 'C-101B', name: 'Wet gas compressor B', unit: 'FCC-2',
    equipment_class: 'Centrifugal Compressor', equipment_type: 'Two-Stage Wet Gas Centrifugal Compressor',
    driver_type: 'Steam Turbine', criticality_class: 'Production critical',
    manufacturer: 'Siemens', commissioned_on: Date.new(2016, 9, 2),
    rated_rpm: 6800.0, design_speed_rpm: 6800.0, rated_flow_m3h: 24_000.0,
    max_bearing_temp_c: 105.0,
    bearing_type: 'Tilting Pad Journal',
    bearing_de_model: 'Tilting Pad', bearing_nde_model: 'Tilting Pad',
    seal_plan: 'API Plan 32/54 Dry Gas Seal (Tandem)',
    operating_status: 'Running', health_state: 'Alert',
    health_index: 54.0, health_index_delta: -8.5,
    rms_velocity_mms: 5.18, rms_velocity_delta_pct: 18.2,
    bearing_temp_c: 82.0, bearing_temp_delta_c: 5.1, motor_current_a: 0.0,
    estimated_rul_days: 22.0, estimated_rul_window: '18–26 d',
    last_sample_at: now - 18.seconds, data_completeness_pct: 97.1,
    hierarchy_path: 'BRR Complex / FCC-2 / Wet Gas Compression Train / C-101B' },
  { tag: 'P-108C', name: 'Hydrotreater feed pump C', unit: 'HCU-3',
    equipment_class: 'Centrifugal Pump', equipment_type: 'Multistage Centrifugal Pump (BB3)',
    driver_type: 'Electric Motor', criticality_class: 'Production critical',
    manufacturer: 'Flowserve', commissioned_on: Date.new(2019, 6, 11),
    rated_rpm: 3560.0, design_speed_rpm: 3560.0, rated_flow_m3h: 680.0,
    max_bearing_temp_c: 98.0,
    bearing_type: 'Sleeve Radial & Kingsbury Double Tilting Pad',
    bearing_de_model: 'SKF 6314 C3', bearing_nde_model: 'SKF 6314 C3',
    seal_plan: 'API Plan 23 (Mechanical Seal with Pumping Ring)',
    operating_status: 'Running', health_state: 'Normal',
    health_index: 84.0, health_index_delta: -1.4,
    rms_velocity_mms: 2.61, rms_velocity_delta_pct: 4.1,
    bearing_temp_c: 71.0, bearing_temp_delta_c: 1.2, motor_current_a: 224.0,
    estimated_rul_days: 126.0, estimated_rul_window: '112–140 d',
    last_sample_at: now - 31.seconds, data_completeness_pct: 99.1,
    hierarchy_path: 'BRR Complex / HCU-3 / Feed Train C / P-108C' },
  { tag: 'M-44', name: 'Charge pump drive motor', unit: 'CDU-1',
    equipment_class: 'Electric Motor', equipment_type: 'Induction Motor',
    driver_type: 'Electric Motor', criticality_class: 'Production critical',
    manufacturer: 'Siemens', commissioned_on: Date.new(2018, 3, 18),
    rated_rpm: 1790.0, design_speed_rpm: 1790.0, rated_flow_m3h: nil,
    max_bearing_temp_c: 90.0,
    bearing_type: 'SKF 6314 C3',
    bearing_de_model: 'SKF 6314 C3', bearing_nde_model: 'SKF 6314 C3',
    seal_plan: 'TEFC',
    operating_status: 'Running', health_state: 'Alert',
    health_index: 68.0, health_index_delta: -6.2,
    rms_velocity_mms: 3.42, rms_velocity_delta_pct: 12.6,
    bearing_temp_c: 74.0, bearing_temp_delta_c: 4.0, motor_current_a: 341.0,
    estimated_rul_days: 61.0, estimated_rul_window: '48–74 d',
    last_sample_at: now - 14.seconds, data_completeness_pct: 96.2,
    hierarchy_path: 'BRR Complex / CDU-1 / Charge Train A / M-44' },

  # PRD sample_data rows.
  { tag: 'P-101A', name: 'Crude Distillation Charge Pump A', unit: 'CDU-1',
    equipment_class: 'Centrifugal Pump', equipment_type: 'Centrifugal Pump (Overhung OH2)',
    driver_type: 'Electric Motor', criticality_class: 'A - Severe/Critical',
    manufacturer: 'Sulzer', commissioned_on: Date.new(2015, 4, 1),
    rated_rpm: 2980.0, design_speed_rpm: 2980.0, rated_flow_m3h: 1_500.0,
    max_bearing_temp_c: 95.0,
    bearing_type: 'SKF 7314 BECBM Angular Contact & 6314 Deep Groove',
    bearing_de_model: 'SKF 7314 BECBM', bearing_nde_model: 'SKF 7314 BECBM',
    seal_plan: 'API Plan 53B (Pressurized Barrier System)',
    operating_status: 'Degraded', health_state: 'Alarm',
    health_index: 61.0, health_index_delta: -33.0,
    rms_velocity_mms: 7.82, rms_velocity_delta_pct: 29.5,
    bearing_temp_c: 93.4, bearing_temp_delta_c: 9.1, motor_current_a: 302.0,
    estimated_rul_days: 18.5, estimated_rul_window: '14–22 d',
    last_sample_at: now - 9.seconds, data_completeness_pct: 98.9,
    hierarchy_path: 'BRR Complex / CDU-1 / Crude Feed Pumping Train / P-101A' },
  { tag: 'P-101B', name: 'Crude Charge Pump B (standby)', unit: 'CDU-1',
    equipment_class: 'Centrifugal Pump', equipment_type: 'Centrifugal Pump (Overhung OH2)',
    driver_type: 'Electric Motor', criticality_class: 'A - Severe/Critical',
    manufacturer: 'Sulzer', commissioned_on: Date.new(2015, 4, 1),
    rated_rpm: 2980.0, design_speed_rpm: 2980.0, rated_flow_m3h: 1_500.0,
    max_bearing_temp_c: 95.0,
    bearing_type: 'SKF 7314 BECBM Angular Contact & 6314 Deep Groove',
    bearing_de_model: 'SKF 7314 BECBM', bearing_nde_model: 'SKF 7314 BECBM',
    seal_plan: 'API Plan 53B (Pressurized Barrier System)',
    operating_status: 'Standby', health_state: 'Normal',
    health_index: 95.0, health_index_delta: 0.0,
    rms_velocity_mms: 1.04, rms_velocity_delta_pct: 0.2,
    bearing_temp_c: 39.0, bearing_temp_delta_c: 0.2, motor_current_a: 0.0,
    estimated_rul_days: 365.0, estimated_rul_window: '365 d',
    last_sample_at: now - 20.seconds, data_completeness_pct: 99.6,
    hierarchy_path: 'BRR Complex / CDU-1 / Crude Feed Pumping Train / P-101B' },
  { tag: 'K-301', name: 'Hydrogen Recycle Compressor', unit: 'HCU-3',
    equipment_class: 'Centrifugal Compressor', equipment_type: 'Multistage Centrifugal Compressor',
    driver_type: 'Steam Turbine', criticality_class: 'A - Severe/Critical',
    manufacturer: 'Mitsubishi', commissioned_on: Date.new(2017, 11, 20),
    rated_rpm: 10_450.0, design_speed_rpm: 10_450.0, rated_flow_m3h: 88_000.0,
    max_bearing_temp_c: 108.0,
    bearing_type: 'Tilting Pad Journal & Active Magnetic Thrust',
    bearing_de_model: 'Tilting Pad', bearing_nde_model: 'Tilting Pad',
    seal_plan: 'API Plan 32/54 Dry Gas Seal (Tandem)',
    operating_status: 'Running', health_state: 'Normal',
    health_index: 88.5, health_index_delta: -0.8,
    rms_velocity_mms: 1.96, rms_velocity_delta_pct: 2.1,
    bearing_temp_c: 78.0, bearing_temp_delta_c: 0.9, motor_current_a: 0.0,
    estimated_rul_days: 210.0, estimated_rul_window: '190–230 d',
    last_sample_at: now - 11.seconds, data_completeness_pct: 99.2,
    hierarchy_path: 'BRR Complex / HCU-3 / Recycle Gas Compression / K-301' },
  { tag: 'P-402', name: 'Boiler Feed Water Pump B', unit: 'ALKY-4',
    equipment_class: 'Centrifugal Pump', equipment_type: 'Multistage Centrifugal Pump (BB3)',
    driver_type: 'Electric Motor', criticality_class: 'A - Severe/Critical',
    manufacturer: 'KSB', commissioned_on: Date.new(2014, 7, 30),
    rated_rpm: 3550.0, design_speed_rpm: 3550.0, rated_flow_m3h: 420.0,
    max_bearing_temp_c: 96.0,
    bearing_type: 'Sleeve Radial & Kingsbury Double Tilting Pad',
    bearing_de_model: 'SKF 6314 C3', bearing_nde_model: 'SKF 6314 C3',
    seal_plan: 'API Plan 23 (Mechanical Seal with Pumping Ring)',
    operating_status: 'Running', health_state: 'Normal',
    health_index: 95.0, health_index_delta: 0.1,
    rms_velocity_mms: 1.31, rms_velocity_delta_pct: 0.4,
    bearing_temp_c: 62.0, bearing_temp_delta_c: 0.3, motor_current_a: 187.0,
    estimated_rul_days: 340.0, estimated_rul_window: '320–360 d',
    last_sample_at: now - 25.seconds, data_completeness_pct: 99.8,
    hierarchy_path: 'BRR Complex / ALKY-4 / BFW Train B / P-402' },
  { tag: 'KT-201', name: 'Wet Gas Compressor Steam Turbine Driver', unit: 'FCC-2',
    equipment_class: 'Steam Turbine', equipment_type: 'Multistage Reaction Steam Turbine',
    driver_type: 'Steam Turbine', criticality_class: 'A - Severe/Critical',
    manufacturer: 'Elliott', commissioned_on: Date.new(2016, 9, 2),
    rated_rpm: 6800.0, design_speed_rpm: 6800.0, rated_flow_m3h: nil,
    max_bearing_temp_c: 110.0,
    bearing_type: 'Tilting Pad Radial with Spherical Pivot',
    bearing_de_model: 'Tilting Pad', bearing_nde_model: 'Tilting Pad',
    seal_plan: 'Steam Labyrinth with Gland Condenser',
    operating_status: 'Running', health_state: 'Alert',
    health_index: 64.7, health_index_delta: -12.1,
    rms_velocity_mms: 4.65, rms_velocity_delta_pct: 15.8,
    bearing_temp_c: 88.0, bearing_temp_delta_c: 6.3, motor_current_a: 0.0,
    estimated_rul_days: 42.0, estimated_rul_window: '36–48 d',
    last_sample_at: now - 15.seconds, data_completeness_pct: 97.4,
    hierarchy_path: 'BRR Complex / FCC-2 / Main Air Blower Train / KT-201' }
]

assets = {}
asset_rows.each do |row|
  unit = units.fetch(row[:unit])
  assets[row[:tag]] = upsert(
    Asset, { organization: org, asset_tag: row[:tag] },
    row.except(:tag, :unit, :name).merge(asset_name: row[:name],
                                         plant_unit_id: unit.id,
                                         monitored: true)
  )
end

# Standby twins point at their lead machine.
assets['P-204B'].update!(parent_asset_id: nil)
assets['P-101A'].update!(parent_asset_id: nil)

upsert(Asset, { organization: other_org, asset_tag: 'X-900A' },
       asset_name: 'Isolation fixture pump', equipment_class: 'Centrifugal Pump',
       equipment_type: 'Centrifugal Pump (Overhang)', driver_type: 'Electric Motor',
       criticality_class: 'B - Essential', manufacturer: 'Sulzer',
       rated_rpm: 2980.0, design_speed_rpm: 2980.0,
       bearing_de_model: 'SKF 6314 C3', bearing_nde_model: 'SKF 6314 C3',
       bearing_type: 'SKF 6314 C3', seal_plan: 'API Plan 11',
       operating_status: 'Running', health_state: 'Normal', health_index: 91.0,
       rms_velocity_mms: 1.84, bearing_temp_c: 58.0,
       estimated_rul_window: '220–240 d', last_sample_at: now,
       data_completeness_pct: 99.0, monitored: true,
       hierarchy_path: 'Other Refinery / ALKY-4 / X-900A')

# The isolation tenant must be able to prove row-level tenancy for EVERY
# resource the runtime contract can select as its CRUD carrier, so the second
# organization owns at least one row of each candidate resource. Without them a
# cross-tenant list is legitimately empty and tenancy isolation cannot be shown.
isolation_asset = Asset.find_by!(organization: other_org, asset_tag: 'X-900A')

upsert(AssetComponent, { organization: other_org, asset: isolation_asset, component_name: 'Isolation fixture bearing' },
       component_type: 'Rolling Element Bearing', position: 'Pump DE',
       bearing_model: 'SKF 6314 C3', seal_type: 'Mechanical Seal API 682',
       health_state: 'Normal')

upsert(AssetHealthIndex, { organization: other_org, asset: isolation_asset, calculated_at: now },
       health_score: 91.0, anomaly_confidence: 0.03,
       contributing_factors_json: { 'vib_de_env' => { 'status' => 'normal', 'weight' => 1.0, 'z_score' => 0.2 } })

# ---------------------------------------------------------------------------
# Asset components
# ---------------------------------------------------------------------------

component_rows = [
  [ 'P-204A', 'Outboard Bearing', 'Angular Contact Ball Bearing Pair', 'Pump OB', 'SKF 7314 BECBM', 'Cartridge Seal API 682', 'Alarm' ],
  [ 'P-204A', 'Drive End Radial Bearing', 'Rolling Element Bearing', 'Pump DE', 'SKF 6314 C3', nil, 'Normal' ],
  [ 'P-204A', 'Primary Cartridge Seal', 'Mechanical Seal API 682', 'Stuffing Box DE', nil, 'API 682 Type A', 'Normal' ],
  [ 'P-101A', 'Drive End Radial Bearing', 'Rolling Element Bearing', 'Pump DE', 'SKF 7314 BECBM', nil, 'Alarm' ],
  [ 'P-101A', 'Non-Drive End Thrust Bearing', 'Angular Contact Ball Bearing Pair', 'Pump NDE', 'SKF 7314 BECBM', nil, 'Alert' ],
  [ 'P-101A', 'Primary Cartridge Seal', 'Mechanical Seal API 682', 'Stuffing Box DE', nil, 'API 682 Type A', 'Normal' ],
  [ 'C-101B', 'Compressor Inboard Journal Bearing', 'Hydrodynamic Tilting Pad Bearing', 'Compressor IB', 'Tilting Pad', nil, 'Alert' ],
  [ 'C-101B', 'High Pressure Tandem Dry Gas Seal', 'Dry Gas Seal Cartridge', 'Discharge End Seal Cavity', nil, 'Tandem DGS', 'Normal' ],
  [ 'K-301', 'Compressor Inboard Journal Bearing', 'Hydrodynamic Tilting Pad Bearing', 'Compressor IB', 'Tilting Pad', nil, 'Normal' ],
  [ 'K-301', 'High Pressure Tandem Dry Gas Seal', 'Dry Gas Seal Cartridge', 'Discharge End Seal Cavity', nil, 'Tandem DGS', 'Normal' ],
  [ 'KT-201', 'Turbine Governor Valve Actuator', 'Hydraulic Trip/Throttle Assembly', 'Steam Chest Inflow', nil, nil, 'Alert' ],
  [ 'P-108C', 'Hydrotreater Feed Pump Drive End Bearing', 'Rolling Element Bearing', 'Pump DE', 'SKF 6314 C3', nil, 'Normal' ],
  [ 'M-44', 'Motor Drive End Bearing', 'Rolling Element Bearing', 'Motor DE', 'SKF 6314 C3', nil, 'Alert' ],
  [ 'P-402', 'Kingsbury Thrust Bearing', 'Double Tilting Pad Thrust Bearing', 'Pump Thrust', 'Kingsbury', nil, 'Normal' ]
]

components = {}
component_rows.each do |asset_tag, name, type, position, bearing_model, seal_type, health_state|
  key = "#{asset_tag}:#{name}"
  components[key] = upsert(
    AssetComponent, { organization: org, asset: assets[asset_tag], component_name: name },
    component_type: type, position: position, bearing_model: bearing_model,
    seal_type: seal_type, health_state: health_state
  )
end

# ---------------------------------------------------------------------------
# Historian tags
# ---------------------------------------------------------------------------

tag_rows = [
  [ 'PI:P204A.VIB.OH', 'P204A.VIB.OH', 'P-204A', 'P-204A:Outboard Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.10, 1.0, 'Good', 8.42, 8, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P204A.VIB.OV', 'P204A.VIB.OV', 'P-204A', 'P-204A:Outboard Bearing', 'Overall Vibration Velocity Vertical', 'mm/s', 1000, 0.10, 1.0, 'Good', 6.91, 8, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P204A.VIB.AX', 'P204A.VIB.AX', 'P-204A', 'P-204A:Outboard Bearing', 'Overall Vibration Velocity Axial', 'mm/s', 1000, 0.10, 1.0, 'Good', 4.22, 9, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P204A.TI.OB', 'P204A.TI.OB', 'P-204A', 'P-204A:Outboard Bearing', 'Bearing Metal Temperature', 'degC', 10_000, 0.5, 0.1, 'Good', 96.0, 11, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P204A.II.MTR', 'P204A.II.MTR', 'P-204A', 'P-204A:Drive End Radial Bearing', 'Motor Current', 'A', 1000, 0.2, 1.0, 'Good', 318.0, 6, 'Mapped', true, 'PI Primary' ],
  [ 'PI:C101B.VIB.IB', 'C101B.VIB.IB', 'C-101B', 'C-101B:Compressor Inboard Journal Bearing', 'Radial Shaft Relative Displacement', 'um pk-pk', 1000, 1.0, 1.0, 'Good', 32.1, 12, 'Mapped', true, 'PI Primary' ],
  [ 'PHD:C101B.DGS.VENT', 'C101B.DGS.VENT', 'C-101B', 'C-101B:High Pressure Tandem Dry Gas Seal', 'Dry Gas Seal Primary Leakage Vent Flow', 'Nm3/h', 5000, 0.05, 0.2, 'Good', 1.85, 14, 'Mapped', true, 'PHD Backup' ],
  [ 'PI:K301.VIB.IB', 'K301.VIB.IB', 'K-301', 'K-301:Compressor Inboard Journal Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 1.96, 10, 'Mapped', true, 'PI Primary' ],
  [ 'PI:KT201.STEAM.CHEST', 'KT201.STEAM.CHEST', 'KT-201', 'KT-201:Turbine Governor Valve Actuator', 'Steam Chest Inlet Pressure', 'barg', 1000, 0.2, 1.0, 'Good', 42.6, 13, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P108C.VIB.DE', 'P108C.VIB.DE', 'P-108C', 'P-108C:Hydrotreater Feed Pump Drive End Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 2.61, 15, 'Mapped', true, 'PI Primary' ],
  [ 'PI:M44.VIB.DE', 'M44.VIB.DE', 'M-44', 'M-44:Motor Drive End Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 3.42, 16, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P204B.VIB.OB', 'P204B.VIB.OB', 'P-204B', 'P-204A:Outboard Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 1.12, 18, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P204B.TI.OB', 'P204B.TI.OB', 'P-204B', 'P-204A:Outboard Bearing', 'Bearing Metal Temperature', 'degC', 10_000, 0.5, 0.1, 'Good', 41.0, 18, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P101A.VIB.DE', 'P101A.VIB.DE', 'P-101A', 'P-101A:Drive End Radial Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 7.82, 9, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P101A.TI.DE', 'P101A.TI.DE', 'P-101A', 'P-101A:Drive End Radial Bearing', 'Bearing Metal Temperature', 'degC', 10_000, 0.5, 0.1, 'Good', 93.4, 9, 'Mapped', true, 'PI Primary' ],
  [ 'PI:P101B.VIB.DE', 'P101B.VIB.DE', 'P-101B', 'P-101A:Drive End Radial Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 1.04, 20, 'Mapped', true, 'PI Primary' ],
  [ 'PHD:P402.VIB.DE', 'P402.VIB.DE', 'P-402', 'P-402:Kingsbury Thrust Bearing', 'Overall Vibration Velocity Horizontal', 'mm/s', 1000, 0.1, 1.0, 'Good', 1.31, 25, 'Mapped', true, 'PHD Backup' ],
  [ 'PHD:P402.TI.THRUST', 'P402.TI.THRUST', 'P-402', 'P-402:Kingsbury Thrust Bearing', 'Thrust Bearing Metal Temperature', 'degC', 10_000, 0.5, 0.1, 'Good', 62.0, 25, 'Mapped', true, 'PHD Backup' ],
  [ 'PI:K301.TI.IB', 'K301.TI.IB', 'K-301', 'K-301:Compressor Inboard Journal Bearing', 'Journal Bearing Metal Temperature', 'degC', 10_000, 0.5, 0.1, 'Good', 78.0, 11, 'Mapped', true, 'PI Primary' ],
  [ 'PI:KT201.STEAM.TEMP', 'KT201.STEAM.TEMP', 'KT-201', 'KT-201:Turbine Governor Valve Actuator', 'Steam Chest Inlet Temperature', 'degC', 10_000, 1.0, 0.1, 'Good', 462.0, 13, 'Mapped', true, 'PI Primary' ],
  # Deliberately bad rows — the tag-mapping table's red-row contract.
  [ 'PI:P204A.VIB.OB', 'P204A.VIB.OB', 'P-204A', 'P-204A:Outboard Bearing', 'High Frequency Demodulated Acceleration', 'g pk-pk', 100, 0.01, 10.0, 'Bad - 0 (OPC Quality)', 4.65, 412, 'Mapped', false, 'PI Primary' ],
  [ 'PHD:ALKY4.BFW.PRESS', 'ALKY4.BFW.PRESS', nil, nil, 'Boiler Feed Water Discharge Pressure', 'barg', 5000, 0.2, 0.2, 'Bad - 0 (OPC Quality)', nil, 980, 'Unmapped', false, 'PHD Backup' ]
]

historian_tags = {}
tag_rows.each do |tag_path, source, asset_tag, component_key, measurement, unit, scan_ms,
                   deadband, scan_hz, quality, last_value, stale_seconds, mapping_state,
                   compatible, connector_name|
  historian_tags[tag_path] = upsert(
    HistorianTag, { organization: org, tag_path: tag_path },
    source_tag_name: source,
    asset_id: asset_tag && assets[asset_tag].id,
    asset_component_id: component_key && components[component_key]&.id,
    historian_connector_id: connectors[connector_name].id,
    historian_type: connectors[connector_name].historian_type,
    measurement_type: measurement, engineering_unit: unit, scan_rate_ms: scan_ms,
    deadband_val: deadband, scan_frequency_hz: scan_hz, quality_status: quality,
    last_value: last_value,
    last_validated_at: now - stale_seconds.seconds,
    stale_seconds: stale_seconds, mapped: true, mapping_state: mapping_state,
    compatible: compatible
  )
end

# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------

telemetry_series = {
  'PI:P204A.VIB.OH' => [ 7.10, 7.22, 7.45, 7.61, 7.88, 8.02, 8.19, 8.42 ],
  'PI:P204A.TI.OB' => [ 88.0, 89.4, 90.1, 91.8, 92.6, 93.9, 95.2, 96.0 ],
  'PI:P204A.II.MTR' => [ 301.0, 303.0, 306.0, 309.0, 311.0, 314.0, 316.0, 318.0 ],
  'PHD:C101B.DGS.VENT' => [ 1.20, 1.28, 1.35, 1.44, 1.55, 1.66, 1.75, 1.85 ],
  'PI:KT201.STEAM.CHEST' => [ 43.4, 43.1, 43.0, 42.9, 42.8, 42.7, 42.6, 42.6 ]
}

telemetry_series.each do |tag_path, values|
  tag = historian_tags.fetch(tag_path)
  values.each_with_index do |value, index|
    recorded_at = (now - ((values.length - 1 - index) * 6).hours).change(min: 0, sec: 0)
    upsert(TelemetryRecord, { organization: org, historian_tag_id: tag.id, recorded_at: recorded_at },
           recorded_value: value, data_quality_flag: 'Good - 192 (OPC Quality)')
  end
end

puts "Seeded demo plant data: #{Asset.where(organization: org).count} assets, " \
     "#{HistorianTag.where(organization: org).count} historian tags"
