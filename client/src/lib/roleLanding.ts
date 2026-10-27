/**
 * Role → landing route map.
 *
 * The application's browser routes are FLAT (no `/:baseOwnerId` segment), so the
 * only thing that can decide where a signed-in user belongs is their role in the
 * current organization. This module is the single source of that mapping; both
 * the router (`routes/custom.tsx`, for a wrong-role deep link) and the login page
 * (for the post-authentication redirect) read it, so the two can never drift.
 *
 * The routes are the ones `navigation_design` §5 pins as each role's entry point.
 * Keying off the role *slug* keeps this free of display-name coupling.
 */

/** Role slug → entry route. Mirrors `navigation_design` §5. */
export const ROLE_LANDINGS: Record<string, string> = {
  reliability_engineer: '/fleet-overview',
  machinery_specialist: '/assets',
  maintenance_planner: '/prescriptive-advisories',
  operations_superintendent: '/operations/unit-risk-matrix',
  admin: '/admin/historian-connections',
};

/**
 * Fallback when no known role is held. `/fleet-overview` is the one authenticated
 * route every blueprint role may read, so it can never bounce.
 */
export const DEFAULT_LANDING = '/fleet-overview';

/** The landing route for one role slug, or `null` when the role is unknown. */
export function landingForRole(role?: string | null): string | null {
  if (!role) return null;
  return ROLE_LANDINGS[role] ?? null;
}

/** The first known role's landing route, else {@link DEFAULT_LANDING}. */
export function landingForRoles(roles?: Array<string | null | undefined> | null): string {
  for (const role of roles ?? []) {
    const landing = landingForRole(role);
    if (landing) return landing;
  }
  return DEFAULT_LANDING;
}

/**
 * Where to send a user who just authenticated: the route they originally asked
 * for when there is one, otherwise their role's landing route.
 */
export function landingAfterLogin(options: {
  from?: string | null;
  roles?: Array<string | null | undefined> | null;
}): string {
  const { from, roles } = options;
  if (from && from !== '/login') return from;
  return landingForRoles(roles);
}

export default ROLE_LANDINGS;
