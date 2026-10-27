// @vitest-environment jsdom
/**
 * Shared component coverage: the presentational primitives, the alert drawer and
 * the application shell.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const rhino = vi.hoisted(() => ({
  api: {
    get: vi.fn(async (): Promise<{ data: unknown }> => ({ data: [] })),
    post: vi.fn(async (): Promise<{ data: unknown }> => ({ data: {} })),
    put: vi.fn(async (): Promise<{ data: unknown }> => ({ data: {} })),
    delete: vi.fn(async (): Promise<{ data: unknown }> => ({ data: {} })),
  },
}));

vi.mock('@rhino-dev/rhino-react', () => ({
  api: rhino.api,
  useModelIndex: () => ({ data: { data: [], pagination: null }, isLoading: false, error: null }),
  useAuth: () => ({ isAuthenticated: true, token: 't', logout: vi.fn(), login: vi.fn() }),
  useOrganization: () => 'demo-org',
  events: { subscribe: vi.fn(() => () => {}), emit: vi.fn() },
  setOrganization: vi.fn(),
}));

vi.mock('@/contexts/appOwner', () => ({
  useAppOwner: () => ({
    organizationSlug: 'demo-org',
    organization: { id: 1, slug: 'demo-org', name: 'Demo Org' },
    user: { id: 1, name: 'Ada Lovelace', email: 'ada@brr-ot.local' },
    roles: ['admin'],
    rolesLoading: false,
    hasRole: () => true,
  }),
}));

if (!('ResizeObserver' in globalThis)) {
  (globalThis as unknown as { ResizeObserver: unknown }).ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  };
}
URL.createObjectURL = () => 'blob:mock';
URL.revokeObjectURL = () => {};
// jsdom's navigation is not implemented; the chart/handover exports click a
// synthetic anchor, so swallow that click.
HTMLAnchorElement.prototype.click = function click() {};
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

import SeverityBadge from '@/components/SeverityBadge';
import TelemetryValue from '@/components/TelemetryValue';
import ExplainabilityEvidence from '@/components/ExplainabilityEvidence';
import OperationalChartFrame from '@/components/OperationalChartFrame';
import AssetContextNavigation from '@/components/AssetContextNavigation';
import GlobalAlertDrawer from '@/components/GlobalAlertDrawer';
import { AuthCard } from '@/components/AuthCard';
import Layout from '@/components/Layout';

function withRouter(ui: React.ReactElement, entry = '/') {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[entry]}>{ui}</MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('presentational components', () => {
  afterEach(() => cleanup());

  it('renders a severity badge for each known and unknown severity', () => {
    const { rerender } = withRouter(<SeverityBadge severity="critical" />);
    expect(screen.getByText('critical')).toBeTruthy();
    rerender(<SeverityBadge severity="warning" label="Advisory" />);
    expect(screen.getByText('Advisory')).toBeTruthy();
    rerender(<SeverityBadge severity="healthy" />);
    rerender(<SeverityBadge severity="weird" />);
    expect(screen.getByText('weird')).toBeTruthy();
  });

  it('renders telemetry trends', () => {
    const { rerender } = withRouter(<TelemetryValue label="RMS" value={8.42} unit="mm/s" trend="up" detail="+12%" />);
    expect(screen.getByText('8.42')).toBeTruthy();
    rerender(<TelemetryValue label="RMS" value="—" trend="down" detail="-12%" />);
    rerender(<TelemetryValue label="RMS" value={1} trend="stable" />);
    expect(screen.getByText('RMS')).toBeTruthy();
  });

  it('renders evidence rows and tolerates an empty list', () => {
    const { rerender } = withRouter(<ExplainabilityEvidence evidence={[{ label: 'Vibration', value: 45 }]} />);
    expect(screen.getByText('Vibration')).toBeTruthy();
    rerender(<ExplainabilityEvidence />);
    expect(screen.getByText(/Explainability evidence/i)).toBeTruthy();
  });

  it('exports a chart frame with and without an svg', () => {
    const { rerender } = withRouter(
      <OperationalChartFrame title="FFT spectrum" subtitle="Velocity">
        <svg viewBox="0 0 10 10"><polyline points="0,0 1,1" /></svg>
      </OperationalChartFrame>,
    );
    fireEvent.click(screen.getByText(/Export/i));
    rerender(
      <OperationalChartFrame title="Empty frame"><div /></OperationalChartFrame>,
    );
    fireEvent.click(screen.getByText(/Export/i));
    expect(screen.getByText(/Empty frame/i)).toBeTruthy();
  });

  it('renders asset context navigation links for the routed asset', () => {
    withRouter(
      <Routes>
        <Route path="/assets/:assetId/diagnostics" element={<AssetContextNavigation />} />
      </Routes>,
      '/assets/P-204A/diagnostics',
    );
    expect(screen.getByText('Health summary')).toBeTruthy();
    expect(screen.getByText('Spectral analytics')).toBeTruthy();
  });

  it('opens the alert drawer and acknowledges an alert', async () => {
    rhino.api.get.mockResolvedValueOnce({
      data: [
        { id: 'P-204A', record_id: 7, asset_tag: 'P-204A', issue: 'BPFO', severity: 'critical', age: '2 d' },
      ],
    });
    withRouter(<GlobalAlertDrawer />);
    fireEvent.click(screen.getByLabelText(/Open alerts/i));
    await waitFor(() => expect(screen.getByText('Active alerts')).toBeTruthy());
    await waitFor(() => expect(screen.getByText('P-204A')).toBeTruthy());
    fireEvent.click(screen.getByText(/^Acknowledge$/i));
    await waitFor(() => expect(rhino.api.post).toHaveBeenCalled());
  });
});

describe('AuthCard', () => {
  afterEach(() => cleanup());

  it('renders children, a notice and submits', () => {
    const onSubmit = vi.fn((event: React.FormEvent) => event.preventDefault());
    withRouter(
      <AuthCard
        formId="demo"
        description="Description"
        onSubmit={onSubmit}
        notice="Notice text"
        footer={<button type="submit">Go</button>}
      >
        <label htmlFor="field">Field</label>
        <input id="field" />
      </AuthCard>,
    );
    expect(screen.getByText('Notice text')).toBeTruthy();
    fireEvent.submit(document.querySelector('form')!);
    expect(onSubmit).toHaveBeenCalled();
  });

  it('shows an error instead of the notice', () => {
    withRouter(
      <AuthCard formId="demo" description="D" onSubmit={vi.fn()} notice="Notice" error="Boom" footer={null}>
        <span />
      </AuthCard>,
    );
    expect(screen.getByText('Boom')).toBeTruthy();
  });
});

describe('Layout', () => {
  beforeEach(() => {
    rhino.api.get.mockResolvedValue({ data: [] });
  });
  afterEach(() => cleanup());

  it('renders the shell and opens the profile dialog', async () => {
    withRouter(
      <Routes>
        <Route element={<Layout />}>
          <Route path="/fleet-overview" element={<div>Workspace</div>} />
        </Route>
      </Routes>,
      '/fleet-overview',
    );

    expect(screen.getByText('Workspace')).toBeTruthy();
    fireEvent.pointerDown(screen.getByLabelText(/Open user profile menu/i), { button: 0 });
    const profile = await screen.findByText(/Profile settings/i);
    fireEvent.click(profile);
    await waitFor(() => expect(document.querySelector('#profile-name')).not.toBeNull());

    fireEvent.change(document.querySelector('#profile-name')!, { target: { value: 'Ada Lovelace' } });
    fireEvent.submit(document.querySelector('form')!);
    await waitFor(() => expect(screen.getByText(/Profile saved/i)).toBeTruthy());
  });

  it('renders the public tier without the shell chrome', () => {
    withRouter(
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<div>Public landing</div>} />
        </Route>
      </Routes>,
      '/',
    );
    expect(screen.getByText('Public landing')).toBeTruthy();
  });
});
