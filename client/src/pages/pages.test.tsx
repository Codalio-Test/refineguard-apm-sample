// @vitest-environment jsdom
/**
 * Workspace smoke coverage.
 *
 * Every page and shared component is rendered with mocked Rhino hooks and a
 * fixture per resource, then a second pass with empty fixtures, so both the
 * populated and the empty branches of each render are exercised.
 */
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import React from 'react';
import { cleanup, render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const rhino = vi.hoisted(() => {
  const state: { rows: Record<string, unknown[]> } = { rows: {} };
  const mutation = () => ({
    mutate: vi.fn(),
    mutateAsync: vi.fn(async () => ({})),
    isPending: false,
    isSuccess: false,
    isError: false,
    error: null,
    data: null,
    reset: vi.fn(),
  });
  return {
    state,
    mutation,
    api: {
      get: vi.fn(async (url: string) => {
        if (String(url).includes('/dashboard/active_anomalies')) return { data: [] };
        if (String(url).includes('/assets/hierarchy')) return { data: { tree: [] } };
        return { data: {} };
      }),
      post: vi.fn(async () => ({ data: {} })),
      put: vi.fn(async () => ({ data: {} })),
      delete: vi.fn(async () => ({ data: {} })),
    },
  };
});

vi.mock('@rhino-dev/rhino-react', () => ({
  useModelIndex: (model: string) => ({
    data: { data: rhino.state.rows[model] ?? [], pagination: null },
    isLoading: false,
    error: null,
  }),
  useModelShow: () => ({ data: null, isLoading: false, error: null }),
  useModelStore: () => rhino.mutation(),
  useModelUpdate: () => rhino.mutation(),
  useModelDelete: () => rhino.mutation(),
  useModelTrashed: () => ({ data: { data: [], pagination: null }, isLoading: false, error: null }),
  useModelRestore: () => rhino.mutation(),
  useModelForceDelete: () => rhino.mutation(),
  useNestedOperations: () => rhino.mutation(),
  useAuth: () => ({
    isAuthenticated: true,
    token: 'token',
    login: vi.fn(async () => ({ success: true, organization_slug: 'demo-org', user: { role_slugs: ['admin'] } })),
    logout: vi.fn(),
    setOrganization: vi.fn(),
  }),
  useOrganization: () => 'demo-org',
  api: rhino.api,
  events: { subscribe: vi.fn(() => () => {}), emit: vi.fn() },
  setOrganization: vi.fn(),
  configureApi: vi.fn(),
}));

// jsdom ships neither ResizeObserver nor matchMedia; the shadcn primitives and
// the shell theme toggle use both.
if (!('ResizeObserver' in globalThis)) {
  (globalThis as unknown as { ResizeObserver: unknown }).ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  };
}
if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: (query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    }),
  });
}

vi.mock('@/contexts/AppOwnerProvider', () => ({
  AppOwnerProvider: ({ children }: { children?: React.ReactNode }) => <>{children}</>,
}));

vi.mock('@/contexts/appOwner', () => ({
  useAppOwner: () => ({
    organizationSlug: 'demo-org',
    organization: { id: 1, slug: 'demo-org', name: 'Demo Org' },
    user: { id: 1, name: 'Ada Lovelace', email: 'ada@brr-ot.local' },
    roles: ['admin'],
    rolesLoading: false,
    hasRole: (role: string) => role === 'admin',
  }),
}));

// jsdom's CSS parser rejects some Radix inline transforms; the shadcn slider is
// presentational and excluded from coverage, so stub it for the page tests.
vi.mock('@/components/ui/slider', () => ({
  Slider: () => <div data-testid="slider" />,
}));

import Landing from '@/pages/Landing';
import Login from '@/pages/Login';
import FleetOverview from '@/pages/FleetOverview';
import Assets from '@/pages/Assets';
import AssetHealthSummary from '@/pages/AssetHealthSummary';
import AssetDiagnostics from '@/pages/AssetDiagnostics';
import SpectralAnalytics from '@/pages/SpectralAnalytics';
import PrescriptiveAdvisories from '@/pages/PrescriptiveAdvisories';
import WorkOrderConfirmation from '@/pages/WorkOrderConfirmation';
import UnitRiskMatrix from '@/pages/UnitRiskMatrix';
import OperationsShiftLog from '@/pages/OperationsShiftLog';
import ModelRetraining from '@/pages/ModelRetraining';
import ModelEvaluation from '@/pages/ModelEvaluation';
import HistorianConnections from '@/pages/HistorianConnections';
import TagMapping from '@/pages/TagMapping';
import AssetHierarchyBuilder from '@/pages/AssetHierarchyBuilder';
import SecurityAudit from '@/pages/SecurityAudit';
import SystemHealth from '@/pages/SystemHealth';
import AuthSignUp from '@/pages/AuthSignUp';
import AuthResetPassword from '@/pages/AuthResetPassword';
import AuthSignIn from '@/pages/AuthSignIn';

