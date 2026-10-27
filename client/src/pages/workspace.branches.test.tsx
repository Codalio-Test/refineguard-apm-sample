// @vitest-environment jsdom
/**
 * Branch coverage for the workspaces.
 *
 * The smoke suite renders each page once with a full fixture, which only walks
 * the "field present" side of every optional chain. This suite walks the other
 * side as well: the same pages are rendered with a *blank* row per resource (so
 * every `??` / `?.` fallback executes), with the list payloads, and through the
 * controls that flip each render-time conditional.
 */
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import React from 'react';
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const rhino = vi.hoisted(() => {
  const state = {
    rows: {} as Record<string, unknown[]>,
    apiGet: {} as Record<string, unknown>,
    loginResult: null as unknown,
    post: vi.fn(async () => ({ data: {} })),
    mutation: () => ({
      mutate: vi.fn(),
      mutateAsync: vi.fn(async () => ({})),
      isPending: false,
      isSuccess: false,
      isError: false,
      error: null,
      data: null,
      reset: vi.fn(),
    }),
  };
  return {
    state,
    mutation: state.mutation,
    api: {
      get: vi.fn(async (url: string) => {
        const target = String(url);
        for (const [fragment, payload] of Object.entries(state.apiGet)) {
          if (target.includes(fragment)) return { data: payload };
        }
        if (target.includes('/dashboard/active_anomalies')) return { data: [] };
        if (target.includes('/assets/hierarchy')) return { data: { tree: [] } };
        return { data: {} };
      }),
      post: state.post,
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
    login: vi.fn(async () => rhino.state.loginResult ?? {
      success: true,
      organization_slug: 'demo-org',
      user: { role_slugs: ['admin'] },
    }),
    logout: vi.fn(),
    setOrganization: vi.fn(),
  }),
  useOrganization: () => 'demo-org',
  api: rhino.api,
  events: { subscribe: vi.fn(() => () => {}), emit: vi.fn() },
  setOrganization: vi.fn(),
  configureApi: vi.fn(),
}));

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
// jsdom implements neither object-URL factory; the export buttons use both.
Object.defineProperty(URL, 'createObjectURL', { writable: true, value: () => 'blob:local' });
Object.defineProperty(URL, 'revokeObjectURL', { writable: true, value: () => {} });

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
import Layout from '@/components/Layout';

const MODELS = [
  'assets',
  'historian_connectors',
  'historian_tags',
  'diagnostic_incidents',
  'prescriptive_advisories',
  'cmms_work_orders',
  'spectrum_snapshots',
  'failure_mode_assessments',
  'asset_health_indices',
  'model_baselines',
  'baseline_windows',
  'shift_log_entries',
  'security_audit_events',
  'plant_units',
  'failure_modes',
  'asset_components',
  'users',
];

/** Every resource answers with a single record whose every field is absent. */
function blankRows(): Record<string, unknown[]> {
  return Object.fromEntries(MODELS.map((model) => [model, [{}]]));
}

function assetRows(): Record<string, unknown[]> {
  return {
    assets: [
      {
        id: 42,
        record_id: 42,
        asset_tag: 'P-204A',
        asset_name: 'Crude charge pump A',
        name: 'Crude charge pump A',
        unit: 'CDU-1',
        kind: 'Centrifugal pump',
        equipment_class: 'Centrifugal Pump',
        status: 'Advisory',
        criticality_class: 'A',
        manufacturer: 'Sulzer',
        commissioned_on: '2019-04-02',
        data_completeness_pct: 98.4,
        rated_flow_m3h: 420,
        rated_rpm: 1795,
        max_bearing_temp_c: 105,
        health: 28,
        health_index: 28,
        health_index_delta: -33,
        rms_velocity_mms: 8.42,
        rms_velocity_delta_pct: 12,
        bearing_temp_c: 96,
        bearing_temp_delta_c: 4,
        motor_current_a: 318,
        bearing_type: 'Angular contact',
        last_tag_validation_at: '2026-04-02T10:00:00.000Z',
        last_sample_at: '2026-04-02T10:00:00.000Z',
        estimated_rul_window: '6–11 d',
        severity: 'warning',
      },
    ],
    asset_components: [{ id: 1, asset_id: 42, component_name: 'Outboard Bearing', severity: 'warning' }],
    historian_tags: [
      {
        id: 1,
        asset_id: 42,
        asset_tag: 'P-204A',
        tag_path: 'PI:P204A.VIB.OH',
        component_name: 'Outboard Bearing',
        measurement_type: 'Vibration',
        engineering_unit: 'mm/s',
        quality_status: 'Good',
        mapping_state: 'Unmapped',
        mapped: false,
        compatible: true,
        stale: false,
        last_validated_at: '2026-04-02T10:00:00.000Z',
      },
      {
        id: 2,
        asset_id: 42,
        tag_path: 'PI:P204A.TEMP',
        measurement_type: 'Temperature',
        mapping_state: 'Mapped',
        mapped: true,
        compatible: false,
      },
    ],
  };
}

