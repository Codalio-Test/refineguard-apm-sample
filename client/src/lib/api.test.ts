// @vitest-environment jsdom
/**
 * The API bootstrap module runs `configureApi` once at import time; this covers
 * its configuration and both interceptor callbacks.
 */
import { describe, expect, it, vi } from 'vitest';

const rhino = vi.hoisted(() => ({ configureApi: vi.fn() }));

vi.mock('@rhino-dev/rhino-react', () => ({ configureApi: rhino.configureApi }));

import { API_BASE_URL } from './api';

interface ApiOptions {
  baseURL: string;
  tenancy: string;
  withCredentials: boolean;
  onUnauthorized: () => void;
  onForbidden: (error?: { message?: string }) => void;
}

describe('api bootstrap', () => {
  it('configures path tenancy for the current origin', () => {
    expect(API_BASE_URL).toBe('/api');
    expect(rhino.configureApi).toHaveBeenCalledTimes(1);

    const options = rhino.configureApi.mock.calls[0][0] as ApiOptions;
    expect(options.baseURL).toBe('/api');
    expect(options.tenancy).toBe('path');
    expect(options.withCredentials).toBe(false);
  });

  it('redirects to login on 401 and warns on 403', () => {
    const options = rhino.configureApi.mock.calls[0][0] as ApiOptions;

    // 401 — the token is already cleared by the library; the handler navigates.
    expect(() => options.onUnauthorized()).not.toThrow();

    // 403 — authenticated but not permitted; the token stays and we only warn.
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    options.onForbidden({ message: 'Denied' });
    expect(warn).toHaveBeenCalledWith('[RefineGuard] request forbidden:', 'Denied');

    options.onForbidden(undefined);
    expect(warn).toHaveBeenCalledWith('[RefineGuard] request forbidden:', undefined);
    warn.mockRestore();
  });
});
