/**
 * Landing page — the single public page and the air-gap ingestion
 * telemetry it renders from `historian_connectors`.
 *
 * Rendered to static markup (no jsdom in this air-gapped toolchain), with the
 * Rhino data hook mocked so the assertions are about what the page renders given
 * real connector rows.
 */
import { describe, expect, it, vi } from 'vitest';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const connectorRows = vi.hoisted(() => [
  { id: 1, historian_type: 'OSIsoft_PI', poll_latency_ms: 380, status: 'Connected', buffer_depth: 0 },
  { id: 2, historian_type: 'Honeywell_PHD', poll_latency_ms: 742, status: 'Connected', buffer_depth: 0 },
]);

vi.mock('@rhino-dev/rhino-react', () => ({
  useModelIndex: () => ({
    data: { data: connectorRows, pagination: null },
    isLoading: false,
    error: null,
  }),
  useModelStore: () => ({ mutate: vi.fn(), isPending: false }),
  useModelUpdate: () => ({ mutate: vi.fn(), isPending: false }),
  useModelDelete: () => ({ mutate: vi.fn(), isPending: false }),
  useModelShow: () => ({ data: null, isLoading: false, error: null }),
  useAuth: () => ({ isAuthenticated: false, login: vi.fn(), logout: vi.fn(), setOrganization: vi.fn() }),
  useOrganization: () => 'demo-org',
  useUserRole: () => ({ hasRole: () => false, roles: [], roleIds: [], isLoading: false }),
}));

import Landing from './Landing';

function render() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return renderToStaticMarkup(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <Landing />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('Landing (AC-153)', () => {
  it('renders the public landing hero without an authenticated shell', () => {
    const html = render();

    expect(html).toContain('Deterministic machinery health for air-gapped refineries');
    expect(html).toContain('Air-gapped predictive maintenance');
    // No sidebar / shell chrome leaks onto the public page.
    expect(html).not.toContain('Fleet overview');
    expect(html).not.toContain('Sign out');
  });

  it('offers the two prototype actions: open the fleet and sign in', () => {
    const html = render();

    expect(html).toContain('Open Fleet Overview');
    expect(html).toContain('Sign In');
    expect(html).toContain('Open RefineGuard');
  });

  it('advertises the operational capabilities of the prototype landing', () => {
    const html = render();

    ['Fleet triage', 'Explainable diagnostics', 'Spectral workbench', 'CMMS dispatch',
     'Air-gapped governance', 'Historian resiliency'].forEach((capability) => {
      expect(html).toContain(capability);
    });
  });
});

describe('Landing air-gap ingestion telemetry (AC-131 / AC-164)', () => {
  it('renders PI latency, PHD sync state and the air-gap seal from historian_connectors', () => {
    const html = render();

    // poll_latency_ms drives the PI badge; status drives the PHD badge.
    expect(html).toContain('PI 380ms');
    expect(html).toContain('PHD Sync OK');
    expect(html).toContain('Air-gap sealed');
    expect(html).toContain('Local telemetry is synchronized');
  });
});
