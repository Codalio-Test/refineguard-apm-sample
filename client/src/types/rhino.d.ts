/**
 * Barrel re-export of the published frontend type-export artifact.
 *
 * The canonical generated types live at `client/src/rhino.d.ts` (the path the
 * host build-evidence contract requires and the path rhino publishes types to).
 * This module exists only so the existing `@/types/rhino` imports across the
 * app keep resolving to that single source of truth.
 */

export * from '../rhino';
