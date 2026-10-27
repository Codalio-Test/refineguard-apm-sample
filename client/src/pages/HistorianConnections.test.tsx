/**
 * Historian connections console — the live connector telemetry surface
 * (, /).
 *
 * The air-gap ingestion telemetry (polling latency, local buffer depth, last
 * heartbeat) is rendered from the `historian_connectors` resource, not from
 * static markup: the same component is rendered twice with different rows and
 * the readouts are asserted to follow the data.
 *
 * Surface note: the plan folded these badges into the shell header, but the
 * locked prototype's chrome wins, so the live telemetry is rendered here and on
 * the landing page (`Landing.test.tsx`) rather than in `Layout`. The capability —
 * telemetry derived from live connector rows rather than static markup — is what
 * is asserted.
 */
import { describe, expect, it, vi } from 'vitest';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

type ConnectorRow = Record<string, unknown>;

const state = vi.hoisted(() => ({ connectors: [] as ConnectorRow[] }));

vi.mock('@rhino-dev/rhino-react', () => ({
  useModelIndex: () => ({ data: { data: state.connectors, pagination: null }, isLoading: false, error: null }),
  useModelUpdate: () => ({ mutate: vi.fn(), isPending: false }),
}));

vi.mock('../hooks/useApiQueries', () => ({
  useConnectorTest: () => ({ mutate: vi.fn(), isPending: false }),
}));

import HistorianConnections from './HistorianConnections';

function render() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return renderToStaticMarkup(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <HistorianConnections />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

const piPrimary: ConnectorRow = {
  id: 1,
  connector_name: 'PI Primary',
  historian_type: 'OSIsoft_PI',
  protocol_type: 'PI Web API',
  server_address: '10.120.44.15',
  endpoint_url: 'pi01.ot.local',
  status: 'Connected',
  severity: 'healthy',
  poll_latency_ms: 380,
  buffer_depth: 12,
  backfill_committed: 184,
  backfill_total: 184,
  last_heartbeat: new Date(Date.now() - 8_000).toISOString(),
};

const phdBackup: ConnectorRow = {
  id: 2,
  connector_name: 'PHD Backup',
  historian_type: 'Honeywell_PHD',
  protocol_type: 'OPC HDA',
  server_address: '10.120.45.20',
  endpoint_url: 'phd02.ot.local',
  status: 'Connected',
  severity: 'warning',
  poll_latency_ms: 742,
  buffer_depth: 0,
  backfill_committed: 95,
  backfill_total: 100,
  last_heartbeat: new Date(Date.now() - 21_000).toISOString(),
};

describe('HistorianConnections telemetry (AC-131 / AC-164)', () => {
  it('renders the connector console', () => {
    state.connectors = [piPrimary, phdBackup];
    const html = render();

    expect(html).toContain('Historian Connections');
    expect(html).toContain('Connector');
    expect(html).toContain('Last poll');
  });

  it('derives the air-gap ingestion readouts from the connector rows', () => {
    state.connectors = [piPrimary, phdBackup];
    const html = render();

    expect(html).toContain('Polling latency');
    expect(html).toContain('742ms'); // worst latency across the connectors
    expect(html).toContain('Buffer depth');
    expect(html).toContain('Backfill queue');

    // Per-connector columns: protocol, endpoint, latency, buffer, last heartbeat.
    expect(html).toContain('PI Primary');
    expect(html).toContain('PI Web API');
    expect(html).toContain('pi01.ot.local');
    expect(html).toContain('380ms');
    expect(html).toContain('PHD Backup');
    expect(html).toContain('OPC HDA');
    expect(html).toMatch(/\b\d+s\b/); // the elapsed-since-last-heartbeat reading
  });

  it('follows the data rather than rendering static markup', () => {
    state.connectors = [piPrimary];
    const first = render();

    state.connectors = [{
      ...piPrimary,
      connector_name: 'Exaquantum Utilities',
      protocol_type: 'OPC UA Secure Binary',
      poll_latency_ms: 1_200,
      buffer_depth: 1_500,
    }];
    const second = render();

    expect(first).toContain('380ms');
    expect(first).not.toContain('1200ms');
    expect(second).toContain('1200ms');
    expect(second).toContain('1.5k'); // buffer depth rendered in thousands
    expect(second).toContain('Exaquantum Utilities');
    expect(second).not.toContain('PI Primary');
  });
});