function seedRows() {
  rhino.state.rows = {
    assets: [
      {
        id: 'P-204A', record_id: 42, asset_tag: 'P-204A', asset_name: 'Crude charge pump A',
        name: 'Crude charge pump A', unit: 'CDU-1', severity: 'critical', status: 'Critical',
        health: 28, health_index: 28, rms: '8.42', rms_velocity_mms: 8.42, temp: '96',
        bearing_temp_c: 96, rul: '6–11 d', sample: '12s', criticality_class: 'A',
        manufacturer: 'Sulzer', commissioned_on: '2019-04-02', data_completeness_pct: 98.4,
        rated_flow_m3h: 420, rated_rpm: 1795, max_bearing_temp_c: 105, bearing_type: 'Angular contact',
        last_sample_at: new Date().toISOString(), monitored: true,
        estimated_rul_window: '6–11 d', health_index_delta: -33, bearing_temp_delta_c: 4,
        rms_velocity_delta_pct: 12, motor_current_a: 318, parent_asset_id: null,
        equipment_class: 'Centrifugal Pump', plant_unit_id: 1, hierarchy_path: 'CDU-1/P-204A',
      },
    ],
    historian_connectors: [
      { id: 1, connector_name: 'PI Primary', historian_type: 'OSIsoft_PI', protocol_type: 'PI Web API',
        status: 'Connected', poll_latency_ms: 380, buffer_depth: 4, backfill_queue: 0,
        backfill_total: 100, backfill_committed: 100, last_heartbeat: new Date().toISOString(),
        severity: 'healthy', buffer: '4 pts', latency: '380ms', state: 'Connected',
        endpoint: '10.120.44.15', quality: 'Good' },
      { id: 2, connector_name: 'PHD Secondary', historian_type: 'Honeywell_PHD', status: 'Connected',
        poll_latency_ms: 410, buffer_depth: 0, last_heartbeat: new Date().toISOString() },
    ],
    diagnostic_incidents: [
      { id: 7, asset_id: 42, incident_code: 'INC-24018', status: 'Active', severity_level: 'High',
        health_state: 'Trip', severity: 'critical', rul_days_estimate: 8.5, rul_window_low_days: 6,
        rul_window_high_days: 11, rul_window: '6–11 d', pf_interval_days: 21, regime: 'heavy',
        regime_confidence_pct: 96, root_cause: 'Outer race spall', evidence_summary: 'BPFO peaks',
        failure_mechanism: 'Bearing Outer Race Spall', finding_confidence: 0.89,
        finding_status: 'Draft', detected_at: new Date().toISOString(), record_id: 7,
        failure_mode_name: 'Bearing Outer Race Defect', asset_tag: 'P-204A',
        severity_badge: 'critical', severity_label: 'Critical', age: '2 d', issue: 'BPFO',
      },
    ],
    prescriptive_advisories: [
      { id: 11, asset_tag: 'P-204A', advisory_code: 'ADV-1', recommended_action: 'Replace bearing pair.',
        recommendation: 'Replace bearing pair.', action_steps_json: ['Isolate', 'Replace'],
        throttle_percentage: 70, parts_required_json: { bearings: ['SKF 7314'] },
        warehouse_status: 'In stock', warehouse_bin: 'C-14', parts_lead_time_days: 6,
        urgency: 'Urgent Action Required', status: 'Ready for Dispatch', due_within_days: 6,
        rul_window: '6–11 d', pf_interval_days: 21, regime_confidence_pct: 96, severity: 'critical',
        derate_recommendation: 'Reduce charge rate by 8%.', derate_approved_at: null,
        standby_ready: true, standby_asset_tag: 'P-204B', finding: 'BPFO' },
    ],
    cmms_work_orders: [
      { id: 3, asset_tag: 'P-204A', cmms_type: 'SAP PM', external_order_number: 'SAP-WO-000123',
        sync_status: 'Dispatched', priority: 'P2', required_by: '2026-01-01', dispatched_at: new Date().toISOString(),
        confirmed_at: null, error_message: null, material_reservations_json: [] },
    ],
    spectrum_snapshots: [
      { id: 1, asset_id: 42, captured_at: new Date().toISOString(), channel: 'OB Horizontal',
        line_resolution: 65536, sample_rate_hz: 1000, rms_velocity: 8.42, running_speed_hz: 29.92,
        cursor_hz: 107.2, cursor_amplitude: 0.62, cursor_order: 3.58, delta_baseline: 0.14,
        spectrum: [{ hz: 10, amplitude: 0.2 }, { hz: 107, amplitude: 0.62 }],
        harmonics: [{ order: 1, hz: 29.9 }], bearing_markers: [{ label: 'BPFO' }],
        waterfall: [1, 2, 3], orbit: [{ x_um: 10, y_um: 5 }], waterfall_horizon_days: 7 },
    ],
    failure_mode_assessments: [
      { id: 1, asset_id: 42, failure_mode_id: 1, probability: 87, confidence_low: 80,
        confidence_high: 92, marker_label: 'BPFO', expected_hz: 106.8, observed_hz: 107.2,
        amplitude: 0.62, match_score: 0.93, assessed_at: new Date().toISOString(),
        failure_mode_name: 'Bearing Outer Race Defect' },
    ],
    asset_health_indices: [
      { id: 1, asset_id: 42, calculated_at: new Date().toISOString(), health_score: 28,
        health_state: 'Trip', anomaly_confidence: 0.97, iso_severity_category: 'D',
        contributing_factors_json: {}, envelope_checks_json: [
          { key: 'vib_de_env', label: 'Vibration DE', observed: 8.42, unit: 'mm/s', breached: true },
        ],
        attribution: [{ label: 'Vibration DE', percent: 45 }], envelope_checks: [
          { label: 'Vibration DE', observed: 8.42, unit: 'mm/s', breached: true },
        ] },
    ],
    model_baselines: [
      { id: 1, model_version: 'v3.8.0-PCA-AE', algorithm_type: 'Deep Autoencoder',
        status: 'Candidate', training_status: 'Idle', training_progress: 100,
        is_active: true, accuracy_metrics_json: { precision: 0.94 }, gates_json: { max_gap: 0.01 },
        gates_satisfied: true, training_window_end: new Date().toISOString(),
        hyperparameters_json: { fft_bins: 512 }, training_log: 'ok', promoted_at: null,
        approved_by_name: 'Ada' },
    ],
    baseline_windows: [
      { id: 1, label: 'Apr 02', window_start: '2026-04-02', window_end: '2026-04-09',
        load_percent: 88, completeness_percent: 99.8, selected: true, eligible: true },
    ],
    historian_tags: [
      { id: 1, asset_id: 42, asset_tag: 'P-204A', historian_type: 'OSIsoft_PI', source_tag_name: 'P204A.VIB.OH',
        tag_path: 'PI:P204A.VIB.OH', measurement_type: 'Vibration', engineering_unit: 'mm/s',
        quality_status: 'Good', last_value: 8.42, last_validated_at: new Date().toISOString(),
        mapping_state: 'Mapped', mapped: true, scan_rate_ms: 1000, deadband_val: 0.1, stale_seconds: 8 },
    ],
    shift_log_entries: [
      { id: 1, plant_unit_id: 1, asset_id: 42, occurred_at: new Date().toISOString(),
        shift_label: 'Day shift', event_type: 'Derate approval', severity: 'warning',
        message: 'CDU-1 charge rate reduced 8%', unit_status: 'Running', outstanding_actions: 'None',
        open_risks: 'None', steps_completed: 0, steps_total: 2, procedure_steps_json: ['Step 1'],
        incoming_ack: true, handover_completed_at: null, author_name: 'Ada' },
    ],
    security_audit_events: [
      { id: 1, recorded_at: new Date().toISOString(), severity: 'info', actor_name: 'ada@brr-ot.local',
        actor_role: 'admin', action_type: 'AUTH_LOGIN', entity_affected: 'ada@brr-ot.local',
        source_host: '10.0.0.1', result: 'Success', tamper_proof_hash: 'abc', previous_hash: null,
        tamper_proof: true, details_json: { mode: 'simulated' } },
    ],
    plant_units: [
      { id: 1, unit_code: 'CDU-1', unit_name: 'Crude Distillation Unit 1', unit_type: 'CDU',
        refinery_area: 'North', rate_percent: 92, exposure_usd_per_day: '418000.00',
        throughput_target_bpd: 120000, derate_recommendation: 'Reduce charge rate by 8%.',
        name: 'CDU-1', exposure_percent: 92, assets_count: 2 },
    ],
    failure_modes: [
      { id: 1, iso_code: 'ISO14224-MECH-BRG-BPFO', failure_name: 'Bearing Outer Race Defect',
        equipment_category: 'Centrifugal Pump', severity_weight: 0.85, description: 'BPFO' },
    ],
    asset_components: [
      { id: 1, asset_id: 42, component_name: 'Outboard Bearing', component_type: 'Angular contact',
        position: 'OB', bearing_model: 'SKF 7314', seal_type: 'Plan 11', health_state: 'Alarm',
        severity: 'warning' },
    ],
  };
}

