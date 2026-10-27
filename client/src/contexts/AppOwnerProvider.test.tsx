// @vitest-environment jsdom
/**
 * Owner-context coverage: resolving the signed-in tenant and its roles from
 * `GET /{org}/me`, failing closed when the request fails, and reacting to a
 * cross-tab organization change.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import React from 'react';
import { act, cleanup, render, screen, waitFor } from '@testing-library/react';

const rhino = vi.hoisted(() => ({
  api: { get: vi.fn(async (): Promise<{ data: unknown }> => ({ data: {} })) },
  auth: { isAuthenticated: true, token: 'token' } as { isAuthenticated: boolean; token: string | null },
  events: { subscribe: vi.fn() },
  setOrganization: vi.fn(),
}));

vi.mock('@rhino-dev/rhino-react', () => ({
  api: rhino.api,
  useAuth: () => rhino.auth,
  events: rhino.events,
  setOrganization: rhino.setOrganization,
}));

import { AppOwnerProvider } from './AppOwnerProvider';
import {
  fetchSession,
  pinOrganization,
  sessionRoleSlugs,
  useAppOwner,
} from './appOwner';

function Probe() {
  const ctx = useAppOwner() as unknown as {
    organization: { name?: string } | null;
    organizationSlug: string | null;
    roles: string[];
    rolesLoading: boolean;
    user: { email?: string } | null;
    hasRole: (role: string) => boolean;
  };
  const { organization, organizationSlug, roles, rolesLoading, user, hasRole } = ctx;
  return (
    <div>
      <span data-testid="slug">{organizationSlug ?? 'none'}</span>
      <span data-testid="name">{organization?.name ?? 'none'}</span>
      <span data-testid="roles">{roles.join(',')}</span>
      <span data-testid="user">{user?.email ?? 'none'}</span>
      <span data-testid="loading">{String(rolesLoading)}</span>
      <span data-testid="has-admin">{String(hasRole('admin'))}</span>
    </div>
  );
}

const session = {
  user: { id: 1, email: 'ada@brr-ot.local', role_slugs: ['admin'] },
  organization: { id: 1, slug: 'demo-org', name: 'Demo Org' },
};

describe('AppOwnerProvider', () => {
  beforeEach(() => {
    rhino.api.get.mockReset();
    rhino.events.subscribe.mockReset().mockReturnValue(() => {});
    rhino.auth = { isAuthenticated: true, token: 'token' };
    window.localStorage.clear();
  });
  afterEach(() => cleanup());

  it('resolves the tenant and roles from the session endpoint', async () => {
    window.localStorage.setItem('organization_slug', 'demo-org');
    rhino.api.get.mockResolvedValue({ data: session });

    render(
      <AppOwnerProvider>
        <Probe />
      </AppOwnerProvider>,
    );

    await waitFor(() => expect(screen.getByTestId('slug').textContent).toBe('demo-org'));
    expect(screen.getByTestId('name').textContent).toBe('Demo Org');
    expect(screen.getByTestId('roles').textContent).toBe('admin');
    expect(screen.getByTestId('user').textContent).toBe('ada@brr-ot.local');
    expect(screen.getByTestId('has-admin').textContent).toBe('true');
  });

  it('fails closed to no roles when the session request fails', async () => {
    window.localStorage.setItem('organization_slug', 'demo-org');
    rhino.api.get.mockRejectedValue(new Error('offline'));

    render(
      <AppOwnerProvider>
        <Probe />
      </AppOwnerProvider>,
    );

    await waitFor(() => expect(screen.getByTestId('loading').textContent).toBe('false'));
    expect(screen.getByTestId('slug').textContent).toBe('demo-org');
    expect(screen.getByTestId('roles').textContent).toBe('');
    expect(screen.getByTestId('has-admin').textContent).toBe('false');
  });

  it('resolves no tenant when unauthenticated or unpinned', async () => {
    rhino.auth = { isAuthenticated: false, token: null };
    const first = render(
      <AppOwnerProvider>
        <Probe />
      </AppOwnerProvider>,
    );
    await waitFor(() => expect(screen.getByTestId('loading').textContent).toBe('false'));
    expect(screen.getByTestId('slug').textContent).toBe('none');
    first.unmount();

    rhino.auth = { isAuthenticated: true, token: 'token' };
    render(
      <AppOwnerProvider>
        <Probe />
      </AppOwnerProvider>,
    );
    await waitFor(() => expect(screen.getByTestId('slug').textContent).toBe('none'));
  });

  it('re-resolves when another tab changes the organization', async () => {
    window.localStorage.setItem('organization_slug', 'demo-org');
    rhino.api.get.mockResolvedValue({ data: session });
    let onStorage: (() => void) = () => {};
    rhino.events.subscribe.mockImplementation((_key: string, cb: () => void) => {
      onStorage = cb;
      return () => {};
    });

    render(
      <AppOwnerProvider>
        <Probe />
      </AppOwnerProvider>,
    );
    await waitFor(() => expect(rhino.api.get).toHaveBeenCalledTimes(1));

    await act(async () => {
      onStorage();
    });
    await waitFor(() => expect(rhino.api.get).toHaveBeenCalledTimes(2));
  });
});

describe('session helpers', () => {
  it('fetchSession returns null without a slug or on failure', async () => {
    expect(await fetchSession(null)).toBeNull();

    rhino.api.get.mockRejectedValueOnce(new Error('boom'));
    expect(await fetchSession('demo-org')).toBeNull();

    rhino.api.get.mockResolvedValueOnce({ data: session });
    expect(await fetchSession('demo-org')).toEqual(session);
  });

  it('sessionRoleSlugs filters empty values', () => {
    expect(sessionRoleSlugs(session)).toEqual(['admin']);
    expect(sessionRoleSlugs({ user: { role_slugs: ['a', null, ''] } })).toEqual(['a']);
    expect(sessionRoleSlugs(null)).toEqual([]);
  });

  it('pinOrganization writes the slug', () => {
    pinOrganization('demo-org');
    expect(rhino.setOrganization).toHaveBeenCalledWith('demo-org');
    pinOrganization(null);
    expect(rhino.setOrganization).toHaveBeenCalledTimes(1);
  });
});
