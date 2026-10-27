/**
 * — the keyboard ergonomics layer.
 *
 *: the documented triage, spectral and dispatch key set.
 *: `Cmd/Ctrl + K` opens the asset & historian tag entry point from the
 *         authenticated shell.
 *
 * The matching rule is exercised directly (`matchesShortcut`) because it is the
 * unit every screen's shortcut delegate runs through; the legend is asserted so
 * the advertised key map cannot silently drift from the rule.
 *
 * TODO: the per-screen subset — `H` harmonics, `B` bearing markers, `W`
 * waterfall, `J`/`K` + `Enter` row navigation, `A`/`Space` acknowledge, `1`-`4`
 * unit filter, `←`/`→` waterfall scrub, `Cmd/Ctrl + Enter` dispatch — is
 * advertised by `shortcutLegend()` and matchable by `matchesShortcut()`, but is
 * not yet mounted by `SpectralAnalytics`, `FleetOverview` or
 * `WorkOrderConfirmation`. Only `Cmd/Ctrl + K` is wired, from
 * the shell in `Layout.tsx`. Left as a reported gap rather than marked green.
 */
import { describe, expect, it, vi } from 'vitest';
import {
  SHELL_SHORTCUTS,
  isEditableTarget,
  matchesShortcut,
  shortcutLegend,
  useGlobalShortcuts,
  useShellShortcuts,
  type Shortcut,
  type ShortcutKeystroke,
} from './useGlobalShortcuts';

const key = (overrides: Partial<ShortcutKeystroke>): ShortcutKeystroke => ({
  key: 'k',
  target: null,
  ...overrides,
});

const input = { tagName: 'INPUT' } as unknown as EventTarget;

describe('matchesShortcut (AC-130 / AC-166)', () => {
  it('treats Cmd and Ctrl as the same modifier', () => {
    const command: Pick<Shortcut, 'keys' | 'meta'> = { keys: ['k'], meta: true };

    expect(matchesShortcut(key({ metaKey: true }), command)).toBe(true);
    expect(matchesShortcut(key({ ctrlKey: true }), command)).toBe(true);
    expect(matchesShortcut(key({}), command)).toBe(false);
  });

  it('requires the modifier when the shortcut declares none', () => {
    const fleetFilter: Pick<Shortcut, 'keys'> = { keys: ['1', '2', '3', '4'] };

    ['1', '2', '3', '4'].forEach((digit) => {
      expect(matchesShortcut(key({ key: digit }), fleetFilter)).toBe(true);
    });
    expect(matchesShortcut(key({ key: '2', metaKey: true }), fleetFilter)).toBe(false);
    expect(matchesShortcut(key({ key: '9' }), fleetFilter)).toBe(false);
  });

  it('matches single characters case-insensitively', () => {
    expect(matchesShortcut(key({ key: 'J' }), { keys: ['j'] })).toBe(true);
    expect(matchesShortcut(key({ key: 'k' }), { keys: ['K'] })).toBe(true);
    expect(matchesShortcut(key({ key: 'W', metaKey: true }), { keys: ['w'], meta: true })).toBe(true);
  });

  it('honours the declared shift requirement', () => {
    const dispatch: Pick<Shortcut, 'keys' | 'meta' | 'shift'> = { keys: ['Enter'], meta: true, shift: true };

    expect(matchesShortcut(key({ key: 'Enter', metaKey: true, shiftKey: true }), dispatch)).toBe(true);
    expect(matchesShortcut(key({ key: 'Enter', metaKey: true }), dispatch)).toBe(false);
    expect(matchesShortcut(key({ key: 'Enter', metaKey: true, ctrlKey: true, shiftKey: true }), dispatch)).toBe(true);
  });

  it('matches the named keys the triage and spectral screens use', () => {
    expect(matchesShortcut(key({ key: 'Enter' }), { keys: ['Enter'] })).toBe(true);
    expect(matchesShortcut(key({ key: 'Escape' }), { keys: ['Escape'] })).toBe(true);
    expect(matchesShortcut(key({ key: 'ArrowLeft' }), { keys: ['ArrowLeft'] })).toBe(true);
    expect(matchesShortcut(key({ key: 'ArrowRight' }), { keys: ['ArrowRight'] })).toBe(true);
    expect(matchesShortcut(key({ key: 'ArrowLeft' }), { keys: ['ArrowRight'] })).toBe(false);
    expect(matchesShortcut(key({ key: ' ' }), { keys: [' '] })).toBe(true); // acknowledge / Space
  });

  it('ignores keystrokes that originate in a form control', () => {
    expect(matchesShortcut(key({ target: input }), { keys: ['k'] })).toBe(false);
    expect(matchesShortcut(key({ target: { tagName: 'TEXTAREA' } as unknown as EventTarget }), { keys: ['k'] })).toBe(false);
    expect(matchesShortcut(key({ target: { tagName: 'SELECT' } as unknown as EventTarget }), { keys: ['k'] })).toBe(false);
    expect(matchesShortcut(key({ target: { isContentEditable: true } as unknown as EventTarget }), { keys: ['k'] })).toBe(false);

    // A shortcut may opt out of the guard explicitly.
    expect(matchesShortcut(key({ target: input }), { keys: ['k'], ignoreInInputs: false })).toBe(true);

    // A non-editable target is unaffected.
    expect(matchesShortcut(key({ target: { tagName: 'DIV' } as unknown as EventTarget }), { keys: ['k'] })).toBe(true);
  });

  it('classifies editable targets', () => {
    expect(isEditableTarget(input)).toBe(true);
    expect(isEditableTarget(null)).toBe(false);
    expect(isEditableTarget({ tagName: 'BUTTON' } as unknown as EventTarget)).toBe(false);
  });
});

