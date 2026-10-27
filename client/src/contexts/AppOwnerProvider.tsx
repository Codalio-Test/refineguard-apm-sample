/**
 * The owner provider component.
 *
 * Resolves the signed-in tenant and its roles from `GET /{org}/me` and exposes
 * them through `AppOwnerContext`, and it never rewrites the URL. An owner
 * provider that navigates to `/<orgId>/` on flat routes is the classic silent
 * bounce-to-home bug, and it also leaves the sidebar's role lookup empty.
 *
 * Why a request rather than storage alone: the engine's login response is only
 * `{ token, organization_slug }`, so `localStorage.user` is never written and a
 * storage-only provider resolves `roles: []` for everybody — silently hiding
 * every role-gated nav item and bouncing every role-gated route. `GET /{org}/me`
 * is the server-side answer for the signed-in identity, and it is tenant-scoped
 * (a non-member gets the information-hiding 404), so the browser can never invent
 * a role it does not hold.
 *
 * The resolution is DERIVED, not stored through a synchronous `setState` inside
 * the fetch effect: the payload is keyed on (token, slug, cross-tab version), so
 * "still loading" is simply "the current key has not resolved yet".
 */
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { events, useAuth } from '@rhino-dev/rhino-react';
import {
  AppOwnerContext,
  STORAGE_ORGANIZATION_KEY,
  fetchSession,
  sessionRoleSlugs,
  type SessionPayload,
} from './appOwner';

interface ResolvedSession {
  key: string;
  session: SessionPayload | null;
}

export const AppOwnerProvider = ({ children }: { children: ReactNode }) => {
  const { isAuthenticated, token } = useAuth();
  const [organizationVersion, setOrganizationVersion] = useState(0);
  const [resolved, setResolved] = useState<ResolvedSession | null>(null);

  // Another tab (or the login page) pinning a different organization must
  // re-resolve: the tenant the roles were read for is no longer the current one.
  useEffect(
    () => events.subscribe(STORAGE_ORGANIZATION_KEY, () => setOrganizationVersion((v) => v + 1)),
    [],
  );

  // `setOrganization` (called by the login page from the login response) is the
  // single writer of this key; here we are only a reader, so a reload restores
  // the tenant without any URL rewriting.
  const storedSlug =
    isAuthenticated && token ? window.localStorage.getItem(STORAGE_ORGANIZATION_KEY) : null;
  const resolutionKey = storedSlug ? `${token}:${storedSlug}:${organizationVersion}` : null;

  useEffect(() => {
    if (!resolutionKey || !storedSlug) return undefined;

    let cancelled = false;
    fetchSession(storedSlug).then((session) => {
      if (!cancelled) setResolved({ key: resolutionKey, session });
    });

    return () => {
      cancelled = true;
    };
  }, [resolutionKey, storedSlug]);

  const isResolved = resolved !== null && resolved.key === resolutionKey;
  const session = isResolved ? resolved.session : null;
  const slug = isResolved ? session?.organization?.slug ?? storedSlug : storedSlug;
  // Fail closed: while the request is in flight (or after it resolved to
  // nothing) there are no roles, and "no roles" is read as "not yet privileged".
  const rolesLoading = resolutionKey !== null && !isResolved;

  const value = useMemo(
    () => ({
      organization: slug ? { slug, name: session?.organization?.name ?? null } : null,
      organizationSlug: slug,
      user: session?.user ?? null,
      roles: sessionRoleSlugs(session),
      rolesLoading,
      // Gate UI on a POSITIVE role check. Never on the negation of another role:
      // while roles load (or if they fail to resolve at all) every `hasRole`
      // returns false, so the negated form would grant privileged UI to everyone.
      hasRole: (name: string) => sessionRoleSlugs(session).includes(name),
    }),
    [slug, session, rolesLoading],
  );

  return <AppOwnerContext.Provider value={value}>{children}</AppOwnerContext.Provider>;
};

export default AppOwnerProvider;
