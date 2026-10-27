/**
 * Application entry point.
 *
 * ORDER MATTERS:
 *   1. `./lib/api` runs `configureApi()` as a side effect — every hook reads that
 *      configuration, so it must happen before the first render.
 *   2. Provider stack: QueryClient → AuthProvider → BrowserRouter → App.
 *
 * The bootstrap is guarded so a mount failure shows a visible error instead of an
 * empty `#root` (a silent white screen is the hardest symptom to diagnose).
 */
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from '@rhino-dev/rhino-react';
import { BrowserRouter } from 'react-router-dom';

import './lib/api';
import './index.css';
import App from './App';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

const container = document.getElementById('root');

function renderFatal(message: string, error?: unknown) {
  if (!container) return;
  container.innerHTML = `
    <div style="font:14px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;color:#fecaca;background:#0f172a;padding:24px;min-height:100vh">
      <h1 style="color:#ef4444;font-size:18px;margin:0 0 8px">RefineGuard APM failed to start</h1>
      <p style="margin:0 0 12px">${message}</p>
      <pre style="white-space:pre-wrap;color:#94a3b8">${error instanceof Error ? error.stack ?? error.message : String(error ?? '')}</pre>
    </div>`;
}

if (!container) {
  // Nothing to mount into — surface it loudly rather than failing silently.
  // eslint-disable-next-line no-console
  console.error('[RefineGuard] #root container is missing from index.html');
} else {
  try {
    createRoot(container).render(
      <StrictMode>
        <QueryClientProvider client={queryClient}>
          <AuthProvider tenancy="path">
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </AuthProvider>
        </QueryClientProvider>
      </StrictMode>,
    );
  } catch (error) {
    renderFatal('The application could not be mounted.', error);
  }
}

window.addEventListener('error', (event) => {
  // eslint-disable-next-line no-console
  console.error('[RefineGuard] unhandled error', event.error ?? event.message);
});
