// @vitest-environment jsdom
/**
 * Route guard behaviour.
 *
 * The guards are the only place that decides whether a workspace renders, so
 * every branch of them is exercised here: an unauthenticated request, a request
 * whose roles are still loading, an allowed role, a denied role that is sent to
 * its own landing route, and a denied role whose landing route is the page it was
 * already denied.
 */
import { describe, expect, it, vi, afterEach, beforeEach } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';

const state = vi.hoisted(() => ({
  isAuthenticated: true,
  rolesLoading: false,
  hasRole: (_role: string): boolean => false,
  roles: [] as string[],
}));

vi.mock('@rhino-dev/rhino-react', () => ({
  useAuth: () => ({ isAuthenticated: state.isAuthenticated }),
}));

vi.mock('@/contexts/appOwner', () => ({
  useAppOwner: () => ({
    roles: state.roles,
    rolesLoading: state.rolesLoading,
    hasRole: (role: string) => state.hasRole(role),
  }),
}));

import { RequireAuth, RequireRole } from '@/routes/RouteGuards';

/** The auth guard sits above an outlet, so it wraps its child route. */
function renderAuthGuard(entry = '/fleet-overview') {
  return render(
    <MemoryRouter initialEntries={[entry]}>
      <Routes>
        <Route element={<RequireAuth />}>
          <Route path="/fleet-overview" element={<p>Fleet page</p>} />
        </Route>
        <Route path="/login" element={<p>Login page</p>} />
      </Routes>
    </MemoryRouter>,
  );
}

/**
 * The role gate wraps one page. Its "send the user home" branch must not point
 * back at the page the guard itself renders, so the other landing routes are
 * plain, unguarded routes.
 */
function renderRoleGuard(denied: string[], entry = '/fleet-overview') {
  return render(
    <MemoryRouter initialEntries={[entry]}>
      <Routes>
        <Route
          path="/fleet-overview"
          element={<RequireRole roles={denied}><p>Fleet page</p></RequireRole>}
        />
        <Route
          path="/admin/historian-connections"
          element={<RequireRole roles={denied}><p>Admin page</p></RequireRole>}
        />
        <Route path="/assets" element={<p>Assets page</p>} />
        <Route path="/login" element={<p>Login page</p>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('RouteGuards', () => {
  beforeEach(() => {
    state.isAuthenticated = true;
    state.rolesLoading = false;
    state.hasRole = () => false;
    state.roles = [];
  });

  afterEach(() => cleanup());

  it('renders the child routes when the session is authenticated', () => {
    renderAuthGuard();
    expect(screen.getByText(/Fleet page/)).toBeTruthy();
  });

  it('redirects an unauthenticated request to the sign-in page', () => {
    state.isAuthenticated = false;
    renderAuthGuard();
    expect(screen.getByText(/Login page/)).toBeTruthy();
  });

  it('renders an unrestricted guard without checking the session', () => {
    state.isAuthenticated = false;
    render(
      <MemoryRouter>
        <Routes>
          <Route path="/" element={<RequireRole roles={[]}><p>Open page</p></RequireRole>} />
        </Routes>
      </MemoryRouter>,
    );
    expect(screen.getByText(/Open page/)).toBeTruthy();
  });

  it('redirects a role-gated request from an unauthenticated session', () => {
    state.isAuthenticated = false;
    renderRoleGuard(['admin']);
    expect(screen.getByText(/Login page/)).toBeTruthy();
  });

  it('waits for the role lookup before granting access', () => {
    state.rolesLoading = true;
    renderRoleGuard(['admin']);
    expect(screen.getByText(/Checking role permissions/)).toBeTruthy();
  });

  it('renders the page for a role it holds', () => {
    state.hasRole = (role) => role === 'admin';
    renderRoleGuard(['admin']);
    expect(screen.getByText(/Fleet page/)).toBeTruthy();
  });

  it('sends a wrong-role session to the landing route for its own role', () => {
    state.roles = ['machinery_specialist'];
    renderRoleGuard(['admin']);
    expect(screen.getByText(/Assets page/)).toBeTruthy();
  });

  it('warns instead of looping when the landing route is the denied page', () => {
    state.roles = ['admin'];
    renderRoleGuard(['admin'], '/admin/historian-connections');
    expect(screen.getByText(/Your role does not grant access to this workspace/)).toBeTruthy();
  });

  it('falls back to the default landing route for an unknown role', () => {
    state.roles = ['unmapped_role'];
    render(
      <MemoryRouter initialEntries={['/model-management/retraining']}>
        <Routes>
          <Route
            path="/model-management/retraining"
            element={<RequireRole roles={['admin']}><p>Training page</p></RequireRole>}
          />
          <Route path="/fleet-overview" element={<p>Fleet page</p>} />
        </Routes>
      </MemoryRouter>,
    );
    expect(screen.getByText(/Fleet page/)).toBeTruthy();
  });
});
