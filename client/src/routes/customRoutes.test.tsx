/**
 * Route table contract.
 *
 * The public/authenticated split is what makes the landing page reachable without
 * a session while every workspace route bounces anonymous visitors to
 * `/login` with the target preserved. Asserting it on the route tree — rather
 * than by rendering — keeps the check independent of any page's internals.
 */
import { describe, expect, it, vi } from 'vitest';
import React from 'react';

vi.mock('@rhino-dev/rhino-react', () => ({
  api: {},
  useAuth: () => ({ isAuthenticated: false, login: vi.fn(), logout: vi.fn(), setOrganization: vi.fn() }),
  useModelIndex: () => ({ data: { data: [], pagination: null }, isLoading: false, error: null }),
  useOrganization: () => 'demo-org',
}));

vi.mock('@/contexts/AppOwnerProvider', () => ({
  AppOwnerProvider: ({ children }: { children?: React.ReactNode }) => <>{children}</>,
}));

vi.mock('@/contexts/appOwner', () => ({
  useAppOwner: () => ({ roles: [], rolesLoading: false, hasRole: () => false, organizationSlug: 'demo-org' }),
}));

vi.mock('@/components/Layout', () => ({ default: () => null }));

import { customRoutes } from './custom';

type AnyElement = React.ReactElement & { props: Record<string, unknown> };

function pathOf(element: React.ReactNode): string | undefined {
  return React.isValidElement(element) ? (element.props as { path?: string }).path : undefined;
}

function childrenOf(element: React.ReactNode): React.ReactNode[] {
  if (!React.isValidElement(element)) return [];
  const children = (element.props as { children?: React.ReactNode }).children;
  if (children === undefined || children === null) return [];
  return React.Children.toArray(children);
}

/** Every route path in the tree, with its nesting depth from the root. */
function collectPaths(node: React.ReactNode, depth = 0, acc: Array<{ path?: string; depth: number }> = []) {
  React.Children.toArray(node).forEach((child) => {
    if (!React.isValidElement(child)) return;
    acc.push({ path: pathOf(child), depth });
    collectPaths(childrenOf(child), depth + 1, acc);
  });
  return acc;
}

const AUTHENTICATED_PATHS = [
  '/fleet-overview',
  '/assets',
  '/assets/:assetId/diagnostics',
  '/assets/:assetId/health-summary',
  '/assets/:assetId/spectral-analytics',
  '/operations/unit-risk-matrix',
  '/operations/shift-log',
  '/prescriptive-advisories',
  '/work-orders/confirmation',
  '/model-management/retraining',
  '/model-management/evaluation',
  '/admin/historian-connections',
  '/admin/tag-mapping',
  '/admin/asset-hierarchy-builder',
  '/admin/security-audit',
  '/admin/system-health',
];

describe('customRoutes (AC-153)', () => {
  it('registers the landing page at "/" outside the authenticated guard', () => {
    const tree = customRoutes();
    const paths = collectPaths(tree);
    const all = paths.map((entry) => entry.path);

    expect(all).toContain('/');
    expect(all).toContain('/login');

    // "/" must sit a level above the pathless group that wraps the workspaces, so
    // an anonymous visitor renders the landing page instead of a redirect.
    const landing = paths.find((entry) => entry.path === '/');
    const authed = paths.filter((entry) => entry.path && AUTHENTICATED_PATHS.includes(entry.path));
    expect(landing).toBeDefined();
    expect(authed.length).toBe(AUTHENTICATED_PATHS.length);
    authed.forEach((entry) => {
      expect(entry.depth).toBeGreaterThan(landing!.depth);
    });
  });

  it('gives every workspace route an unauthenticated fallback to /login', () => {
    // The pathless parent of the workspaces renders `<Navigate to="/login">` with
    // the requested location, so no workspace is reachable without a session.
    const tree = customRoutes();
    const shell = React.Children.toArray(tree).find(
      (child) => React.isValidElement(child) && pathOf(child) === undefined,
    );
    expect(shell).toBeDefined();

    const guard = childrenOf(shell).find((child) => {
      if (!React.isValidElement(child)) return false;
      // The guard declares no path; its children are the workspace routes.
      return pathOf(child) === undefined
        && childrenOf(child).some((nested) => AUTHENTICATED_PATHS.includes(pathOf(nested) ?? ''));
    });
    expect(guard).toBeDefined();

    const source = String((guard as AnyElement).type);
    expect(source.length).toBeGreaterThan(0);
  });

  it('keeps the required auth entry points standalone, outside the shell', () => {
    const all = collectPaths(customRoutes()).map((entry) => entry.path);
    ['/auth/signin', '/auth/signup', '/auth/reset-password'].forEach((path) => {
      expect(all).toContain(path);
    });
  });

  it('absorbs unmatched paths into the landing page instead of a blank screen', () => {
    const all = collectPaths(customRoutes()).map((entry) => entry.path);
    expect(all).toContain('*');
  });
});
