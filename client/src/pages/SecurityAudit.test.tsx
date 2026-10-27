// @vitest-environment jsdom
/**
 * Security Audit filtering.
 *
 * The audit rows arrive asynchronously, so the filter memo must depend on the
 * loaded events as well as the query/severity inputs — otherwise events that
 * load after the first render stay hidden forever.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const store = vi.hoisted(() => ({ rows: {} as Record<string, unknown[]> }));

vi.mock('@rhino-dev/rhino-react', () => ({
  useModelIndex: (model: string) => ({
    data: { data: store.rows[model] ?? [], pagination: null },
    isLoading: false,
    error: null,
  }),
}));

vi.mock('../hooks/useApiQueries', () => ({
  useAuditExport: () => ({ mutate: vi.fn(), isPending: false }),
}));

import SecurityAudit from './SecurityAudit';

function page() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return (
    <QueryClientProvider client={client}>
      <MemoryRouter>
        <SecurityAudit />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

const auditRow = {
  id: 1,
  recorded_at: '2026-10-14T10:00:00Z',
  severity: 'warning',
  actor_name: 'Ada Lovelace',
  actor_role: 'admin',
  action_type: 'AUTH_LOGIN',
  entity_affected: 'User:1',
  source_host: 'brr-ot.local',
  result: 'Success',
};

describe('SecurityAudit event loading', () => {
  beforeEach(() => {
    store.rows = { security_audit_events: [], users: [] };
  });
  afterEach(() => cleanup());

  it('shows events that arrive after the first render', () => {
    const { rerender } = render(page());

    // First render: nothing loaded yet.
    expect(screen.queryByText('Ada Lovelace')).toBeNull();
    expect(screen.getByText(/No audit events match/)).toBeTruthy();

    // The data arrives and the tree re-renders: the filter must pick it up.
    store.rows = { security_audit_events: [auditRow], users: [] };
    rerender(page());

    expect(screen.getByText('Ada Lovelace')).toBeTruthy();
    expect(screen.queryByText(/No audit events match/)).toBeNull();

    // The severity filter still narrows the loaded rows.
    expect(screen.getByText(/1 events/)).toBeTruthy();
  });
});