function renderRoute(ui: React.ReactElement, path = '/', entry = '/') {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[entry]}>
        <Routes>
          <Route path={path} element={ui} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

const PAGES: Array<{ name: string; element: React.ReactElement; path?: string; entry?: string }> = [
  { name: 'Landing', element: <Landing /> },
  { name: 'Login', element: <Login /> },
  { name: 'FleetOverview', element: <FleetOverview /> },
  { name: 'Assets', element: <Assets />, path: '/assets', entry: '/assets' },
  { name: 'AssetHealthSummary', element: <AssetHealthSummary />, path: '/assets/:assetId/health-summary', entry: '/assets/P-204A/health-summary' },
  { name: 'AssetDiagnostics', element: <AssetDiagnostics />, path: '/assets/:assetId/diagnostics', entry: '/assets/P-204A/diagnostics' },
  { name: 'SpectralAnalytics', element: <SpectralAnalytics />, path: '/assets/:assetId/spectral-analytics', entry: '/assets/P-204A/spectral-analytics' },
  { name: 'PrescriptiveAdvisories', element: <PrescriptiveAdvisories /> },
  { name: 'WorkOrderConfirmation', element: <WorkOrderConfirmation /> },
  { name: 'UnitRiskMatrix', element: <UnitRiskMatrix /> },
  { name: 'OperationsShiftLog', element: <OperationsShiftLog /> },
  { name: 'ModelRetraining', element: <ModelRetraining /> },
  { name: 'ModelEvaluation', element: <ModelEvaluation /> },
  { name: 'HistorianConnections', element: <HistorianConnections /> },
  { name: 'TagMapping', element: <TagMapping /> },
  { name: 'AssetHierarchyBuilder', element: <AssetHierarchyBuilder /> },
  { name: 'SecurityAudit', element: <SecurityAudit /> },
  { name: 'SystemHealth', element: <SystemHealth /> },
  { name: 'AuthSignIn', element: <AuthSignIn /> },
  { name: 'AuthSignUp', element: <AuthSignUp /> },
  { name: 'AuthResetPassword', element: <AuthResetPassword />, path: '/auth/reset-password', entry: '/auth/reset-password?token=tok' },
];

