/**
 * Wrappers for RefineGuard's non-CRUD endpoints.
 *
 * Every function goes through the pre-configured `api` axios instance, so the
 * bearer token, the base URL and the tenancy mode are handled for us. The org
 * slug is read from the AppOwnerProvider (which reads the same storage key the
 * model hooks use), never from a hardcoded value.
 */
import { api, useModelIndex } from '@rhino-dev/rhino-react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAppOwner } from '@/contexts/appOwner';
import { assetRecordId, useAssetByTag } from '@/hooks/useAssetByTag';
import type {
  ActiveAnomaly,
  Asset,
  CmmsWorkOrder,
  DiagnosticIncident,
  FleetOverview,
  HierarchyNode,
  PrescriptiveAdvisory,
  SpectrumSnapshot,
  SystemHealth,
  TagValidationRow,
  UnitRiskMatrix,
} from '@/types/rhino';

/**
 * Build a tenant-scoped API path for the current organization.
 *
 * The path is RELATIVE to the configured axios base URL (`/api`), exactly like
 * the URLs `buildModelUrl` hands to the model hooks: `/{org}/<endpoint>`. Adding
 * a literal `/api` prefix here would produce `/api/api/{org}/...` and every
 * custom endpoint would 404.
 */
function useApiPath() {
  const { organizationSlug } = useAppOwner();
  return (path: string) => `/${organizationSlug}${path}`;
}

function useTenantKey() {
  const { organizationSlug } = useAppOwner();
  return organizationSlug;
}

export function useFleetOverview() {
  const path = useApiPath();
  const tenant = useTenantKey();
  return useQuery({
    queryKey: ['refineguard', 'fleetOverview', tenant],
    queryFn: async () => (await api.get<FleetOverview>(path('/dashboard/fleet_overview'))).data,
    enabled: Boolean(tenant),
    staleTime: 30_000,
  });
}

export function useActiveAnomalies() {
  const path = useApiPath();
  const tenant = useTenantKey();
  return useQuery({
    queryKey: ['refineguard', 'activeAnomalies', tenant],
    queryFn: async () => (await api.get<ActiveAnomaly[]>(path('/dashboard/active_anomalies'))).data,
    enabled: Boolean(tenant),
    staleTime: 15_000,
  });
}

export function useUnitRiskMatrix(range?: string) {
  const path = useApiPath();
  const tenant = useTenantKey();
  return useQuery({
    queryKey: ['refineguard', 'unitRiskMatrix', tenant, range ?? 'current_shift'],
    queryFn: async () =>
      (
        await api.get<UnitRiskMatrix>(
          `${path('/dashboard/unit_risk_matrix')}?range=${encodeURIComponent(range ?? 'current_shift')}`,
        )
      ).data,
    enabled: Boolean(tenant),
    staleTime: 30_000,
  });
}

export function useSystemHealth() {
  const path = useApiPath();
  const tenant = useTenantKey();
  return useQuery({
    queryKey: ['refineguard', 'systemHealth', tenant],
    queryFn: async () => (await api.get<SystemHealth>(path('/system_health'))).data,
    enabled: Boolean(tenant),
    refetchInterval: 60_000,
  });
}

export function useHierarchyTree() {
  const path = useApiPath();
  const tenant = useTenantKey();
  return useQuery({
    queryKey: ['refineguard', 'hierarchy', tenant],
    queryFn: async () =>
      (await api.get<{ tree: HierarchyNode[] }>(path('/assets/hierarchy'))).data.tree,
    enabled: Boolean(tenant),
  });
}

/** Export the signed audit evidence bundle. */
export function useAuditExport() {
  const path = useApiPath();
  return useMutation({
    mutationFn: async (format: 'json' | 'csv') =>
      (await api.get(path(`/security_audit_events/export?format=${format}`), {
        responseType: format === 'csv' ? 'blob' : 'json',
      })).data,
  });
}

/**
 * Import a mapping/hierarchy file at `endpoint`.
 *
 * The historian-tag and asset-hierarchy imports have the same shape
 * (`{ filename, content }` posted as `{ filename, import }`), so they share one
 * hook parameterised by the endpoint and the `modelIndex` key to refresh.
 */
export function useFileImport(endpoint: string, invalidateKey: string) {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ filename, content }: { filename: string; content: string }) =>
      (await api.post(path(endpoint), { filename, import: content })).data,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['modelIndex', invalidateKey] }),
  });
}

/**
 * Invoke a record-scoped action: `POST /{resource}/{id}/{action}`.
 *
 * Training and promoting a baseline are the same shape, so they share one hook
 * parameterised by the resource, the action and the cache key to refresh.
 */
export function useRecordAction(resource: string, action: string, invalidateKey: string) {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: { id: number } & Record<string, unknown>) =>
      (await api.post(path(`${resource}/${id}/${action}`), body)).data,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['modelIndex', invalidateKey] }),
  });
}

/**
 * Run the <=50-tag validation harness.
 *
 * The body is optional: the harness validates the default sample when the
 * caller has nothing to narrow it with, so `mutate()` with no argument sends an
 * empty object rather than `undefined`.
 */
export function useTagValidation() {
  const path = useApiPath();
  return useMutation({
    mutationFn: async (body?: Record<string, unknown>) =>
      (await api.post<{
        duration_ms: number;
        budget_ms: number;
        within_budget: boolean;
        passed: number;
        failed: number;
        success: boolean;
        results: TagValidationRow[];
      }>(path('/historian_tags/validate_batch'), body ?? {})).data,
  });
}

/** Probe a historian connector / ring buffer. */
export function useConnectorTest() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: { id: number } & Record<string, unknown>) =>
      (await api.post(path(`/historian_connectors/${id}/test_connection`), body)).data,
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'historian_connectors'] }),
  });
}

