import path from 'node:path';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig, loadEnv } from 'vite';

/**
 * The SPA talks to the Rails API over ONE public Vite origin.
 *
 * `/api/*` is proxied to the Rails server, whose port is derived from `API_PORT`
 * (default 3001) — never hardcoded to 3000 — so the browser only ever sees
 * same-origin requests and no CORS configuration is required.
 */
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const apiPort = env.API_PORT || process.env.API_PORT || '3001';
  const clientPort = Number(env.CLIENT_PORT || process.env.CLIENT_PORT || 5173);

  return {
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: {
        '@': path.resolve(import.meta.dirname, './src'),
      },
    },
    server: {
      allowedHosts: ['.prod-runtime.all-hands.dev'],
      host: '0.0.0.0',
      port: clientPort,
      strictPort: false,
      proxy: {
        '/api': {
          target: `http://127.0.0.1:${apiPort}`,
          changeOrigin: true,
          secure: false,
        },
      },
    },
    preview: {
      host: '0.0.0.0',
      port: clientPort,
      strictPort: false,
    },
    build: {
      outDir: 'dist',
      sourcemap: false,
      // Every emitted chunk must stay under 500 kB (routes are lazy-loaded).
      chunkSizeWarningLimit: 500,
    },
    test: {
      environment: 'node',
      coverage: {
        provider: 'v8',
        reporter: ['text', 'html'],
        // Vendored shadcn/ui primitives and generated type files are excluded;
        // the application code we own is what the threshold measures.
        include: ['src/**/*.{ts,tsx}'],
        exclude: [
          'src/components/ui/**',
          'src/types/**',
          'src/**/*.d.ts',
          'src/main.tsx',
          'src/**/*.test.{ts,tsx}',
        ],
        thresholds: {
          lines: 80,
          branches: 85,
        },
      },
    },
  };
});