describe('workspace pages', () => {
  beforeEach(() => {
    seedRows();
    vi.clearAllMocks();
  });

  afterEach(() => {
    cleanup();
  });

  it.each(PAGES.map((page) => [page.name, page] as const))('renders %s with data', async (_name, page) => {
    const { container } = renderRoute(page.element, page.path ?? '/', page.entry ?? '/');
    await waitFor(() => expect(container.firstChild).not.toBeNull());
    expect(container.textContent).toBeTruthy();
  });

  it.each(PAGES.map((page) => [page.name, page] as const))('renders %s with empty data', async (_name, page) => {
    rhino.state.rows = {};
    const { container } = renderRoute(page.element, page.path ?? '/', page.entry ?? '/');
    await waitFor(() => expect(container.firstChild).not.toBeNull());
    expect(container.textContent).toBeTruthy();
  });

  it('submits the sign-in form and validates an empty credential', async () => {
    renderRoute(<Login />, '/login', '/login');
    const form = document.querySelector('form')!;
    fireEvent.submit(form);
    await waitFor(() => expect(document.body.textContent).toMatch(/username/i));
  });

  it('validates the invitation form before posting', async () => {
    renderRoute(<AuthSignUp />, '/auth/signup', '/auth/signup');
    fireEvent.submit(document.querySelector('form')!);
    await waitFor(() => expect(document.body.textContent).toMatch(/invitation token/i));
  });

  it('starts a password recovery without a token', async () => {
    renderRoute(<AuthResetPassword />, '/auth/reset-password', '/auth/reset-password');
    fireEvent.change(document.querySelector('#reset-email')!, { target: { value: 'operator@brr-ot.local' } });
    fireEvent.submit(document.querySelector('form')!);
    await waitFor(() => expect(rhino.api.post).toHaveBeenCalled());
  });

  it('confirms and dispatches a work order', async () => {
    rhino.state.rows.cmms_work_orders = [
      { id: 3, cmms_type: 'SAP PM', sync_status: 'Pending Sync', asset_tag: 'P-204A', priority: 'P2' },
    ];
    renderRoute(<WorkOrderConfirmation />, '/work-orders/confirmation', '/work-orders/confirmation');
    const button = await screen.findByText(/Confirm and dispatch/i);
    fireEvent.click(button);
    await waitFor(() => expect(rhino.api.post).toHaveBeenCalled());
  });

  it('routes a second render pass over the components with data', async () => {
    renderRoute(<FleetOverview />, '/fleet-overview', '/fleet-overview');
    await waitFor(() => expect(document.body.textContent).toMatch(/Fleet overview/i));
  });
});