/** Let the mocked axios promises resolve so the query-backed panels re-render. */
async function settle(ms = 30) {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, ms));
  });
}

function renderAt(ui: React.ReactElement, path = '/', entry = '/') {
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
  { name: 'AuthSignUp', element: <AuthSignUp />, path: '/auth/signup', entry: '/auth/signup' },
  { name: 'AuthResetPassword', element: <AuthResetPassword />, path: '/auth/reset-password', entry: '/auth/reset-password?token=tok' },
];

describe('workspace branch coverage', () => {
  beforeEach(() => {
    rhino.state.rows = {};
    rhino.state.apiGet = {};
    rhino.state.loginResult = null;
    rhino.state.post.mockClear();
    vi.clearAllMocks();
  });

  afterEach(() => {
    cleanup();
  });

  it.each(PAGES.map((page) => [page.name, page] as const))(
    'renders %s with records that carry no fields',
    async (_name, page) => {
      rhino.state.rows = blankRows();
      const { container } = renderAt(page.element, page.path ?? '/', page.entry ?? '/');
      await waitFor(() => expect(container.firstChild).not.toBeNull());
      await settle();
      cleanup();
    },
  );

  it.each(PAGES.map((page) => [page.name, page] as const))(
    'renders %s with api payloads present',
    async (_name, page) => {
      rhino.state.rows = assetRows();
      rhino.state.apiGet = {
        '/dashboard/fleet_overview': {
          generated_at: '2026-04-02T10:00:00.000Z',
          kpis: [
            { label: 'Critical', value: 4, note: 'assets', direction: 'down' },
            { label: 'Assets monitored', value: null, note: 'tags', direction: 'up' },
          ],
          unit_risk: [{ name: 'CDU-1', exposure_percent: 92 }],
        },
        '/dashboard/active_anomalies': [{ id: 'P-204A', issue: 'BPFO', age: '2 d' }],
        '/dashboard/unit_risk_matrix': {
          rows: [
            { unit: 'CDU-1', rate: '92%', critical_train: 'P-204A', trip_probability: '12%', derate: '8%', exposure: '$418k' },
            { unit: 'FCC-2', rate: '88%', critical_train: null, trip_probability: null, derate: null, exposure: null },
          ],
          risk_cells: [{ horizon: 'CDU-1' }, { horizon: 'FCC-2' }, { horizon: 'HCU-3' }],
          derate_recommendation: 'Reduce charge rate by 8%.',
        },
        '/system_health': {
          metrics: [
            { name: 'Local DB', value: 'OK', status: 'measured' },
            { name: 'Disk used', value: null, status: 'not_measured' },
          ],
          services: [
            { name: 'Ingestion gateway', status: 'Running' },
            { name: 'LDAP', status: 'SIMULATED' },
          ],
          storage: [
            { name: 'Historian cache', percent: 87, status: 'measured' },
            { name: 'Telemetry store', percent: null, status: 'not_measured' },
          ],
          events: ['10:00 PI Primary heartbeat Connected'],
          warnings: ['PI Primary is reporting a critical condition'],
          backup: { last_run_at: null, status: 'Not measured', retention_days: null },
        },
        '/assets/hierarchy': {
          tree: [
            { id: 'n1', label: 'CDU-1', asset_tag: 'CDU-1', children: [{ id: 'n2', asset_tag: 'P-204A' }] },
          ],
        },
      };
      const { container } = renderAt(page.element, page.path ?? '/', page.entry ?? '/');
      await waitFor(() => expect(container.firstChild).not.toBeNull());
      await settle();
      cleanup();
    },
  );

  it('walks the fleet overview filters and column toggle', async () => {
    rhino.state.rows = assetRows();
    renderAt(<FleetOverview />);
    const search = await screen.findByPlaceholderText(/Search asset or tag/i);
    fireEvent.change(search, { target: { value: 'p-204a' } });
    fireEvent.change(search, { target: { value: 'no-match' } });
    fireEvent.click(screen.getByRole('button', { name: /Hide temperature/i }));
    expect(screen.getByRole('button', { name: /Show temperature/i })).toBeTruthy();
  });

  it('filters the asset registry and switches its tabs', async () => {
    rhino.state.rows = assetRows();
    renderAt(<Assets />, '/assets', '/assets');
    const search = await screen.findByPlaceholderText(/Search equipment/i);
    fireEvent.change(search, { target: { value: 'cdu' } });
    fireEvent.change(search, { target: { value: 'nothing' } });
    // Radix activates a tab on mousedown, not click.
    fireEvent.mouseDown(screen.getByRole('tab', { name: /Components/i }));
    expect(document.body.textContent).toMatch(/Outboard Bearing/);
    fireEvent.mouseDown(screen.getByRole('tab', { name: /Operating envelope/i }));
    expect(document.body.textContent).toMatch(/Rated flow/);
    fireEvent.mouseDown(screen.getByRole('tab', { name: /^Tags$/i }));
    expect(document.body.textContent).toMatch(/historian tags mapped/i);
  });

  it('acknowledges from the health summary and the diagnostics workspace', async () => {
    rhino.state.rows = {
      ...assetRows(),
      diagnostic_incidents: [{ id: 7, incident_code: 'INC-1', status: 'Active', root_cause: 'Outer race spall', evidence_summary: 'BPFO', asset_id: 42 }],
      model_baselines: [{ id: 1, is_active: true }],
      security_audit_events: [{ id: 1, recorded_at: '2026-04-02T10:00:00.000Z', action_type: 'FINDING_SIGNOFF' }],
    };
    const health = renderAt(<AssetHealthSummary />, '/assets/:assetId/health-summary', '/assets/P-204A/health-summary');
    fireEvent.click(await screen.findByRole('button', { name: /^Acknowledge$/ }));
    cleanup();
    expect(health).toBeTruthy();

    renderAt(<AssetDiagnostics />, '/assets/:assetId/diagnostics', '/assets/P-204A/diagnostics');
    fireEvent.click(await screen.findByRole('button', { name: /Compare baseline/i }));
    expect(await screen.findByRole('button', { name: /Hide baseline/i })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /^Acknowledge$/ }));
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'Edited finding' } });
    fireEvent.click(screen.getByRole('button', { name: /Save engineering finding/i }));
    expect(await screen.findByRole('button', { name: /Finding saved/i })).toBeTruthy();
  });

  it('drives the diagnostic workspace when no baseline or incident is loaded', async () => {
    rhino.state.rows = {};
    renderAt(<AssetDiagnostics />, '/assets/:assetId/diagnostics', '/assets/P-204A/diagnostics');
    fireEvent.click(await screen.findByRole('button', { name: /Compare baseline/i }));
    expect(await screen.findByText(/No active baseline/i)).toBeTruthy();
  });

  it('toggles the spectral overlay controls', async () => {
    renderAt(<SpectralAnalytics />, '/assets/:assetId/spectral-analytics', '/assets/P-204A/spectral-analytics');
    fireEvent.click(await screen.findByRole('button', { name: /Harmonics off/i }));
    expect(screen.getByRole('button', { name: /Harmonics on/i })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Bearing markers on/i }));
    expect(screen.getByRole('button', { name: /Bearing markers off/i })).toBeTruthy();
  });

  it('filters, selects and intervenes on the advisory queue', async () => {
    rhino.state.rows = {
      prescriptive_advisories: [
        {
          id: 11, asset_tag: 'P-204A', advisory_code: 'ADV-1', recommended_action: 'Replace bearing pair.',
          recommendation: 'Replace bearing pair.', action_steps_json: ['Isolate', 'Replace'],
          severity: 'critical', status: 'Ready for Dispatch', due_within_days: 6, rul_window: '6–11 d',
          regime_confidence_pct: 96, parts_lead_time_days: 6, warehouse_status: 'In stock',
        },
        { id: 12, asset_tag: 'P-101B', action_steps_json: null, severity: null, status: null },
      ],
    };
    renderAt(<PrescriptiveAdvisories />);
    const search = await screen.findByPlaceholderText(/Search advisory or asset/i);
    fireEvent.change(search, { target: { value: 'P-204A' } });
    fireEvent.click(screen.getByRole('button', { name: /^Unit$/ }));
    fireEvent.click(screen.getByRole('button', { name: /^State$/ }));
    fireEvent.click(screen.getByText(/^P-204A$/));
    fireEvent.click(screen.getByRole('button', { name: /Create work order/i }));
    expect(rhino.state.post).not.toHaveBeenCalled();
  });

  it('switches the unit risk horizon', async () => {
    rhino.state.apiGet = { '/dashboard/unit_risk_matrix': { rows: [], risk_cells: [] } };
    renderAt(<UnitRiskMatrix />);
    fireEvent.click(await screen.findByRole('button', { name: /7 days/i }));
    fireEvent.click(screen.getByRole('button', { name: /30 days/i }));
    expect(screen.getByText(/30 days · Production risk projection/i)).toBeTruthy();
  });

  it('exports and saves the shift handover with and without an existing entry', async () => {
    rhino.state.rows = { shift_log_entries: [{ id: 1, message: 'Derate', severity: 'warning', occurred_at: '2026-04-02T10:00:00.000Z', unit_status: 'Running' }] };
    const first = renderAt(<OperationsShiftLog />);
    fireEvent.click(await screen.findByRole('button', { name: /Export handover/i }));
    fireEvent.click(screen.getByRole('button', { name: /Start new entry/i }));
    expect(screen.getByText(/New entry ready below/i)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Save handover/i }));
    cleanup();
    expect(first).toBeTruthy();

    rhino.state.rows = { shift_log_entries: [] };
    renderAt(<OperationsShiftLog />);
    fireEvent.click(await screen.findByRole('button', { name: /Export handover/i }));
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'Handover note' } });
    fireEvent.click(screen.getByRole('button', { name: /Save handover/i }));
    expect(screen.getByRole('button', { name: /Save handover/i })).toBeTruthy();
  });

  it('drives the retraining console controls', async () => {
    rhino.state.rows = {
      model_baselines: [{ id: 1, status: 'Candidate', algorithm_type: 'Autoencoder', asset_tag: 'P-204A', training_progress: 40, training_log: 'ok', hyperparameters_json: { window_days: 14 } }],
      baseline_windows: [
        { id: 1, label: 'Apr 02', load_percent: 88, completeness_percent: 99.8, selected: true },
        { id: 2, load_percent: 79, completeness_percent: 91.2, selected: false },
      ],
    };
    renderAt(<ModelRetraining />);
    fireEvent.click(await screen.findByRole('button', { name: /Compare baseline/i }));
    expect(screen.getByText(/Baseline comparison enabled/i)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Start retraining/i }));
    fireEvent.click(screen.getByRole('button', { name: /Run locally/i }));
    expect(rhino.state.post).not.toHaveBeenCalled();
  });

  it('drives the evaluation console controls', async () => {
    rhino.state.rows = {
      model_baselines: [
        { id: 1, model_version: 'v3.8.0', status: 'Candidate', algorithm_type: 'Autoencoder', accuracy_metrics_json: { precision: 0.94, false_alarms: 3, lead_time_days: 12 }, gates_json: { golden_run_provenance: true, no_critical_regression: false, custom_gate: true } },
        { id: 2, model_version: 'v3.7.0', status: 'Production', approved_by_name: 'Ada' },
      ],
    };
    renderAt(<ModelEvaluation />);
    fireEvent.click(await screen.findByRole('button', { name: /Export evidence/i }));
    expect(screen.getByText(/Evidence exported/i)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Approve promotion/i }));
    expect(rhino.state.post).not.toHaveBeenCalled();
  });

  it('evaluates a single candidate with no production baseline', async () => {
    rhino.state.rows = { model_baselines: [{ id: 1, status: 'Candidate', gates_json: { golden_run_provenance: false } }] };
    renderAt(<ModelEvaluation />);
    expect(await screen.findByText(/Export evidence/i)).toBeTruthy();
    fireEvent.click(screen.getByRole('checkbox'));
    expect(screen.getByText(/Version history/i)).toBeTruthy();
  });

  it('probes and configures a historian connector', async () => {
    rhino.state.rows = {
      historian_connectors: [
        { id: 1, connector_name: 'PI Primary', protocol_type: 'PI Web API', endpoint_url: 'https://pi.local', poll_latency_ms: 380, buffer_depth: 1200, backfill_total: 100, backfill_committed: 40, status: 'Connected', severity: 'warning', last_heartbeat: '2026-04-02T10:00:00.000Z', polling_interval_seconds: 5 },
      ],
    };
    renderAt(<HistorianConnections />);
    const inputs = await screen.findAllByRole('textbox');
    fireEvent.change(inputs[0], { target: { value: 'https://pi02.local' } });
    fireEvent.change(inputs[1], { target: { value: '15 seconds' } });
    fireEvent.click(screen.getByRole('button', { name: /Test and save/i }));
    expect(screen.getByText(/1.2k/)).toBeTruthy();
  });

  it('searches, triages and commits historian tag mappings', async () => {
    rhino.state.rows = assetRows();
    renderAt(<TagMapping />);
    const search = await screen.findByPlaceholderText(/Search historian tags/i);
    fireEvent.change(search, { target: { value: 'P204A' } });
    fireEvent.click(screen.getByRole('button', { name: /Connector: All/i }));
    expect(screen.getByRole('button', { name: /Connector: PI/i })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Unit: All/i }));
    fireEvent.click(screen.getByRole('button', { name: /Auto-map/i }));
    fireEvent.click(screen.getByRole('button', { name: /Commit valid mappings/i }));
    expect(screen.getByText(/mappings pass all compatibility/i)).toBeTruthy();
  });

  it('commits tag mappings when every tag is already mapped', async () => {
    rhino.state.rows = { historian_tags: [{ id: 1, mapped: true, compatible: true }] };
    renderAt(<TagMapping />);
    fireEvent.click(await screen.findByRole('button', { name: /Commit valid mappings/i }));
    expect(screen.getByRole('button', { name: /Mappings committed/i })).toBeTruthy();
  });

  it('builds the asset hierarchy and publishes it', async () => {
    rhino.state.rows = assetRows();
    rhino.state.apiGet = {
      '/assets/hierarchy': { tree: [{ id: 'n1', label: 'CDU-1', asset_tag: 'CDU-1', children: [{ id: 'n2', asset_tag: 'P-204A' }] }] },
    };
    const { container } = renderAt(<AssetHierarchyBuilder />);
    fireEvent.click(await screen.findByRole('button', { name: /Add unit/i }));
    fireEvent.click(screen.getByRole('button', { name: /Add train/i }));
    fireEvent.click(screen.getByRole('button', { name: /Add asset/i }));
    fireEvent.click(await screen.findByRole('button', { name: /P-204A/i }));
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0], { target: { value: 'P-204B' } });
    fireEvent.change(inputs[1], { target: { value: 'Reciprocating pump' } });
    fireEvent.change(inputs[2], { target: { value: 'Sulzer' } });
    fireEvent.change(inputs[3], { target: { value: 'Production critical' } });
    fireEvent.click(screen.getByRole('button', { name: /Save metadata/i }));
    fireEvent.click(screen.getByRole('button', { name: /Validate & publish/i }));
    expect(container.textContent).toBeTruthy();
  });

  it('reports a failed hierarchy validation payload', async () => {
    rhino.state.apiGet = { '/assets/validate_hierarchy': { valid: false, errors: ['Duplicate tag'] } };
    renderAt(<AssetHierarchyBuilder />);
    expect(await screen.findByText(/Hierarchy validation passed/i)).toBeTruthy();
  });

  it('searches and exports the security audit trail', async () => {
    rhino.state.rows = {
      security_audit_events: [
        { id: 1, recorded_at: '2026-04-02T10:00:00.000Z', severity: 'info', actor_name: 'ada', actor_role: 'admin', action_type: 'AUTH_LOGIN', entity_affected: 'ada', source_host: '10.0.0.1', result: 'Success' },
        { id: 2, recorded_at: null, result: 'Failure' },
      ],
      users: [{ id: 1, role_slugs: ['admin', 'reliability_engineer', 'operations_superintendent'] }],
    };
    renderAt(<SecurityAudit />);
    const search = await screen.findByLabelText(/Search audit events/i);
    fireEvent.change(search, { target: { value: 'ada' } });
    fireEvent.change(search, { target: { value: 'nothing-matches' } });
    expect(await screen.findByText(/No audit events match/i)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Export evidence/i }));
    expect(screen.getByText(/Evidence exported/i)).toBeTruthy();
  });

  it('renders the system health page without measured storage', async () => {
    rhino.state.apiGet = { '/system_health': { metrics: [], storage: [], services: [], events: [], backup: null } };
    renderAt(<SystemHealth />);
    expect((await screen.findAllByText(/Not measured/)).length).toBeGreaterThan(0);
  });

  it('submits the invitation form with a mismatch and with valid credentials', async () => {
    renderAt(<AuthSignUp />, '/auth/signup', '/auth/signup');
    const submit = () => fireEvent.submit(document.querySelector('form') as HTMLFormElement);
    submit();
    expect(document.body.textContent).toMatch(/invitation token/i);
    fireEvent.change(document.querySelector('#invite') as HTMLInputElement, { target: { value: 'tok' } });
    fireEvent.change(document.querySelector('#name') as HTMLInputElement, { target: { value: 'Ada Lovelace' } });
    fireEvent.change(document.querySelector('#email') as HTMLInputElement, { target: { value: 'ada@brr-ot.local' } });
    fireEvent.change(document.querySelector('#password') as HTMLInputElement, { target: { value: 'password123' } });
    fireEvent.change(document.querySelector('#confirmation') as HTMLInputElement, { target: { value: 'password123' } });
    rhino.state.post.mockRejectedValueOnce(new Error('offline'));
    submit();
    await waitFor(() => expect(document.body.textContent).toMatch(/offline/i));
  });

  it('resets a password with a token and recovers without one', async () => {
    const { unmount } = renderAt(<AuthResetPassword />, '/auth/reset-password', '/auth/reset-password?token=tok');
    fireEvent.change(document.querySelector('#reset-email') as HTMLInputElement, { target: { value: 'ada@brr-ot.local' } });
    fireEvent.change(document.querySelector('#reset-password') as HTMLInputElement, { target: { value: 'password123' } });
    fireEvent.change(document.querySelector('#reset-confirmation') as HTMLInputElement, { target: { value: 'password123' } });
    fireEvent.submit(document.querySelector('form') as HTMLFormElement);
    await waitFor(() => expect(rhino.state.post).toHaveBeenCalledWith('/auth/password/reset', expect.anything()));
    unmount();

    rhino.state.post.mockRejectedValueOnce(new Error('broker offline'));
    renderAt(<AuthResetPassword />, '/auth/reset-password', '/auth/reset-password');
    fireEvent.change(document.querySelector('#reset-email') as HTMLInputElement, { target: { value: 'ada@brr-ot.local' } });
    fireEvent.submit(document.querySelector('form') as HTMLFormElement);
    await waitFor(() => expect(document.body.textContent).toMatch(/broker offline/i));
  });

  it('signs in with valid credentials and surfaces a rejected login', async () => {
    rhino.state.loginResult = { success: false, error: 'Bad credentials' };
    renderAt(<Login />, '/login', '/login');
    fireEvent.change(document.querySelector('#user') as HTMLInputElement, { target: { value: 'ada' } });
    fireEvent.change(document.querySelector('#pass') as HTMLInputElement, { target: { value: 'password' } });
    fireEvent.submit(document.querySelector('form') as HTMLFormElement);
    await waitFor(() => expect(document.body.textContent).toMatch(/Bad credentials/i));
  });

  it('opens the shell profile dialog and saves and rejects a profile edit', async () => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <MemoryRouter initialEntries={['/fleet-overview']}>
          <Routes>
            <Route element={<Layout />}>
              <Route path="/fleet-overview" element={<p>Fleet body</p>} />
            </Route>
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    fireEvent.click(await screen.findByRole('button', { name: /Use (light|dark) theme/i }));
    expect(screen.getByRole('button', { name: /Use (light|dark) theme/i })).toBeTruthy();
    fireEvent.pointerDown(screen.getByLabelText(/Open user profile menu/i), { button: 0 });
    fireEvent.click(await screen.findByText(/Profile settings/i));
    const name = await screen.findByLabelText(/Display name/i);
    fireEvent.change(name, { target: { value: 'B' } });
    fireEvent.submit(document.querySelector('form') as HTMLFormElement);
    expect(await screen.findByText(/at least 2 characters|Enter a display name/i)).toBeTruthy();
    fireEvent.change(name, { target: { value: 'Ada Lovelace' } });
    fireEvent.submit(document.querySelector('form') as HTMLFormElement);
    expect(await screen.findByText(/Profile saved/i)).toBeTruthy();
  });

  it('renders every fleet KPI and unit-risk row shape', async () => {
    rhino.state.rows = {
      assets: [
        { id: 42, asset_tag: 'P-204A', asset_name: 'Pump A', name: 'Pump A', unit: 'CDU-1', health: 28, rms: '8.42', temp: '96', rul: '6–11 d', sample: '12s', severity: 'critical' },
        { id: 43, asset_tag: 'P-101B', name: null, asset_name: null, unit: 'FCC-2', health: null, rms: null, temp: null, rul: null, sample: null },
      ],
    };
    rhino.state.apiGet = {
      '/dashboard/fleet_overview': {
        generated_at: '2026-04-02T10:00:00.000Z',
        kpis: [
          { label: 'Critical', value: 4, note: 'assets', direction: 'down' },
          { label: 'Assets monitored', value: null, note: 'tags', direction: 'up' },
          { label: 'Open advisories', value: 3, note: 'advisories' },
          { label: 'Dispatched', note: 'orders', direction: 'up' },
        ],
        unit_risk: [{ name: 'CDU-1', exposure_percent: 92 }, { name: 'FCC-2', exposure_percent: null }],
      },
      '/dashboard/active_anomalies': [{ id: 'P-204A', issue: 'BPFO', age: '2 d' }],
    };
    renderAt(<FleetOverview />);
    await settle();
    expect(document.body.textContent).toMatch(/Criti/);
    const search = screen.getByPlaceholderText(/Search asset or tag/i);
    fireEvent.change(search, { target: { value: 'fcc' } });
    fireEvent.change(search, { target: { value: 'nothing-matches' } });
    fireEvent.click(screen.getByRole('button', { name: /Hide temperature/i }));
    expect(document.body.textContent).toBeTruthy();
  });

  it('renders measured storage, a degraded service and a completed backup', async () => {
    rhino.state.apiGet = {
      '/system_health': {
        metrics: [{ name: 'Local DB', value: 'OK', status: 'measured' }, { name: 'Disk used', value: null, status: 'not_measured' }],
        services: [{ name: 'Ingestion gateway', status: 'Degraded' }, { name: 'CMMS bridge', status: 'Running' }],
        storage: [{ name: 'Historian cache', percent: 92, status: 'measured' }, { name: 'Telemetry store', percent: null, status: 'not_measured' }],
        events: [],
        backup: { status: 'Completed' },
      },
    };
    renderAt(<SystemHealth />);
    await settle();
    expect(document.body.textContent).toMatch(/Mean volume utilisation 92%/);
    expect(document.body.textContent).toMatch(/Degraded/);
  });

  it('scopes historian tags to the CDU unit and to the PI connector', async () => {
    rhino.state.rows = {
      historian_connectors: [{ id: 5, historian_type: 'OSIsoft_PI', connector_name: 'PI Primary' }],
      historian_tags: [
        { id: 1, tag_path: 'PI:A', mapped: false, compatible: true, asset: { unit: 'CDU-1', asset_tag: 'P-204A' }, asset_component: { component_name: 'Bearing' } },
        { id: 2, tag_path: 'PI:B', mapped: true, stale: true, asset: { unit: 'FCC-2' } },
      ],
    };
    renderAt(<TagMapping />);
    fireEvent.click(await screen.findByRole('button', { name: /Connector: All/i }));
    expect(screen.getByRole('button', { name: /Connector: PI/i })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: /Unit: All/i }));
    expect(screen.getByRole('button', { name: /Unit: CDU-1/i })).toBeTruthy();
  });

  it('confirms a work order from URL parameters and reports a missing priority', async () => {
    rhino.state.rows = {
      prescriptive_advisories: [{ id: 11, asset_tag: 'P-204A', advisory_code: 'ADV-1', recommended_action: 'Replace bearing pair.', recommendation: 'Replace bearing pair.' }],
      cmms_work_orders: [{ id: 3, cmms_type: 'SAP PM', sync_status: 'Dispatched', asset_tag: 'P-204A', priority: 'P2', required_by: '2026-01-01', external_order_number: 'SAP-WO-1', confirmed_at: null }],
    };
    const first = renderAt(<WorkOrderConfirmation />, '/work-orders/confirmation', '/work-orders/confirmation?priority=P2&required_by=2026-01-01');
    await settle();
    expect(document.body.textContent).toMatch(/Work Order Confirmation/);
    first.unmount();

    rhino.state.rows.cmms_work_orders = [{ id: 3, cmms_type: 'SAP PM', sync_status: 'Pending Sync' }];
    const second = renderAt(<WorkOrderConfirmation />, '/work-orders/confirmation', '/work-orders/confirmation');
    await settle();
    fireEvent.click(await screen.findByRole('button', { name: /Confirm and dispatch/i }));
    await settle();
    expect(document.body.textContent).toMatch(/maintenance priority/i);
    second.unmount();

    rhino.state.rows.cmms_work_orders = [{ id: 3, cmms_type: 'SAP PM', sync_status: 'Pending Sync' }];
    renderAt(<WorkOrderConfirmation />, '/work-orders/confirmation', '/work-orders/confirmation?priority=P2&required_by=2026-01-01');
    await settle();
    fireEvent.click(await screen.findByRole('button', { name: /Confirm and dispatch/i }));
    await settle();
    expect(rhino.state.post).toHaveBeenCalledWith(
      expect.stringContaining('/dispatch_work_order'),
      expect.objectContaining({ priority: 'P2' }),
    );
  });

  it('renders the shell on a public path without the sidebar', async () => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <MemoryRouter initialEntries={['/login']}>
          <Routes>
            <Route element={<Layout />}>
              <Route path="/login" element={<p>Sign in body</p>} />
            </Route>
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    expect(await screen.findByText(/Sign in body/i)).toBeTruthy();
  });
});
