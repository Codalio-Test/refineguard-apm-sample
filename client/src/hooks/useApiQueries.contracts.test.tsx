// @vitest-environment jsdom
/**
 * Request contracts for the non-CRUD hooks.
 *
 * Each hook owns an exact URL, HTTP verb, request body, cache key and set of
 * cache invalidations. This suite pins those contracts literally, so a hook that
 * starts calling a different endpoint, drops the body, renames a cache key or
 * forgets an invalidation fails here rather than silently drifting from the
 * controller it talks to.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import React from 'react';
import { act, cleanup, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { QueryObserverOptions } from '@tanstack/react-query';

const rhino = vi.hoisted(() => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
  modelIndex: vi.fn(),
}));

const ownerState = vi.hoisted(() => ({ slug: 'demo-org' as string | null }));
const assetState = vi.hoisted(() => ({ asset: { record_id: 42 } as Record<string, unknown> | null }));

vi.mock('@rhino-dev/rhino-react', () => ({
  api: rhino.api,
  // Forward the real argument arity so a two-argument call is asserted as two.
  useModelIndex: (...args: unknown[]) => rhino.modelIndex(...args),
}));

vi.mock('@/contexts/appOwner', () => ({
  useAppOwner: () => ({ organizationSlug: ownerState.slug }),
}));

vi.mock('@/hooks/useAssetByTag', () => ({
  useAssetByTag: () => ({ asset: assetState.asset }),
  assetRecordId: (asset: Record<string, unknown> | null) => {
    if (!asset) return null;
    if (typeof asset.record_id === 'number') return asset.record_id;
    return typeof asset.id === 'number' ? asset.id : null;
  },
}));

import {
  useAcknowledgeIncident,
  useActiveAnomalies,
  useApproveDerate,
  useAssetIncidentContext,
  useAuditExport,
  useConnectorTest,
  useDispatchWorkOrder,
  useEvaluateStandby,
  useFleetOverview,
  useFileImport,
  useHierarchyTree,
  useRecordAction,
  useSignOffIncident,
  useSpectrumContext,
  useSystemHealth,
  useTagValidation,
  useUnitRiskMatrix,
  useValidateHierarchy,
  useWorkOrderContext,
} from './useApiQueries';

function harness() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const invalidate = vi.spyOn(client, 'invalidateQueries');
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );
  return { client, invalidate, wrapper };
}

type Wrapper = ReturnType<typeof harness>['wrapper'];

function queryKeys(client: QueryClient): unknown[][] {
  return client
    .getQueryCache()
    .getAll()
    .map((query) => query.queryKey as unknown[]);
}

function cacheOptions(client: QueryClient): QueryObserverOptions | undefined {
  // `getQueryCache().options` is a `QueryOptions`; the observer-level knobs the
  // assertions read (staleTime / refetchInterval) live on the wider
  // `QueryObserverOptions` the query was created from.
  return client.getQueryCache().getAll()[0]?.options as QueryObserverOptions | undefined;
}

async function runMutation<T>(hook: () => T, wrapper: Wrapper, call: (value: T) => Promise<unknown>) {
  const { result } = renderHook(hook, { wrapper });
  await act(async () => {
    await call(result.current);
  });
}

beforeEach(() => {
  ownerState.slug = 'demo-org';
  assetState.asset = { record_id: 42 };
  rhino.api.get.mockReset().mockResolvedValue({ data: {} });
  rhino.api.post.mockReset().mockResolvedValue({ data: {} });
  rhino.api.put.mockReset().mockResolvedValue({ data: {} });
  rhino.api.delete.mockReset().mockResolvedValue({ data: {} });
  rhino.modelIndex.mockReset().mockReturnValue({ data: { data: [], pagination: null } });
});

afterEach(() => cleanup());

describe('query hook request contracts', () => {
  it('useFleetOverview reads the tenant fleet aggregate under its own cache key', async () => {
    const { client, wrapper } = harness();
    const { result } = renderHook(() => useFleetOverview(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/dashboard/fleet_overview');
    expect(queryKeys(client)).toEqual([['refineguard', 'fleetOverview', 'demo-org']]);
    expect(cacheOptions(client)?.staleTime).toBe(30_000);
  });

  it('useActiveAnomalies reads the anomaly feed', async () => {
    const { client, wrapper } = harness();
    const { result } = renderHook(() => useActiveAnomalies(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/dashboard/active_anomalies');
    expect(queryKeys(client)).toEqual([['refineguard', 'activeAnomalies', 'demo-org']]);
    expect(cacheOptions(client)?.staleTime).toBe(15_000);
  });

  it('useUnitRiskMatrix sends the range and defaults to the current shift', async () => {
    const explicit = harness();
    const first = renderHook(() => useUnitRiskMatrix('7d'), { wrapper: explicit.wrapper });
    await waitFor(() => expect(first.result.current.isSuccess).toBe(true));
    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/dashboard/unit_risk_matrix?range=7d');
    expect(queryKeys(explicit.client)).toEqual([['refineguard', 'unitRiskMatrix', 'demo-org', '7d']]);

    cleanup();
    const fallback = harness();
    const second = renderHook(() => useUnitRiskMatrix(), { wrapper: fallback.wrapper });
    await waitFor(() => expect(second.result.current.isSuccess).toBe(true));
    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/dashboard/unit_risk_matrix?range=current_shift');
    expect(queryKeys(fallback.client)).toEqual([
      ['refineguard', 'unitRiskMatrix', 'demo-org', 'current_shift'],
    ]);
    expect(cacheOptions(fallback.client)?.staleTime).toBe(30_000);
  });

  it('useSystemHealth polls the health endpoint', async () => {
    const { client, wrapper } = harness();
    const { result } = renderHook(() => useSystemHealth(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/system_health');
    expect(queryKeys(client)).toEqual([['refineguard', 'systemHealth', 'demo-org']]);
    expect(cacheOptions(client)?.refetchInterval).toBe(60_000);
  });

  it('useHierarchyTree unwraps the tree envelope', async () => {
    rhino.api.get.mockResolvedValue({ data: { tree: [{ id: 'root' }] } });
    const { client, wrapper } = harness();
    const { result } = renderHook(() => useHierarchyTree(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/assets/hierarchy');
    expect(result.current.data).toEqual([{ id: 'root' }]);
    expect(queryKeys(client)).toEqual([['refineguard', 'hierarchy', 'demo-org']]);
  });

  it('every query hook stays idle without a tenant', async () => {
    ownerState.slug = null;
    const { client, wrapper } = harness();
    renderHook(
      () => [
        useFleetOverview(),
        useActiveAnomalies(),
        useSystemHealth(),
        useHierarchyTree(),
        useUnitRiskMatrix(),
      ],
      { wrapper },
    );

    expect(rhino.api.get).not.toHaveBeenCalled();
    expect(queryKeys(client).every((key) => key.includes(null))).toBe(true);
  });
});

describe('mutation hook request contracts', () => {
  it('useAuditExport requests the signed bundle in the chosen format', async () => {
    const { wrapper } = harness();
    await runMutation(useAuditExport, wrapper, (mutation) => mutation.mutateAsync('json'));
    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/security_audit_events/export?format=json', {
      responseType: 'json',
    });

    rhino.api.get.mockClear();
    await runMutation(useAuditExport, wrapper, (mutation) => mutation.mutateAsync('csv'));
    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/security_audit_events/export?format=csv', {
      responseType: 'blob',
    });
  });

  it('useFileImport posts the file body to the given endpoint and refreshes its index', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(
      () => useFileImport('/assets/import', 'assets'),
      wrapper,
      (mutation) => mutation.mutateAsync({ filename: 'assets.csv', content: 'a,b' }),
    );

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/assets/import', {
      filename: 'assets.csv',
      import: 'a,b',
    });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'assets'] });
    expect(rhino.api.put).not.toHaveBeenCalled();
  });

  it('useRecordAction posts the remaining body to the record action', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(
      () => useRecordAction('/model_baselines', 'train', 'model_baselines'),
      wrapper,
      (mutation) => mutation.mutateAsync({ id: 9, baseline_window_ids: [1, 2] }),
    );

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/model_baselines/9/train', {
      baseline_window_ids: [1, 2],
    });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'model_baselines'] });
  });

  it('useTagValidation posts the batch body', async () => {
    const { wrapper } = harness();
    await runMutation(useTagValidation, wrapper, (mutation) => mutation.mutateAsync({ limit: 50 }));
    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/historian_tags/validate_batch', {
      limit: 50,
    });

    rhino.api.post.mockClear();
    await runMutation(useTagValidation, wrapper, (mutation) => mutation.mutateAsync());
    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/historian_tags/validate_batch', {});
  });

  it('useConnectorTest probes the connector and refreshes the connector index', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useConnectorTest, wrapper, (mutation) => mutation.mutateAsync({ id: 3 }));

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/historian_connectors/3/test_connection', {});
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'historian_connectors'] });
  });

  it('useValidateHierarchy publishes the hierarchy and refreshes the tree', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useValidateHierarchy, wrapper, (mutation) => mutation.mutateAsync());

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/assets/validate_hierarchy', {});
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['refineguard', 'hierarchy'] });
  });

  it('useDispatchWorkOrder posts the dispatch body and refreshes both indexes', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useDispatchWorkOrder, wrapper, (mutation) =>
      mutation.mutateAsync({ id: 7, cmms_type: 'SAP PM', priority: 'P2' }),
    );

    expect(rhino.api.post).toHaveBeenCalledWith(
      '/demo-org/prescriptive_advisories/7/dispatch_work_order',
      { cmms_type: 'SAP PM', priority: 'P2' },
    );
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'cmms_work_orders'] });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'prescriptive_advisories'] });
  });

  it('useApproveDerate posts the throttle and refreshes advisories and the shift log', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useApproveDerate, wrapper, (mutation) =>
      mutation.mutateAsync({ id: 5, throttle_percentage: 70 }),
    );

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/prescriptive_advisories/5/approve_derate', {
      throttle_percentage: 70,
    });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'prescriptive_advisories'] });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'shift_log_entries'] });
  });

  it('useEvaluateStandby generates the switchover advisory', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useEvaluateStandby, wrapper, (mutation) => mutation.mutateAsync(5));

    expect(rhino.api.post).toHaveBeenCalledWith(
      '/demo-org/prescriptive_advisories/5/evaluate_standby',
      {},
    );
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'prescriptive_advisories'] });
  });

  it('useAcknowledgeIncident acknowledges the incident and refreshes the anomaly feed', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useAcknowledgeIncident, wrapper, (mutation) => mutation.mutateAsync(4));

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/diagnostic_incidents/4/acknowledge', {});
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'diagnostic_incidents'] });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['refineguard', 'activeAnomalies'] });
  });

  it('useSignOffIncident wraps the finding and refreshes the incident index', async () => {
    const { invalidate, wrapper } = harness();
    await runMutation(useSignOffIncident, wrapper, (mutation) =>
      mutation.mutateAsync({ id: 4, finding: { root_cause: 'BPFO' } }),
    );

    expect(rhino.api.post).toHaveBeenCalledWith('/demo-org/diagnostic_incidents/4/sign_off', {
      finding: { root_cause: 'BPFO' },
    });
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ['modelIndex', 'diagnostic_incidents'] });
  });
});

describe('shared read-model hooks', () => {
  it('useWorkOrderContext reads the newest order and resolves the routed advisory', () => {
    rhino.modelIndex.mockImplementation((model: string) => {
      if (model === 'cmms_work_orders') {
        return { data: { data: [{ id: 11, external_order_number: 'SAP-WO-000001' }], pagination: null } };
      }
      return {
        data: { data: [{ id: 1, advisory_code: 'ADV-1' }, { id: 2, advisory_code: 'ADV-2' }], pagination: null },
      };
    });

    const { wrapper } = harness();
    const { result } = renderHook(() => useWorkOrderContext(2), { wrapper });

    expect(rhino.modelIndex).toHaveBeenCalledWith('cmms_work_orders', {
      sort: '-dispatched_at',
      perPage: 1,
    });
    expect(rhino.modelIndex).toHaveBeenCalledWith('prescriptive_advisories', { perPage: 50 });
    expect(result.current.order).toEqual({ id: 11, external_order_number: 'SAP-WO-000001' });
    expect(result.current.advisory).toEqual({ id: 2, advisory_code: 'ADV-2' });
    expect(result.current.advisories).toHaveLength(2);
  });

  it('useWorkOrderContext falls back to the first advisory and to null', () => {
    const { wrapper } = harness();
    rhino.modelIndex.mockImplementation((model: string) =>
      model === 'cmms_work_orders'
        ? { data: { data: [], pagination: null } }
        : { data: { data: [{ id: 1 }], pagination: null } },
    );

    const routed = renderHook(() => useWorkOrderContext(99), { wrapper });
    expect(routed.result.current.advisory).toEqual({ id: 1 });
    expect(routed.result.current.order).toBeNull();

    cleanup();
    rhino.modelIndex.mockReturnValue({ data: { data: [], pagination: null } });
    const empty = renderHook(() => useWorkOrderContext(1), { wrapper });
    expect(empty.result.current.advisory).toBeNull();
  });

  it('useWorkOrderContext defaults the routed id to undefined', () => {
    const { wrapper } = harness();
    rhino.modelIndex.mockImplementation((model: string) =>
      model === 'cmms_work_orders'
        ? { data: { data: [{ id: 3 }], pagination: null } }
        : { data: { data: [{ id: 8 }], pagination: null } },
    );
    const { result } = renderHook(() => useWorkOrderContext(), { wrapper });
    expect(result.current.advisory).toEqual({ id: 8 });
  });

  it('useWorkOrderContext tolerates a query that has produced no result object yet', () => {
    rhino.modelIndex.mockReturnValue({});
    const { wrapper } = harness();
    const { result } = renderHook(() => useWorkOrderContext(1), { wrapper });

    expect(result.current.order).toBeNull();
    expect(result.current.advisories).toEqual([]);
    expect(result.current.advisory).toBeNull();
  });

  it('useWorkOrderContext tolerates a resolved query with no payload yet', () => {
    rhino.modelIndex.mockReturnValue({ data: undefined });
    const { wrapper } = harness();
    const { result } = renderHook(() => useWorkOrderContext(1), { wrapper });

    expect(result.current.order).toBeNull();
    expect(result.current.advisories).toEqual([]);
    expect(result.current.advisory).toBeNull();
  });

  it('useWorkOrderContext tolerates a result object whose payload has no data array', () => {
    // The response object exists but carries no `data` collection: the optional
    // chain on `data` (not just on the response) is what keeps this defensive.
    rhino.modelIndex.mockReturnValue({ data: {} });
    const { wrapper } = harness();
    const { result } = renderHook(() => useWorkOrderContext(1), { wrapper });

    expect(result.current.order).toBeNull();
    expect(result.current.advisories).toEqual([]);
    expect(result.current.advisory).toBeNull();
  });

  it('useAssetIncidentContext loads the incident for the resolved asset id', () => {
    rhino.modelIndex.mockImplementation((model: string) =>
      model === 'diagnostic_incidents'
        ? { data: { data: [{ id: 77, incident_code: 'INC-1' }], pagination: null } }
        : { data: { data: [], pagination: null } },
    );

    const { wrapper } = harness();
    const { result } = renderHook(() => useAssetIncidentContext('P-204A'), { wrapper });

    expect(rhino.modelIndex).toHaveBeenCalledWith(
      'diagnostic_incidents',
      { filters: { asset_id: 42 }, perPage: 1 },
      { enabled: true },
    );
    expect(result.current.assetPk).toBe(42);
    expect(result.current.incident).toEqual({ id: 77, incident_code: 'INC-1' });
  });

  it('useAssetIncidentContext disables the incident query without a resolved asset', () => {
    assetState.asset = null;
    const { wrapper } = harness();
    const { result } = renderHook(() => useAssetIncidentContext('P-204A'), { wrapper });

    expect(rhino.modelIndex).toHaveBeenCalledWith(
      'diagnostic_incidents',
      { filters: { asset_id: null }, perPage: 1 },
      { enabled: false },
    );
    expect(result.current.assetPk).toBeNull();
    expect(result.current.incident).toBeNull();
  });

  it('useAssetIncidentContext tolerates a query with no payload yet', () => {
    rhino.modelIndex.mockReturnValue({});
    const { wrapper } = harness();
    const { result } = renderHook(() => useAssetIncidentContext('P-204A'), { wrapper });

    expect(result.current.assetPk).toBe(42);
    expect(result.current.incident).toBeNull();
  });

  it('useAssetIncidentContext tolerates a result object whose payload has no data array', () => {
    rhino.modelIndex.mockReturnValue({ data: {} });
    const { wrapper } = harness();
    const { result } = renderHook(() => useAssetIncidentContext('P-204A'), { wrapper });

    expect(result.current.assetPk).toBe(42);
    expect(result.current.incident).toBeNull();
  });

  it('useSpectrumContext loads the snapshot for the requested channel', () => {
    rhino.modelIndex.mockImplementation((model: string) =>
      model === 'spectrum_snapshots'
        ? { data: { data: [{ id: 5, channel: '1X' }], pagination: null } }
        : { data: { data: [], pagination: null } },
    );

    const { wrapper } = harness();
    const { result } = renderHook(() => useSpectrumContext('P-204A', '1X'), { wrapper });

    expect(rhino.modelIndex).toHaveBeenCalledWith(
      'spectrum_snapshots',
      { filters: { asset_id: 42, channel: '1X' }, sort: '-captured_at', perPage: 1 },
      { enabled: true },
    );
    expect(result.current.assetPk).toBe(42);
    expect(result.current.snapshot).toEqual({ id: 5, channel: '1X' });
  });

  it('useSpectrumContext returns a null snapshot when nothing matches', () => {
    assetState.asset = { id: 9 };
    const { wrapper } = harness();
    const { result } = renderHook(() => useSpectrumContext('P-204A', '2X'), { wrapper });

    expect(rhino.modelIndex).toHaveBeenCalledWith(
      'spectrum_snapshots',
      { filters: { asset_id: 9, channel: '2X' }, sort: '-captured_at', perPage: 1 },
      { enabled: true },
    );
    expect(result.current.snapshot).toBeNull();
  });

  it('useSpectrumContext tolerates a query with no payload yet', () => {
    rhino.modelIndex.mockReturnValue({});
    const { wrapper } = harness();
    const { result } = renderHook(() => useSpectrumContext('P-204A', '1X'), { wrapper });

    expect(result.current.assetPk).toBe(42);
    expect(result.current.snapshot).toBeNull();
  });

  it('useSpectrumContext tolerates a result object whose payload has no data array', () => {
    rhino.modelIndex.mockReturnValue({ data: {} });
    const { wrapper } = harness();
    const { result } = renderHook(() => useSpectrumContext('P-204A', '1X'), { wrapper });

    expect(result.current.assetPk).toBe(42);
    expect(result.current.snapshot).toBeNull();
  });
});
