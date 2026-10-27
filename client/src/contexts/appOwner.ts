/**
 * Application-wide owner context: the shared value, hook and helpers.
 *
 * Rhino's multi-tenancy is *path* based on the API side (`/api/{org}/{model}`)
 * but the application's browser routes are FLAT (`/fleet-overview`, `/assets`).
 * There is therefore no `:baseOwnerId` segment to read an organization from, so
 * the organization a user acts as — and the roles they hold in it — come from
 * the user's own session data (`GET /{org}/me`), never from the URL.
 *
 * This module holds the non-component pieces (the context, the hook and the
 * session helpers); the provider component lives in `AppOwnerProvider.tsx`, so
 * neither file mixes component and non-component exports.
 */
import { createContext, useContext } from 'react';
import { api, setOrganization } from '@rhino-dev/rhino-react';

/** localStorage key `setOrganization` writes and the provider reads. */
export const STORAGE_ORGANIZATION_KEY = 'organization_slug';

export interface SessionUser {
  id?: number;
  name?: string | null;
  display_name?: string | null;
  email?: string | null;
  first_name?: string | null;
  last_name?: string | null;
  approved?: boolean;
  profile_completed?: boolean;
  // Defensive: the server sends strings, but a malformed payload must not leak a
  // null role into the UI's role gates.
  role_slugs?: Array<string | null | undefined>;
}

export interface SessionOrganization {
  id: number;
  name: string | null;
  slug: string;
}

export interface SessionPayload {
  user?: SessionUser | null;
  organization?: SessionOrganization | null;
  authentication?: Record<string, unknown>;
}

export interface AppOwnerValue {
  organization: { slug: string; name: string | null } | null;
  organizationSlug: string | null;
  user: SessionUser | null;
  roles: string[];
  rolesLoading: boolean;
  hasRole: (roleName: string) => boolean;
}

export const AppOwnerContext = createContext<AppOwnerValue>({
  organization: null,
  organizationSlug: null,
  user: null,
  roles: [],
  rolesLoading: true,
  // The default takes the role name so consumers type-check the call site.
  hasRole: () => false,
});

export const useAppOwner = (): AppOwnerValue => useContext(AppOwnerContext);

/**
 * The signed-in identity plus the tenant it was resolved in, exactly as the API
 * reports them. Resolves `null` (never throws) so callers degrade rather than
 * crash when the request fails.
 */
export async function fetchSession(slug: string | null): Promise<SessionPayload | null> {
  if (!slug) return null;
  try {
    const response = await api.get<SessionPayload>(`/${slug}/me`);
    return response?.data ?? null;
  } catch {
    return null;
  }
}

/** The role slugs a session payload carries. Empty when it carries none. */
export function sessionRoleSlugs(session: SessionPayload | null): string[] {
  const slugs = session?.user?.role_slugs;
  return Array.isArray(slugs) ? slugs.filter((slug): slug is string => Boolean(slug)) : [];
}

/** Pin the organization slug the login response returned. */
export function pinOrganization(slug: string | null): void {
  if (slug) setOrganization(slug);
}
