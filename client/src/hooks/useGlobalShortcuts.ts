/**
 * — the global keyboard ergonomics layer.
 *
 * Mounted once, in the application shell, so every authenticated page inherits
 * the same shortcuts. Handlers are registered on the capture phase but ignore
 * events that originate in a form control, so typing in a field never triggers
 * navigation.
 */
import { useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';

export interface Shortcut {
  /** Keys as they appear in `event.key`, e.g. 'k', '1', 'ArrowLeft'. */
  keys: string[];
  /** Require Cmd on macOS / Ctrl elsewhere. */
  meta?: boolean;
  /** Require Shift. */
  shift?: boolean;
  description: string;
  handler: () => void;
  /** Skip when focus is inside an input/textarea/select. Default true. */
  ignoreInInputs?: boolean;
}

/** The keystroke shape the matcher needs — a real KeyboardEvent satisfies it. */
export interface ShortcutKeystroke {
  key: string;
  metaKey?: boolean;
  ctrlKey?: boolean;
  shiftKey?: boolean;
  target?: EventTarget | null;
}

/** True when the event originated in a text field, so shortcuts must not fire. */
export function isEditableTarget(target: EventTarget | null | undefined): boolean {
  if (!target || typeof target !== 'object') return false;

  const candidate = target as { tagName?: string; isContentEditable?: boolean };
  if (candidate.isContentEditable) return true;

  return ['INPUT', 'TEXTAREA', 'SELECT'].includes(candidate.tagName ?? '');
}

/**
 * The complete matching rule for one keystroke.
 *
 * Exported so the rule itself is unit-testable without a DOM: modifier
 * agreement (Cmd/Ctrl treated as one), the literal-key match (case-insensitive
 * for single characters), and the "never fire while typing" guard.
 */
export function matchesShortcut(
  event: ShortcutKeystroke,
  shortcut: Pick<Shortcut, 'keys' | 'meta' | 'shift' | 'ignoreInInputs'>,
): boolean {
  const meta = Boolean(event.metaKey) || Boolean(event.ctrlKey);
  if (Boolean(shortcut.meta) !== meta) return false;
  if (Boolean(shortcut.shift) !== Boolean(event.shiftKey)) return false;

  const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  if (!shortcut.keys.some((candidate) => candidate.toLowerCase() === key.toLowerCase())) return false;

  const ignore = shortcut.ignoreInInputs !== false;
  if (ignore && isEditableTarget(event.target)) return false;

  return true;
}

export function useGlobalShortcuts(shortcuts: Shortcut[], enabled = true) {
  useEffect(() => {
    if (!enabled) return undefined;

    const onKeyDown = (event: KeyboardEvent) => {
      for (const shortcut of shortcuts) {
        if (!matchesShortcut(event, shortcut)) continue;

        event.preventDefault();
        shortcut.handler();
        return;
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [shortcuts, enabled]);
}

/** A shell shortcut as data, so the wiring is testable without a DOM. */
export interface ShellShortcutDefinition {
  keys: string[];
  meta?: boolean;
  /** Route the shortcut opens. */
  to: string;
  description: string;
}

/**
 * The shell-level shortcut set.
 *
 * Mounted once by the application shell so every authenticated workspace
 * inherits it. `Cmd/Ctrl + K` opens the asset & historian tag quick-switcher
 * entry point (`/assets`, whose search spans tags and equipment numbers).
 */
export const SHELL_SHORTCUTS: ShellShortcutDefinition[] = [
  {
    keys: ['k'],
    meta: true,
    to: '/assets',
    description: 'Open the asset & historian tag quick switcher',
  },
];

export function useShellShortcuts() {
  const navigate = useNavigate();

  const shortcuts = useMemo<Shortcut[]>(
    () =>
      SHELL_SHORTCUTS.map(({ keys, meta, to, description }) => ({
        keys,
        meta,
        description,
        handler: () => navigate(to),
      })),
    [navigate],
  );

  useGlobalShortcuts(shortcuts);
}

/** The canonical key map the shell advertises in the shortcut help. */
export function shortcutLegend(): Array<{ keys: string; description: string }> {
  return [
    { keys: '⌘/Ctrl + K', description: 'Open the asset & historian tag quick switcher' },
    { keys: '[', description: 'Collapse / expand the ISA-95 hierarchy sidebar' },
    { keys: '1 – 4', description: 'Filter the fleet by operating unit (CDU / FCC / HCU / ALKY)' },
    { keys: 'J / K', description: 'Move down / up the asset rows' },
    { keys: 'Enter', description: 'Open the highlighted asset' },
    { keys: 'A / Space', description: 'Acknowledge the active anomaly alert' },
    { keys: 'H', description: 'Toggle harmonic peak overlay markers' },
    { keys: 'B', description: 'Toggle bearing kinematic defect markers' },
    { keys: 'W', description: 'Toggle 2D spectrum / 3D waterfall' },
    { keys: '← / →', description: 'Scrub the waterfall time slices' },
    { keys: '⌘/Ctrl + Enter', description: 'Confirm and dispatch the work order' },
    { keys: 'Esc', description: 'Close the active modal, drawer or selection' },
  ];
}
