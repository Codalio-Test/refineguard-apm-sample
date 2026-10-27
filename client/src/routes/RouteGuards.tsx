/**
 * Route guards for the flat, application-owned routes.
 *
 * Both guards live in their own module so the route builder stays a plain
 * function with no component declarations.
 */
import type { ReactNode } from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@rhino-dev/rhino-react';
import { useAppOwner } from '@/contexts/appOwner';
import { landingForRoles } from '@/lib/roleLanding';

/** Preserve the requested route so login can return the user to it. */
export function RequireAuth() {
  const { isAuthenticated } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // `Outlet` ONLY. Nesting an owner provider that rewrites the URL here is what
  // causes the silent nav bounce on flat routes.
  return <Outlet />;
}

/**
 * Role gate. Positive checks only — a negated check grants privileged UI to
 * every user while the roles are still loading, and would loop forever if the
 * role's own landing route were the page being denied.
 */
export function RequireRole({ roles, children }: { roles: string[]; children: ReactNode }) {
  const { roles: userRoles, rolesLoading, hasRole } = useAppOwner();
  const { isAuthenticated } = useAuth();
  const location = useLocation();

  if (roles.length === 0) return <>{children}</>;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (rolesLoading) return <p className="loading">Checking role permissions…</p>;

  if (!roles.some((role) => hasRole(role))) {
    const target = landingForRoles(userRoles);
    if (target === location.pathname) {
      return <p className="notice notice--warning">Your role does not grant access to this workspace.</p>;
    }
    return <Navigate to={target} replace />;
  }

  return <>{children}</>;
}
