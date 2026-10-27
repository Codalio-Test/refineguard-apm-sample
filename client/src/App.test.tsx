// @vitest-environment jsdom
/**
 * Application shell behaviour.
 *
 * The shell owns the two things a control-room SPA must never get wrong: a
 * boundary with a real fallback instead of a blank screen, and a loading state
 * for the lazily-fetched route chunks.
 */
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { lazy } from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter, Route } from 'react-router-dom';

const state = vi.hoisted(() => ({ mode: 'ok' as 'ok' | 'boom' | 'pending' }));

/** Throws while rendering, so the failure happens BELOW the error boundary. */
function ExplodingPage(): React.ReactElement {
  throw new Error('route table exploded');
}

vi.mock('@/routes/custom', () => ({
  customRoutes: () => {
    if (state.mode === 'pending') {
      const Never = lazy(() => new Promise<{ default: () => React.ReactElement }>(() => {}));
      return [<Route key="pending" path="/" element={<Never />} />];
    }
    if (state.mode === 'boom') {
      return [<Route key="boom" path="/" element={<ExplodingPage />} />];
    }
    return [<Route key="home" path="/" element={<p>Home page</p>} />];
  },
}));

import App from '@/App';

describe('App', () => {
  beforeEach(() => {
    state.mode = 'ok';
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    cleanup();
    vi.restoreAllMocks();
  });

  it('renders the route table', () => {
    render(<MemoryRouter><App /></MemoryRouter>);
    expect(screen.getByText(/Home page/)).toBeTruthy();
  });

  it('shows the route loading state while a chunk is fetched', () => {
    state.mode = 'pending';
    render(<MemoryRouter><App /></MemoryRouter>);
    expect(screen.getByText(/Loading workspace/)).toBeTruthy();
  });

  it('renders a real fallback instead of a blank screen when rendering throws', () => {
    state.mode = 'boom';
    render(<MemoryRouter><App /></MemoryRouter>);
    expect(screen.getByText(/hit an unexpected error/)).toBeTruthy();
    expect(screen.getByText(/route table exploded/)).toBeTruthy();
    expect(screen.getByRole('button', { name: /Reload the console/i })).toBeTruthy();
  });
});
