import { Component, Suspense, type ReactNode } from 'react';
import { Routes } from 'react-router-dom';
import { customRoutes } from '@/routes/custom';

/**
 * Error boundary with a REAL fallback.
 *
 * A boundary that renders `null` produces a blank screen with no console error —
 * the worst possible failure mode in a control room. This one renders the message
 * and a reload affordance.
 */
class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  constructor(props: { children: ReactNode }) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error) {
    // eslint-disable-next-line no-console
    console.error('[RefineGuard] render error', error);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="grid min-h-screen place-items-center bg-background p-6">
          <div className="w-full max-w-lg rounded-xl border border-destructive/50 bg-card p-6 shadow-md">
            <h1 className="text-lg font-semibold text-foreground">RefineGuard APM hit an unexpected error</h1>
            <p className="mt-2 text-sm text-muted-foreground">{this.state.error.message}</p>
            <button
              type="button"
              className="mt-4 inline-flex items-center justify-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground shadow"
              onClick={() => window.location.reload()}
            >
              Reload the console
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

/** Shown while a lazily-loaded route chunk is being fetched. */
function RouteFallback() {
  return (
    <div className="grid min-h-screen place-items-center bg-background p-6">
      <p className="text-sm text-muted-foreground">Loading workspace…</p>
    </div>
  );
}

export default function App() {
  return (
    <ErrorBoundary>
      {/* Every route page is lazy-loaded, so a boundary is required above them. */}
      <Suspense fallback={<RouteFallback />}>
        <Routes>{customRoutes()}</Routes>
      </Suspense>
    </ErrorBoundary>
  );
}