/** Validate / publish the hierarchy. */
export function useValidateHierarchy() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async () => (await api.post(path('/assets/validate_hierarchy'), {})).data,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['refineguard', 'hierarchy'] }),
  });
}

/**
 * The CMMS dispatch response, mirroring
 * `Refineguard::Serializers::CmmsWorkOrderSerializer#dispatch_payload` and the
 * controller's dispatch envelope. `work_order` is absent on a 409 (already
 * dispatched); `budget_ms` is null whenever no network call was timed.
 */
export interface CmmsWorkOrderPayload {
  id: number;
  cmms_type: string;
  external_order_number: string | null;
  sync_status: string;
  priority: string | null;
  required_by: string | null;
  dispatched_at: string | null;
  confirmed_at: string | null;
  material_reservations_json: unknown;
  work_order_payload: Record<string, unknown> | null;
  error_message: string | null;
}

export interface CmmsDispatchResult {
  success: boolean;
  adapter: string;
  simulated: boolean;
  duration_ms: number;
  budget_ms: number | null;
  advisory_status: string;
  errors: string[];
  work_order?: CmmsWorkOrderPayload;
}

/** Dispatch a work order to the on-prem CMMS. */
export function useDispatchWorkOrder() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: { id: number } & Record<string, unknown>) =>
      (await api.post<CmmsDispatchResult>(path(`/prescriptive_advisories/${id}/dispatch_work_order`), body))
        .data,
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'cmms_work_orders'] });
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'prescriptive_advisories'] });
    },
  });
}

/** Approve an operational derate. */
export function useApproveDerate() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, throttle_percentage }: { id: number; throttle_percentage: number }) =>
      (
        await api.post(path(`/prescriptive_advisories/${id}/approve_derate`), {
          throttle_percentage,
        })
      ).data,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'prescriptive_advisories'] });
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'shift_log_entries'] });
    },
  });
}

/** Generate a standby switchover advisory. */
export function useEvaluateStandby() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: number) =>
      (await api.post(path(`/prescriptive_advisories/${id}/evaluate_standby`), {})).data,
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'prescriptive_advisories'] }),
  });
}

/** Persist the anomaly acknowledgement transition. */
export function useAcknowledgeIncident() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: number) =>
      (await api.post(path(`/diagnostic_incidents/${id}/acknowledge`), {})).data,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'diagnostic_incidents'] });
      queryClient.invalidateQueries({ queryKey: ['refineguard', 'activeAnomalies'] });
    },
  });
}

/** Persist an engineering finding and its sign-off. */
export function useSignOffIncident() {
  const path = useApiPath();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, finding }: { id: number; finding: Record<string, unknown> }) =>
      (await api.post(path(`/diagnostic_incidents/${id}/sign_off`), { finding })).data,
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['modelIndex', 'diagnostic_incidents'] }),
  });
}

/* ------------------------------------------------------------------------- *
 * Shared read-model hooks.
 *
 * Several workspaces render the same slice of data from more than one panel, so
 * the loading is expressed once here rather than repeated per section.
 * ------------------------------------------------------------------------- */

export interface WorkOrderContext {
  order: CmmsWorkOrder | null;
  advisories: PrescriptiveAdvisory[];
  advisory: PrescriptiveAdvisory | null;
}

/**
 * The work-order confirmation context: the most recent work order plus the
 * advisory the routed work package belongs to. Both confirmation panels read
 * this, so they can never disagree about which advisory is selected.
 */
export function useWorkOrderContext(routedAdvisoryId?: number): WorkOrderContext {
  const { data: orderResponse } = useModelIndex<CmmsWorkOrder>('cmms_work_orders', {
    sort: '-dispatched_at',
    perPage: 1,
  });
  const { data: advisoryResponse } = useModelIndex<PrescriptiveAdvisory>('prescriptive_advisories', {
    perPage: 50,
  });

  const order = orderResponse?.data?.[0] ?? null;
  const advisories = advisoryResponse?.data ?? [];
  const advisory = advisories.find((row) => row.id === routedAdvisoryId) ?? advisories[0] ?? null;

  return { order, advisories, advisory };
}

export interface AssetIncidentContext {
  asset: Asset | null;
  assetPk: number | null;
  incident: DiagnosticIncident | null;
}

/**
 * The tag-keyed asset context plus its latest diagnostic incident. Shared by the
 * health-summary and diagnostics workspaces.
 */
export function useAssetIncidentContext(assetTag: string): AssetIncidentContext {
  const { asset } = useAssetByTag(assetTag);
  const assetPk = assetRecordId(asset);
  const { data: incidentResponse } = useModelIndex<DiagnosticIncident>(
    'diagnostic_incidents',
    { filters: { asset_id: assetPk }, perPage: 1 },
    { enabled: Boolean(assetPk) },
  );

  return { asset, assetPk, incident: incidentResponse?.data?.[0] ?? null };
}

export interface SpectrumContext {
  asset: Asset | null;
  assetPk: number | null;
  snapshot: SpectrumSnapshot | null;
}

/**
 * The tag-keyed asset context plus its latest spectrum snapshot for the channel
 * carried in the URL. Shared by the spectral workbench panels.
 */
export function useSpectrumContext(assetTag: string, channel: string): SpectrumContext {
  const { asset } = useAssetByTag(assetTag);
  const assetPk = assetRecordId(asset);
  const { data: snapshotResponse } = useModelIndex<SpectrumSnapshot>(
    'spectrum_snapshots',
    { filters: { asset_id: assetPk, channel }, sort: '-captured_at', perPage: 1 },
    { enabled: Boolean(assetPk) },
  );

  return { asset, assetPk, snapshot: snapshotResponse?.data?.[0] ?? null };
}
