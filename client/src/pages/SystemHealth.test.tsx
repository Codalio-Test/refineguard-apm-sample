// @vitest-environment jsdom
/**
 * System Health honesty: a value the backend did not measure is rendered as
 * "Not measured", never as a synthesized number.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';

const state = vi.hoisted(() => ({ health: {} as Record<string, unknown> }));

vi.mock('../hooks/useApiQueries', () => ({
  useSystemHealth: () => ({ data: state.health }),
}));

import SystemHealth from './SystemHealth';

describe('SystemHealth rendering', () => {
  afterEach(() => cleanup());

  it('renders measured metrics and labels the rest not measured', () => {
    state.health = {
      metrics: [
        { name: 'Local DB', value: 'OK', status: 'measured' },
        { name: 'API latency', value: '2ms', status: 'measured' },
        { name: 'Disk used', value: null, status: 'not_measured' },
      ],
      services: [{ name: 'Time-series database', status: 'Not measured' }],
      storage: [{ name: 'Telemetry store', percent: null, status: 'not_measured' }],
      events: [],
      warnings: [],
      ingestion: { buffer_depth: 0, backfill_pending: 0, connectors: [] },
      backup: { last_run_at: null, status: 'Not measured', retention_days: null },
      generated_at: '2026-10-14T10:00:00Z',
    };

    render(<SystemHealth />);

    expect(screen.getByText('OK')).toBeTruthy();
    expect(screen.getByText('2ms')).toBeTruthy();
    // The unmeasured metric, the unmeasured service, the volume and the backup
    // status are all reported as "Not measured".
    expect(screen.getAllByText('Not measured').length).toBeGreaterThanOrEqual(4);
    expect(screen.getByText('Not measured', { selector: 'p.font-mono' })).toBeTruthy();
  });
});
