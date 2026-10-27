/**
 * Side-effect module: configures the single axios client the whole SPA uses.
 *
 * Imported FIRST in main.tsx, before anything renders, because every data hook
 * (`useModelIndex`, `useModelStore`, ...) reads this configuration at call time.
 *
 * Tenancy is `path`: the organization slug is a path segment
 * (`/api/{org}/{model}`), which is what the Rails tenant route group
 * (`prefix: ':organization'`) draws. In development the Vite dev server proxies
 * `/api` to the Rails port, so no CORS configuration is needed and no port is
 * hardcoded here.
 */
import { configureApi } from '@rhino-dev/rhino-react';

export const API_BASE_URL = '/api';

configureApi({
  baseURL: API_BASE_URL,
  tenancy: 'path',
  withCredentials: false,
  onUnauthorized: () => {
    // The library has already cleared the token; a full navigation to the login
    // route also resets any in-memory query cache holding stale tenant data.
    if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
      window.location.assign('/login');
    }
  },
  onForbidden: (error) => {
    // 403 means authenticated but not permitted — the token stays valid.
    console.warn('[RefineGuard] request forbidden:', error?.message ?? error);
  },
});
