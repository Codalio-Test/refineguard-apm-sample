// @vitest-environment jsdom
/**
 * Data-hook coverage for the custom endpoints and the shared read models.
 *
 * Each query hook is rendered until it resolves and each mutation is invoked, so
 * the request builders, the tenant path and the cache-invalidation callbacks all
 * execute.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import React from 'react';
import { cleanup, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const rhino = vi.hoisted(() => ({
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
  modelIndex: vi.fn(
    (_model?: string): { data: { data: unknown[]; pagination: null }; isLoading: boolean; error: null } => ({
      data: { data: [], pagination: null },
      isLoading: false,
      error: null,
    }),
  ),
}));

vi.mock('@rhino-dev/rhino-react', () => ({
  api: rhino.api,
  useModelIndex: (model: string) => rhino.modelIndex(model),
}));

vi.mock('@/contexts/appOwner', () => ({
  useAppOwner: () => ({ organizationSlug: 'demo-org' }),
}));

vi.mock('@/hooks/useAssetByTag', () => ({
  useAssetByTag: () => ({ asset: { record_id: 42 } }),
  assetRecordId: () => 42,
}));

import {
  useActiveAnomalies,
  useAcknowledgeIncident,
  useApproveDerate,
  useAuditExport,
  useConnectorTest,
  useDispatchWorkOrder,
  useFileImport,
  useEvaluateStandby,
  useFleetOverview,
  useHierarchyTree,
  useRecordAction,
  useSignOffIncident,
  useSpectrumContext,
  useSystemHealth,
  useTagValidation,
  useUnitRiskMatrix,
  useValidateHierarchy,
  useWorkOrderContext,
  useAssetIncidentContext,
} from './useApiQueries';

function wrapper({ children }: { children: React.ReactNode }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}

describe('query hooks', () => {
  afterEach(() => cleanup());

  it.each([
    ['useFleetOverview', useFleetOverview],
    ['useActiveAnomalies', useActiveAnomalies],
    ['useSystemHealth', useSystemHealth],
    ['useHierarchyTree', useHierarchyTree],
  ] as const)('%s resolves', async (_name, hook) => {
    const { result } = renderHook(() => hook(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
  });

  it('useUnitRiskMatrix passes the range through', async () => {
    const { result } = renderHook(() => useUnitRiskMatrix('7d'), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/dashboard/unit_risk_matrix?range=7d');
  });
});

describe('mutation hooks', () => {
  afterEach(() => cleanup());

  const cases = [
    ['useFileImport', () => useFileImport('/historian_tags/import', 'historian_tags'), (m: { mutate: (v: unknown) => void }) => m.mutate({ filename: 'a.csv', content: 'x' })],
    ['useTagValidation', useTagValidation, (m: { mutate: (v: unknown) => void }) => m.mutate({})],
    ['useConnectorTest', useConnectorTest, (m: { mutate: (v: unknown) => void }) => m.mutate({ id: 1 })],
    ['useValidateHierarchy', useValidateHierarchy, (m: { mutate: (v: unknown) => void }) => m.mutate(undefined)],
    ['useRecordAction', () => useRecordAction('/model_baselines', 'train', 'model_baselines'), (m: { mutate: (v: unknown) => void }) => m.mutate({ id: 1 })],
    ['useDispatchWorkOrder', useDispatchWorkOrder, (m: { mutate: (v: unknown) => void }) => m.mutate({ id: 1, priority: 'P2' })],
    ['useApproveDerate', useApproveDerate, (m: { mutate: (v: unknown) => void }) => m.mutate({ id: 1, throttle_percentage: 70 })],
    ['useEvaluateStandby', useEvaluateStandby, (m: { mutate: (v: unknown) => void }) => m.mutate(1)],
    ['useAcknowledgeIncident', useAcknowledgeIncident, (m: { mutate: (v: unknown) => void }) => m.mutate(1)],
    ['useSignOffIncident', useSignOffIncident, (m: { mutate: (v: unknown) => void }) => m.mutate({ id: 1, finding: { root_cause: 'x' } })],
  ] as const;

  it.each(cases)('%s issues its request', async (_name, hook, invoke) => {
    const { result } = renderHook(() => hook(), { wrapper });
    invoke(result.current as unknown as { mutate: (v: unknown) => void });
    await waitFor(() => expect(rhino.api.post).toHaveBeenCalled());
  });

  it('the audit export requests a blob for csv', async () => {
    const { result } = renderHook(() => useAuditExport(), { wrapper });
    result.current.mutate('csv');
    await waitFor(() =>
      expect(rhino.api.get).toHaveBeenCalledWith('/demo-org/security_audit_events/export?format=csv', {
        responseType: 'blob',
      }),
    );
  });
});

describe('shared read-model hooks', () => {
  afterEach(() => cleanup());

  it('useWorkOrderContext resolves the routed advisory', () => {
    rhino.modelIndex.mockImplementation((model?: string) => ({
      data: {
        data: model === 'cmms_work_orders'
          ? [{ id: 3, sync_status: 'Pending Sync' }]
          : [{ id: 11, advisory_code: 'ADV-1' }, { id: 12, advisory_code: 'ADV-2' }],
        pagination: null,
      },
      isLoading: false,
      error: null,
    }));

    const { result } = renderHook(() => useWorkOrderContext(12), { wrapper });
    expect(result.current.order).toEqual({ id: 3, sync_status: 'Pending Sync' });
    expect(result.current.advisory).toEqual({ id: 12, advisory_code: 'ADV-2' });
  });

  it('useAssetIncidentContext and useSpectrumContext return the asset context', () => {
    const incident = renderHook(() => useAssetIncidentContext('P-204A'), { wrapper });
    expect(incident.result.current.assetPk).toBe(42);

    const spectrum = renderHook(() => useSpectrumContext('P-204A', 'OB Horizontal'), { wrapper });
    expect(spectrum.result.current.assetPk).toBe(42);
  });
});
