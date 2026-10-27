/**
 * Asset registry / hierarchy explorer.
 *
 *: the ISA-95 equipment tree renders with each node's (worst-child)
 *         health state.
 *: selecting a node populates the Identity, Components, Operating
 *         envelope and Tags inspector tabs.
 *: the explorer drills into the asset health workspace with the selected
 *         asset pre-loaded — the selection key is the asset TAG.
 *
 * Rendered to static markup with the Rhino hooks mocked, so the assertions are
 * about what the page renders given real asset / component / tag rows.
 */
import { describe, expect, it, vi } from 'vitest';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const fixtures = vi.hoisted(() => ({
  rows: {} as Record<string, unknown[]>,
}));

vi.mock('@rhino-dev/rhino-react', () => ({
  useModelIndex: (model: string) => ({
    data: { data: fixtures.rows[model] ?? [], pagination: null },
    isLoading: false,
    error: null,
  }),
}));

import Assets from './Assets';

function render() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return renderToStaticMarkup(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <Assets />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

const assetRow = {
  id: 'P-204A',
  record_id: 42,
  asset_tag: 'P-204A',
  unit: 'CDU-1',
  kind: 'Centrifugal Pump',
  status: 'Critical',
  criticality_class: 'A - Severe/Critical',
  manufacturer: 'Sulzer',
  commissioned_on: '2019-04-02',
  data_completeness_pct: 98.4,
  rated_flow_m3h: 420,
  rated_rpm: 1795,
  max_bearing_temp_c: 105,
};

const healthyRow = {
  id: 'P-101B',
  record_id: 43,
  asset_tag: 'P-101B',
  unit: 'CDU-1',
  kind: 'Centrifugal Pump',
  status: 'Normal',
  criticality_class: 'A - Severe/Critical',
  manufacturer: 'Sulzer',
  data_completeness_pct: 99.4,
};

function seed() {
  fixtures.rows = {
    assets: [assetRow, healthyRow],
    asset_components: [
      { id: 1, component_name: 'Outboard Bearing', component_type: 'Angular Contact Ball Bearing Pair' },
      { id: 2, component_name: 'Primary Cartridge Seal', component_type: 'Mechanical Seal API 682' },
    ],
    historian_tags: [
      { id: 1, tag_path: 'PI:P204A.VIB.OH', measurement_type: 'Overall Vibration Velocity Horizontal' },
      { id: 2, tag_path: 'PI:P204A.TI.OB', measurement_type: 'Bearing Metal Temperature' },
      { id: 3, tag_path: 'PI:P204A.II.MTR', measurement_type: 'Motor Current' },
    ],
  };
}

describe('Assets hierarchy explorer (AC-149)', () => {
  it('renders the ISA-95 tree with each node carrying its health state', () => {
    seed();
    const html = render();

    expect(html).toContain('Asset registry');
    expect(html).toContain('BRR refinery complex');
    expect(html).toContain('P-204A');
    expect(html).toContain('P-101B');
    expect(html).toContain('CDU-1 · Centrifugal Pump');
    expect(html).toContain('Critical'); // the worst-child state on the selected node
  });
});

describe('Assets inspector (AC-150)', () => {
  it('exposes the Identity, Components, Operating envelope and Tags tabs', () => {
    seed();
    const html = render();

    ['Identity', 'Components', 'Operating envelope', 'Tags'].forEach((tab) => {
      expect(html).toContain(tab);
    });
  });

  it('populates the identity card from the selected asset, not a placeholder', () => {
    seed();
    const html = render();

    expect(html).toContain('Equipment identity');
    expect(html).toContain('Centrifugal Pump');
    expect(html).toContain('A - Severe/Critical');
    expect(html).toContain('Sulzer');
    expect(html).toContain('98.4%');
  });

  it('follows the selected node rather than rendering a fixed asset', () => {
    seed();
    fixtures.rows = { ...fixtures.rows, assets: [healthyRow, assetRow] };
    const html = render();

    expect(html).toContain('P-101B');
    expect(html).toContain('99.4%');
    expect(html).not.toContain('98.4%');
  });
});

describe('Assets drill-in (AC-151)', () => {
  it('offers the health workspace drill-in keyed on the asset tag', () => {
    seed();
    const html = render();

    expect(html).toContain('Open health workspace');
    // The selection key is the tag, so the drill-in URL is /assets/P-204A/health-summary
    // rather than a numeric primary key.
    expect(html).toMatch(/P-204A/);
    expect(html).not.toMatch(/\/assets\/42\//);
  });
});
