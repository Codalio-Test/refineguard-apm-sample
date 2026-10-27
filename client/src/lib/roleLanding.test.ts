/**
 * Role-landing redirect map.
 *
 * Covers (the operations superintendent lands on /operations/unit-risk-matrix
 * after login) and (the administrator lands on /admin/historian-connections
 * after login) — the two personas `PERSONA_NO_JOURNEY` flagged as having no entry
 * route. The map is also what `routes/custom.jsx` uses to bounce a wrong-role deep
 * link, so these assertions pin both behaviours to one table.
 */
import { describe, expect, it } from 'vitest';
import {
  DEFAULT_LANDING,
  ROLE_LANDINGS,
  landingAfterLogin,
  landingForRole,
  landingForRoles,
} from './roleLanding';

describe('roleLanding', () => {
  it('lands the operations superintendent on the unit risk matrix (AC-156)', () => {
    expect(landingForRoles(['operations_superintendent'])).toBe('/operations/unit-risk-matrix');
    expect(landingAfterLogin({ roles: ['operations_superintendent'] })).toBe(
      '/operations/unit-risk-matrix',
    );
  });

  it('lands the system administrator on historian connections (AC-157)', () => {
    expect(landingForRoles(['admin'])).toBe('/admin/historian-connections');
    expect(landingAfterLogin({ roles: ['admin'] })).toBe('/admin/historian-connections');
  });

  it('lands every blueprint role on a real route', () => {
    expect(ROLE_LANDINGS.reliability_engineer).toBe('/fleet-overview');
    expect(ROLE_LANDINGS.machinery_specialist).toBe('/assets');
    expect(ROLE_LANDINGS.maintenance_planner).toBe('/prescriptive-advisories');
  });

  it('falls back to the one route every role may read', () => {
    expect(landingForRoles([])).toBe(DEFAULT_LANDING);
    expect(landingForRoles(null)).toBe(DEFAULT_LANDING);
    expect(landingForRoles(['unknown_role'])).toBe(DEFAULT_LANDING);
    expect(landingForRole(undefined)).toBeNull();
    expect(landingForRole('unknown_role')).toBeNull();
  });

  it('returns the requested route after login when one was captured', () => {
    expect(landingAfterLogin({ from: '/admin/security-audit', roles: ['admin'] })).toBe(
      '/admin/security-audit',
    );
    // Never treat /login itself as a captured target, or login would loop.
    expect(landingAfterLogin({ from: '/login', roles: ['admin'] })).toBe(
      '/admin/historian-connections',
    );
  });

  it('resolves the first role it recognises when several are held', () => {
    expect(landingForRoles(['unknown_role', 'maintenance_planner', 'admin'])).toBe(
      '/prescriptive-advisories',
    );
  });
});
