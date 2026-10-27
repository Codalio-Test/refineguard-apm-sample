/**
 * The lazily-loaded page components.
 *
 * Each page is code-split with `React.lazy`, so the initial bundle only carries
 * the shell and one route's chunk is fetched on demand (every emitted chunk is
 * kept under 500 kB). Keeping the lazy imports in their own module keeps the
 * route builder free of component declarations.
 */
import { lazy } from 'react';

/* The design root's pages. */
export const Landing = lazy(() => import('@/pages/Landing'));
export const Login = lazy(() => import('@/pages/Login'));
export const FleetOverview = lazy(() => import('@/pages/FleetOverview'));
export const Assets = lazy(() => import('@/pages/Assets'));
export const AssetHealthSummary = lazy(() => import('@/pages/AssetHealthSummary'));
export const AssetDiagnostics = lazy(() => import('@/pages/AssetDiagnostics'));
export const SpectralAnalytics = lazy(() => import('@/pages/SpectralAnalytics'));
export const PrescriptiveAdvisories = lazy(() => import('@/pages/PrescriptiveAdvisories'));
export const WorkOrderConfirmation = lazy(() => import('@/pages/WorkOrderConfirmation'));
export const UnitRiskMatrix = lazy(() => import('@/pages/UnitRiskMatrix'));
export const OperationsShiftLog = lazy(() => import('@/pages/OperationsShiftLog'));
export const ModelRetraining = lazy(() => import('@/pages/ModelRetraining'));
export const ModelEvaluation = lazy(() => import('@/pages/ModelEvaluation'));
export const HistorianConnections = lazy(() => import('@/pages/HistorianConnections'));
export const TagMapping = lazy(() => import('@/pages/TagMapping'));
export const AssetHierarchyBuilder = lazy(() => import('@/pages/AssetHierarchyBuilder'));
export const SecurityAudit = lazy(() => import('@/pages/SecurityAudit'));
export const SystemHealth = lazy(() => import('@/pages/SystemHealth'));

/* Required auth entry points the design root did not draw. They are the smallest
 * screens that speak the design language, and they live OUTSIDE the app shell. */
export const AuthSignIn = lazy(() => import('@/pages/AuthSignIn'));
export const AuthSignUp = lazy(() => import('@/pages/AuthSignUp'));
export const AuthResetPassword = lazy(() => import('@/pages/AuthResetPassword'));
