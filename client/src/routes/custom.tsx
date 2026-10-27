/**
 * Flat, application-owned routes.
 *
 * The design root's paths carry no `/:baseOwnerId` segment. The organization
 * travels in the API URL (`/api/{org}/{model}`) and in AppOwnerProvider's
 * context, never in the browser path — registering these under an owner-prefixed
 * provider bounces every navigation back to `/` with no console error.
 *
 * The page components are registered in `./lazyPages` and the guards in
 * `./RouteGuards`, so this module exports only the route builder.
 */
import { Navigate, Route } from 'react-router-dom';
import { AppOwnerProvider } from '@/contexts/AppOwnerProvider';
import { landingForRoles } from '@/lib/roleLanding';
import Layout from '@/components/Layout';
import { RequireAuth, RequireRole } from '@/routes/RouteGuards';
import {
  AssetDiagnostics,
  AssetHealthSummary,
  AssetHierarchyBuilder,
  Assets,
  AuthResetPassword,
  AuthSignIn,
  AuthSignUp,
  FleetOverview,
  HistorianConnections,
  Landing,
  Login,
  ModelEvaluation,
  ModelRetraining,
  OperationsShiftLog,
  PrescriptiveAdvisories,
  SecurityAudit,
  SpectralAnalytics,
  SystemHealth,
  TagMapping,
  UnitRiskMatrix,
  WorkOrderConfirmation,
} from '@/routes/lazyPages';

export { landingForRoles };

/* Role ACLs are the ones `.codalio/ui-handoff.json#pages[*].roles` pins. */
const ACL = {
  fleet: ['reliability_engineer', 'machinery_specialist', 'maintenance_planner', 'operations_superintendent', 'admin'],
  registry: ['reliability_engineer', 'machinery_specialist', 'maintenance_planner', 'operations_superintendent', 'admin'],
  health: ['reliability_engineer', 'machinery_specialist', 'maintenance_planner', 'operations_superintendent'],
  diagnostics: ['reliability_engineer', 'machinery_specialist', 'maintenance_planner'],
  spectral: ['reliability_engineer', 'machinery_specialist'],
  advisories: ['reliability_engineer', 'machinery_specialist', 'maintenance_planner', 'operations_superintendent'],
  workOrders: ['maintenance_planner', 'reliability_engineer'],
  unitRisk: ['operations_superintendent', 'reliability_engineer', 'admin'],
  shiftLog: ['operations_superintendent', 'reliability_engineer', 'admin'],
  models: ['machinery_specialist', 'admin'],
  admin: ['admin'],
  adminOrSpecialist: ['admin', 'machinery_specialist'],
};

export const customRoutes = () => [
  <Route
    key="shell"
    element={
      // AppOwnerProvider MUST wrap Layout: the sidebar's role lookups and the
      // flat-route ACL gates both read it, and it never rewrites the URL.
      <AppOwnerProvider>
        <Layout />
      </AppOwnerProvider>
    }
  >
    {/* Public tier — the design's Layout already renders bare `<Outlet/>` here. */}
    <Route path="/" element={<Landing />} />
    <Route path="/login" element={<Login />} />

    {/* Authenticated tier. */}
    <Route element={<RequireAuth />}>
      <Route path="/fleet-overview" element={<RequireRole roles={ACL.fleet}><FleetOverview /></RequireRole>} />
      <Route path="/assets" element={<RequireRole roles={ACL.registry}><Assets /></RequireRole>} />
      <Route path="/assets/:assetId/diagnostics" element={<RequireRole roles={ACL.diagnostics}><AssetDiagnostics /></RequireRole>} />
      <Route path="/assets/:assetId/health-summary" element={<RequireRole roles={ACL.health}><AssetHealthSummary /></RequireRole>} />
      <Route path="/assets/:assetId/spectral-analytics" element={<RequireRole roles={ACL.spectral}><SpectralAnalytics /></RequireRole>} />
      <Route path="/operations/unit-risk-matrix" element={<RequireRole roles={ACL.unitRisk}><UnitRiskMatrix /></RequireRole>} />
      <Route path="/operations/shift-log" element={<RequireRole roles={ACL.shiftLog}><OperationsShiftLog /></RequireRole>} />
      <Route path="/prescriptive-advisories" element={<RequireRole roles={ACL.advisories}><PrescriptiveAdvisories /></RequireRole>} />
      <Route path="/work-orders/confirmation" element={<RequireRole roles={ACL.workOrders}><WorkOrderConfirmation /></RequireRole>} />
      <Route path="/model-management/retraining" element={<RequireRole roles={ACL.models}><ModelRetraining /></RequireRole>} />
      <Route path="/model-management/evaluation" element={<RequireRole roles={ACL.models}><ModelEvaluation /></RequireRole>} />
      <Route path="/admin/historian-connections" element={<RequireRole roles={ACL.admin}><HistorianConnections /></RequireRole>} />
      <Route path="/admin/tag-mapping" element={<RequireRole roles={ACL.adminOrSpecialist}><TagMapping /></RequireRole>} />
      <Route path="/admin/asset-hierarchy-builder" element={<RequireRole roles={ACL.adminOrSpecialist}><AssetHierarchyBuilder /></RequireRole>} />
      <Route path="/admin/security-audit" element={<RequireRole roles={ACL.admin}><SecurityAudit /></RequireRole>} />
      <Route path="/admin/system-health" element={<RequireRole roles={ACL.admin}><SystemHealth /></RequireRole>} />
    </Route>

    {/* Unmatched paths land on the public overview rather than a blank screen.
        This also absorbs the Codalio preview iframe's `/<org_id>/<product_id>` URL. */}
    <Route path="*" element={<Navigate to="/" replace />} />
  </Route>,

  /* Required auth entry points, standalone (never nested in the app shell). */
  <Route key="auth-signin" path="/auth/signin" element={<AuthSignIn />} />,
  <Route key="auth-signup" path="/auth/signup" element={<AuthSignUp />} />,
  <Route key="auth-reset" path="/auth/reset-password" element={<AuthResetPassword />} />,
];

export default customRoutes;