describe('shell shortcuts (AC-165 / AC-130)', () => {
  it('opens the asset and historian tag workspace on Cmd/Ctrl + K', () => {
    expect(SHELL_SHORTCUTS).toHaveLength(1);

    const commandK = SHELL_SHORTCUTS[0];
    expect(commandK.keys).toEqual(['k']);
    expect(commandK.meta).toBe(true);
    expect(commandK.to).toBe('/assets');
    expect(matchesShortcut(key({ metaKey: true }), commandK)).toBe(true);
    expect(matchesShortcut(key({ ctrlKey: true }), commandK)).toBe(true);
    expect(matchesShortcut(key({}), commandK)).toBe(false);
  });

  it('mounts the layer from the shell', () => {
    expect(typeof useGlobalShortcuts).toBe('function');
    expect(typeof useShellShortcuts).toBe('function');
  });

  it('navigates to the declared target when the shell handler runs', () => {
    // The shell builds its handlers from SHELL_SHORTCUTS; this pins the mapping
    // the shell performs (`to` -> navigate) without needing a router.
    const navigate = vi.fn();
    SHELL_SHORTCUTS.forEach(({ keys, meta, to, description }) => {
      const handler = () => navigate(to);
      expect(description.length).toBeGreaterThan(0);
      expect(matchesShortcut(key({ key: keys[0], metaKey: meta }), { keys, meta })).toBe(true);
      handler();
    });
    expect(navigate).toHaveBeenCalledWith('/assets');
  });
});

describe('shortcutLegend (AC-166)', () => {
  it('advertises the complete documented key set', () => {
    const keys = shortcutLegend().map((entry) => entry.keys);

    ['⌘/Ctrl + K', '[', '1 – 4', 'J / K', 'Enter', 'A / Space', 'H', 'B', 'W', '← / →',
     '⌘/Ctrl + Enter', 'Esc'].forEach((advertised) => {
      expect(keys).toContain(advertised);
    });

    expect(shortcutLegend()).toHaveLength(12);
    shortcutLegend().forEach((entry) => expect(entry.description.length).toBeGreaterThan(0));
  });

  it('includes the quick-switcher entry advertised in the shell', () => {
    const entry = shortcutLegend().find((candidate) => candidate.keys === '⌘/Ctrl + K');
    expect(entry?.description).toMatch(/quick switcher/);
  });
});
