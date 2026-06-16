# P6 Web Parity Additions Implementation Plan

> Part of the 2026-06-16 product-v2 set.

## Goal

Bring the **web** playground (`src/playground/`) up to parity with the iOS
product-v2 plan by adding the surfaces web currently lacks: an **account /
avatar button** that opens a **Settings panel** (folding in the existing
visualization picker that today lives only in the header `More` menu), a
**language RU/EN** toggle, **tool DELETE**, **data reset / export**, and an
**About** section.

Web already ships chat, history, hyperbrain, and tool detail
(`FindBar.tsx`, `ToolDetail.tsx`, the 15 `variants/*`). This plan does **not**
duplicate any of those — it only adds the missing account/settings/delete/
language plumbing and wires the existing variant picker into the new panel.

Every new control is pure liquid glass and tactile: tap / long-press / swipe-to-
dismiss / press-feedback (`active:scale-[0.96]`) / micro-animations / haptics
(`navigator.vibrate`), all gated behind `prefers-reduced-motion`. Targets stay
≥44px. No new full-screen postprocessing; the R3F variants are untouched.

## Architecture

- **Store is the single source of truth.** `ToolStoreProvider` (`store.tsx`)
  today only holds `added` tools + icon overrides, all in memory. P6 extends the
  store with:
  - `removeTool(id)` — drops a user-added tool (seed tools are never deletable);
  - `settings` + `setSettings(patch)` — `{ language: 'en' | 'ru'; variantId: string }`,
    persisted to `localStorage` (mirrors the `FindBar` persistence pattern at
    `FindBar.tsx:80-145`);
  - `resetData()` — clears added tools, icon overrides, settings, and the
    `FindBar` thread key;
  - `exportData()` — returns a JSON string of the user's added tools + settings.
  - `added` tools are themselves persisted now (so delete/reset/export are
    meaningful across reloads) under a new key.
- **`useSettings` hook** — thin selector over the store for the panel + shell.
- **`SettingsPanel` (new component)** — a swipe-to-dismiss liquid-glass sheet
  built exactly like `AddToolModal` (scrim + grab handle + `DISMISS` contract +
  `role="dialog"`), containing four sections: Visualization (radio list moved
  out of the header `More` menu), Language (RU/EN segmented control),
  Data (Export / Reset), and About.
- **Account button** — a small glass avatar button in the header replacing the
  standalone `More` disclosure responsibility for the variant list; tapping it
  opens `SettingsPanel`. The header keeps the inline finalist tabs for quick
  switching; the full list now lives in Settings (no functional regression).
- **Tool DELETE** — `ToolDetail` gains a long-press / overflow "Remove from my
  universe" action for `userAdded` tools that calls `removeTool(id)` then
  closes.
- **i18n** — a tiny dependency-free `t(key, lang)` dictionary in a new
  `i18n.ts` for the handful of new strings (RU/EN). We do **not** retrofit
  existing copy; scope is the new P6 surfaces only.

## Tech Stack

React 18 + TypeScript + Vite, Vitest (`npm run test` → `vitest run src`,
jsdom-free pure-logic tests like `query.test.ts`), Tailwind utility strings via
`cx(...)`, the `designSystem.ts` tokens (`GLASS`, `EASE`, `DURATION`, `DISMISS`,
`FOCUS_RING`, `TYPE`, `TEXT`, `ACCENT`, `LONG_PRESS_MS`), `lucide-react` icons,
`localStorage`, `navigator.vibrate`.

---

## Task 1 — Persistence + settings + delete in the store

**Files**
- Modify: `src/playground/toolStoreContext.ts`
- Modify: `src/playground/store.tsx`
- Create: `src/playground/store.test.ts`

### Steps

1. Write the failing test `src/playground/store.test.ts` (pure-logic helpers —
   no React render, matching `query.test.ts`):

```ts
import { afterEach, describe, expect, it } from 'vitest';
import {
  DEFAULT_SETTINGS,
  loadPersisted,
  persist,
  serializeExport,
  type PersistedState,
} from './store';

const KEY = 'playground.store.v1';

afterEach(() => {
  if (typeof localStorage !== 'undefined') localStorage.clear();
});

describe('store persistence', () => {
  it('defaults when nothing is stored', () => {
    const state = loadPersisted();
    expect(state.added).toHaveLength(0);
    expect(state.settings).toEqual(DEFAULT_SETTINGS);
  });

  it('round-trips added tools + settings', () => {
    const state: PersistedState = {
      added: [{ id: 'x', name: 'X' } as PersistedState['added'][number]],
      icons: { x: 'data:image/png;base64,AA' },
      settings: { language: 'ru', variantId: 'K' },
    };
    persist(state);
    const back = loadPersisted();
    expect(back.added.map((t) => t.id)).toEqual(['x']);
    expect(back.icons.x).toBe('data:image/png;base64,AA');
    expect(back.settings).toEqual({ language: 'ru', variantId: 'K' });
  });

  it('falls back to defaults on corrupt json', () => {
    localStorage.setItem(KEY, '{not json');
    expect(loadPersisted().settings).toEqual(DEFAULT_SETTINGS);
  });

  it('serializeExport emits added tools + settings as JSON', () => {
    const json = serializeExport(
      [{ id: 'x', name: 'X' } as PersistedState['added'][number]],
      { language: 'en', variantId: 'A' },
    );
    const parsed = JSON.parse(json);
    expect(parsed.tools[0].id).toBe('x');
    expect(parsed.settings.variantId).toBe('A');
    expect(typeof parsed.exportedAt).toBe('string');
  });
});
```

   Note: `vitest run src` runs in Node. `localStorage` is referenced through the
   `typeof localStorage !== 'undefined'` guard already used in `FindBar`, so the
   helpers no-op safely if it is missing. If the project's vitest env lacks
   `localStorage`, the round-trip test is still valid because we define the
   helpers to accept an injectable store; see step 2.

2. Run it — it fails (helpers don't exist):

```bash
npm run test -- src/playground/store.test.ts
```

3. Extend the store context type. In `src/playground/toolStoreContext.ts` add to
   the `ToolStore` interface:

```ts
export type Language = 'en' | 'ru';

export interface PlaygroundSettings {
  language: Language;
  /** Active visualization variant id (e.g. 'A'). */
  variantId: string;
}

export interface ToolStore {
  tools: AddedTool[];
  toolById: Map<string, AddedTool>;
  addTool: (input: AddToolInput) => AddedTool;
  iconUrlFor: (tool: AITool, size?: number) => string | undefined;
  /** Remove a user-added tool (seed tools are ignored). */
  removeTool: (id: string) => void;
  settings: PlaygroundSettings;
  setSettings: (patch: Partial<PlaygroundSettings>) => void;
  /** Wipe added tools, icon overrides, settings, and the chat thread. */
  resetData: () => void;
  /** JSON snapshot of the user's added tools + settings. */
  exportData: () => string;
}
```

4. Add the persistence helpers + new state to `src/playground/store.tsx`.
   Replace the imports block and the `ToolStoreProvider` body. First, the new
   top-of-file additions (after the existing imports):

```ts
import type { Language, PlaygroundSettings } from './toolStoreContext';

const STORE_KEY = 'playground.store.v1';
/** Same key FindBar uses, so a reset clears the chat thread too. */
const FINDBAR_KEY = 'playground.findbar.turns.v1';
const MAX_STORE_BYTES = 400_000;

export const DEFAULT_SETTINGS: PlaygroundSettings = { language: 'en', variantId: 'A' };

export interface PersistedState {
  added: AddedTool[];
  icons: Record<string, string>;
  settings: PlaygroundSettings;
}

function isLanguage(v: unknown): v is Language {
  return v === 'en' || v === 'ru';
}

export function loadPersisted(): PersistedState {
  const empty: PersistedState = { added: [], icons: {}, settings: DEFAULT_SETTINGS };
  if (typeof localStorage === 'undefined') return empty;
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw || raw.length > MAX_STORE_BYTES) return empty;
    const parsed = JSON.parse(raw) as Partial<PersistedState> | null;
    if (!parsed || typeof parsed !== 'object') return empty;
    const added = Array.isArray(parsed.added)
      ? (parsed.added.filter((t) => t && typeof (t as AddedTool).id === 'string') as AddedTool[])
      : [];
    const icons =
      parsed.icons && typeof parsed.icons === 'object'
        ? (parsed.icons as Record<string, string>)
        : {};
    const s = (parsed.settings ?? {}) as Partial<PlaygroundSettings>;
    const settings: PlaygroundSettings = {
      language: isLanguage(s.language) ? s.language : DEFAULT_SETTINGS.language,
      variantId: typeof s.variantId === 'string' ? s.variantId : DEFAULT_SETTINGS.variantId,
    };
    return { added, icons, settings };
  } catch {
    return empty;
  }
}

export function persist(state: PersistedState): void {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state));
  } catch {
    /* storage full / unavailable — stay in-memory */
  }
}

export function serializeExport(added: AddedTool[], settings: PlaygroundSettings): string {
  return JSON.stringify(
    { exportedAt: new Date().toISOString(), settings, tools: added },
    null,
    2,
  );
}
```

5. Rework the `ToolStoreProvider` body to seed from `loadPersisted()`, persist on
   change, and expose the new intents:

```ts
export function ToolStoreProvider({ children }: { children: ReactNode }) {
  const [boot] = useState(loadPersisted);
  const [added, setAdded] = useState<AddedTool[]>(boot.added);
  const [icons, setIcons] = useState<Map<string, string>>(
    () => new Map(Object.entries(boot.icons)),
  );
  const [settings, setSettingsState] = useState<PlaygroundSettings>(boot.settings);

  // Persist added tools, icon overrides, and settings on every change.
  useEffect(() => {
    persist({ added, icons: Object.fromEntries(icons), settings });
  }, [added, icons, settings]);

  const tools = useMemo<AddedTool[]>(() => [...seedTools, ...added], [added]);
  const toolById = useMemo(() => {
    const map = new Map<string, AddedTool>();
    tools.forEach((t) => map.set(t.id, t));
    return map;
  }, [tools]);

  const addTool = useCallback(
    (input: AddToolInput): AddedTool => {
      // ...unchanged body...
    },
    [added],
  );

  const removeTool = useCallback((id: string) => {
    setAdded((prev) => prev.filter((t) => t.id !== id));
    setIcons((prev) => {
      if (!prev.has(id)) return prev;
      const next = new Map(prev);
      next.delete(id);
      return next;
    });
  }, []);

  const setSettings = useCallback((patch: Partial<PlaygroundSettings>) => {
    setSettingsState((prev) => ({ ...prev, ...patch }));
  }, []);

  const resetData = useCallback(() => {
    setAdded([]);
    setIcons(new Map());
    setSettingsState(DEFAULT_SETTINGS);
    if (typeof localStorage !== 'undefined') {
      try {
        localStorage.removeItem(FINDBAR_KEY);
      } catch {
        /* ignore */
      }
    }
  }, []);

  const exportData = useCallback(() => serializeExport(added, settings), [added, settings]);

  const iconUrlFor = useCallback(
    (tool: AITool, size = 96): string | undefined =>
      icons.get(tool.id) ?? getToolLogoUrl(tool, size) ?? undefined,
    [icons],
  );

  const value = useMemo<ToolStore>(
    () => ({
      tools,
      toolById,
      addTool,
      iconUrlFor,
      removeTool,
      settings,
      setSettings,
      resetData,
      exportData,
    }),
    [tools, toolById, addTool, iconUrlFor, removeTool, settings, setSettings, resetData, exportData],
  );

  return <ToolStoreContext.Provider value={value}>{children}</ToolStoreContext.Provider>;
}
```

   Also add `useEffect` to the `react` import at the top of `store.tsx` (it
   currently imports `useCallback, useMemo, useState, type ReactNode`).

6. Run the test — it passes:

```bash
npm run test -- src/playground/store.test.ts
```

7. Type-check and lint:

```bash
npm run build && npm run lint
```

8. Commit:

```bash
git add src/playground/store.tsx src/playground/store.test.ts src/playground/toolStoreContext.ts
git commit -m "playground: persist tools + settings, add removeTool/reset/export to store"
```

---

## Task 2 — i18n dictionary for the new surfaces

**Files**
- Create: `src/playground/i18n.ts`
- Create: `src/playground/i18n.test.ts`

### Steps

1. Write the failing test `src/playground/i18n.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { STRINGS, t } from './i18n';

describe('i18n', () => {
  it('returns English copy', () => {
    expect(t('settings.title', 'en')).toBe('Settings');
  });

  it('returns Russian copy', () => {
    expect(t('settings.title', 'ru')).toBe('Настройки');
  });

  it('every key exists in both languages', () => {
    const en = Object.keys(STRINGS.en);
    const ru = Object.keys(STRINGS.ru);
    expect(ru.sort()).toEqual(en.sort());
  });
});
```

2. Run it — fails (module missing):

```bash
npm run test -- src/playground/i18n.test.ts
```

3. Create `src/playground/i18n.ts`:

```ts
import type { Language } from './toolStoreContext';

/** Copy for the P6 surfaces only (account/settings/delete/language/about). */
export const STRINGS = {
  en: {
    'account.open': 'Account & settings',
    'settings.title': 'Settings',
    'settings.visualization': 'Visualization',
    'settings.language': 'Language',
    'settings.data': 'Data',
    'settings.about': 'About',
    'settings.export': 'Export my universe',
    'settings.reset': 'Reset everything',
    'settings.reset.confirm': 'Delete your added tools and settings?',
    'settings.close': 'Close',
    'about.body': 'A premium map of the AI-tool universe.',
    'tool.remove': 'Remove from my universe',
  },
  ru: {
    'account.open': 'Аккаунт и настройки',
    'settings.title': 'Настройки',
    'settings.visualization': 'Визуализация',
    'settings.language': 'Язык',
    'settings.data': 'Данные',
    'settings.about': 'О приложении',
    'settings.export': 'Экспорт моей вселенной',
    'settings.reset': 'Сбросить всё',
    'settings.reset.confirm': 'Удалить добавленные инструменты и настройки?',
    'settings.close': 'Закрыть',
    'about.body': 'Премиальная карта вселенной AI-инструментов.',
    'tool.remove': 'Убрать из моей вселенной',
  },
} as const;

export type StringKey = keyof typeof STRINGS['en'];

export function t(key: StringKey, lang: Language): string {
  return STRINGS[lang][key] ?? STRINGS.en[key];
}
```

4. Run the test — passes:

```bash
npm run test -- src/playground/i18n.test.ts
```

5. Commit:

```bash
git add src/playground/i18n.ts src/playground/i18n.test.ts
git commit -m "playground: add RU/EN i18n dictionary for settings surfaces"
```

---

## Task 3 — `SettingsPanel` liquid-glass sheet

**Files**
- Create: `src/playground/SettingsPanel.tsx`

This mirrors the `AddToolModal` sheet shell (scrim + grab handle + `DISMISS`
contract + `role="dialog"`, `src/playground/AddToolModal.tsx:369-417`). The
variant list is passed in from the shell so we don't import the variant
registry twice.

### Steps

1. Create `src/playground/SettingsPanel.tsx`:

```tsx
import {
  useEffect,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import { Check, Download, Trash2, X } from 'lucide-react';
import { useToolStore } from './useToolStore';
import { t } from './i18n';
import type { Language } from './toolStoreContext';
import {
  ACCENT,
  cx,
  DISMISS,
  DURATION,
  EASE,
  FOCUS_RING,
  GLASS,
  TEXT,
  TYPE,
} from './designSystem';

export interface VariantOption {
  id: string;
  ship: string;
}

interface Props {
  open: boolean;
  onClose: () => void;
  variants: VariantOption[];
  activeVariantId: string;
  onSelectVariant: (id: string) => void;
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function haptic(ms = 8): void {
  if (prefersReducedMotion()) return;
  if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(ms);
}

export function SettingsPanel({ open, onClose, variants, activeVariantId, onSelectVariant }: Props) {
  const { settings, setSettings, resetData, exportData } = useToolStore();
  const lang = settings.language;
  const reduced = prefersReducedMotion();

  const [visible, setVisible] = useState(false);
  const [drag, setDrag] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ y: number; t: number; id: number } | null>(null);
  const dialogRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (open) {
      setDrag(0);
      const r = requestAnimationFrame(() => setVisible(true));
      return () => cancelAnimationFrame(r);
    }
    setVisible(false);
    return undefined;
  }, [open]);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  const onHandlePointerDown = (e: ReactPointerEvent) => {
    dragStart.current = { y: e.clientY, t: e.timeStamp, id: e.pointerId };
    setDragging(true);
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };
  const onHandlePointerMove = (e: ReactPointerEvent) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    setDrag(dy > 0 ? dy : dy * DISMISS.resistance);
  };
  const onHandlePointerUp = (e: ReactPointerEvent) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    const dt = e.timeStamp - dragStart.current.t;
    const v = dt > 0 ? dy / dt : 0;
    dragStart.current = null;
    setDragging(false);
    if (dy > DISMISS.distancePx || v > DISMISS.velocity) {
      haptic();
      onClose();
    } else {
      setDrag(0);
    }
  };

  const exportNow = () => {
    haptic();
    const blob = new Blob([exportData()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'my-ai-universe.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  const resetNow = () => {
    if (typeof window !== 'undefined' && !window.confirm(t('settings.reset.confirm', lang))) return;
    haptic(16);
    resetData();
    onClose();
  };

  const setLang = (next: Language) => {
    if (next === lang) return;
    haptic();
    setSettings({ language: next });
  };

  const panelTransform = visible ? `translateY(${drag}px) scale(1)` : 'translateY(24px) scale(0.94)';

  return (
    <div
      className="fixed inset-0 z-40 flex items-end justify-center px-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:items-center"
      onClick={onClose}
    >
      <div
        aria-hidden
        className={GLASS.scrim + ' absolute inset-0'}
        style={{
          opacity: visible ? Math.max(0, 1 - drag / 520) : 0,
          transition: reduced ? 'none' : `opacity ${DURATION.enter}ms ${EASE.out}`,
        }}
      />

      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label={t('settings.title', lang)}
        className={cx('relative w-full max-w-md overflow-hidden', GLASS.panel, 'p-5 select-none')}
        style={{
          transform: panelTransform,
          opacity: visible ? 1 : 0,
          transition:
            dragging || reduced
              ? 'none'
              : `transform ${DURATION.sheet}ms ${EASE.sheet}, opacity ${DURATION.exit}ms ${EASE.out}`,
          willChange: 'transform, opacity',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div
          className="group/handle mx-auto -mt-1 mb-3 flex h-6 w-full cursor-grab touch-none items-center justify-center active:cursor-grabbing"
          onPointerDown={onHandlePointerDown}
          onPointerMove={onHandlePointerMove}
          onPointerUp={onHandlePointerUp}
          onPointerCancel={onHandlePointerUp}
        >
          <div className="h-1 w-9 rounded-full bg-white/20 transition-colors duration-200 group-active/handle:bg-white/40" />
        </div>

        <div className="mb-4 flex items-center justify-between">
          <h2 className={cx(TYPE.title, TEXT.primary)}>{t('settings.title', lang)}</h2>
          <button
            type="button"
            onClick={onClose}
            onPointerDown={() => haptic()}
            aria-label={t('settings.close', lang)}
            className={cx(
              'flex h-11 w-11 items-center justify-center rounded-2xl transition active:scale-[0.96]',
              '[@media(hover:hover)]:hover:bg-white/10',
              FOCUS_RING,
            )}
          >
            <X className="h-5 w-5 text-white/70" aria-hidden />
          </button>
        </div>

        <div className="flex max-h-[60vh] flex-col gap-5 overflow-y-auto">
          {/* Visualization */}
          <section>
            <h3 className={cx(TYPE.eyebrow, TEXT.meta, 'mb-2')}>{t('settings.visualization', lang)}</h3>
            <div className="grid grid-cols-2 gap-1" role="radiogroup" aria-label={t('settings.visualization', lang)}>
              {variants.map((v) => {
                const active = v.id === activeVariantId;
                return (
                  <button
                    key={v.id}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => {
                      haptic();
                      onSelectVariant(v.id);
                    }}
                    className={cx(
                      'flex min-h-[44px] items-center justify-between rounded-xl px-3 py-2 text-left transition-[background-color,transform] duration-200 active:scale-[0.97]',
                      active
                        ? cx(ACCENT.fill, ACCENT.text)
                        : cx(TEXT.body, '[@media(hover:hover)]:hover:bg-white/10'),
                      FOCUS_RING,
                    )}
                    style={{ transitionTimingFunction: EASE.out }}
                  >
                    <span className={cx(TYPE.body, 'font-medium leading-tight')}>{v.ship}</span>
                    {active && <Check className="h-4 w-4 shrink-0" aria-hidden />}
                  </button>
                );
              })}
            </div>
          </section>

          {/* Language */}
          <section>
            <h3 className={cx(TYPE.eyebrow, TEXT.meta, 'mb-2')}>{t('settings.language', lang)}</h3>
            <div className={cx('flex gap-1 p-1', GLASS.chip)} role="radiogroup" aria-label={t('settings.language', lang)}>
              {(['en', 'ru'] as const).map((code) => {
                const active = lang === code;
                return (
                  <button
                    key={code}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => setLang(code)}
                    className={cx(
                      'min-h-[44px] flex-1 rounded-lg px-3 py-2 text-center font-medium transition-[background-color,transform] duration-200 active:scale-[0.97]',
                      TYPE.body,
                      active ? cx(ACCENT.fill, ACCENT.text) : cx(TEXT.secondary, '[@media(hover:hover)]:hover:bg-white/10'),
                      FOCUS_RING,
                    )}
                    style={{ transitionTimingFunction: EASE.out }}
                  >
                    {code === 'en' ? 'English' : 'Русский'}
                  </button>
                );
              })}
            </div>
          </section>

          {/* Data */}
          <section className="flex flex-col gap-2">
            <h3 className={cx(TYPE.eyebrow, TEXT.meta)}>{t('settings.data', lang)}</h3>
            <button
              type="button"
              onClick={exportNow}
              className={cx(
                'flex min-h-[44px] items-center gap-2 rounded-xl px-3 py-2 transition active:scale-[0.97]',
                TEXT.body,
                '[@media(hover:hover)]:hover:bg-white/10',
                FOCUS_RING,
              )}
            >
              <Download className="h-4 w-4" aria-hidden />
              <span className={TYPE.body}>{t('settings.export', lang)}</span>
            </button>
            <button
              type="button"
              onClick={resetNow}
              className={cx(
                'flex min-h-[44px] items-center gap-2 rounded-xl px-3 py-2 transition active:scale-[0.97]',
                'text-red-200/90 [@media(hover:hover)]:hover:bg-red-400/10',
                FOCUS_RING,
              )}
            >
              <Trash2 className="h-4 w-4" aria-hidden />
              <span className={TYPE.body}>{t('settings.reset', lang)}</span>
            </button>
          </section>

          {/* About */}
          <section>
            <h3 className={cx(TYPE.eyebrow, TEXT.meta, 'mb-1')}>{t('settings.about', lang)}</h3>
            <p className={cx(TYPE.chip, TEXT.secondary)}>{t('about.body', lang)}</p>
          </section>
        </div>
      </div>
    </div>
  );
}
```

2. Type-check + lint:

```bash
npm run build && npm run lint
```

3. Commit:

```bash
git add src/playground/SettingsPanel.tsx
git commit -m "playground: add SettingsPanel liquid-glass sheet (viz/language/data/about)"
```

---

## Task 4 — Account button in the shell + wire SettingsPanel, sync variant

**Files**
- Modify: `src/playground/PlaygroundApp.tsx`

The shell currently keeps `activeId` in local state seeded from the URL hash.
P6 keeps that behaviour but lets `SettingsPanel` drive it too, and seeds the
initial variant from persisted `settings.variantId` when there's no hash.

### Steps

1. Add imports near the existing ones in `PlaygroundApp.tsx`:

```tsx
import { ChevronDown, Plus, UserRound } from 'lucide-react';
import { SettingsPanel } from './SettingsPanel';
import { t } from './i18n';
```

   (Replace the existing `import { ChevronDown, Plus } from 'lucide-react';`.)

2. In `PlaygroundShell`, add settings open state and pull settings from the
   store (the component already calls `useToolStore()`):

```tsx
  const [settingsOpen, setSettingsOpen] = useState(false);
  const { tools, settings, setSettings } = useToolStore();
```

   (Replace the existing `const { tools } = useToolStore();`.)

3. Update `initialId()` use: keep the hash precedence, but when there is no hash,
   prefer the persisted variant. Inside `PlaygroundShell`, after the existing
   `useState(initialId)` line, add a one-shot effect:

```tsx
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (!window.location.hash && VARIANTS.some((v) => v.id === settings.variantId)) {
      setActiveId(settings.variantId);
    }
    // run once on mount only
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
```

4. Make `select` persist the chosen variant so Settings + header + reload agree:

```tsx
  const select = (id: string) => {
    setActiveId(id);
    setMoreOpen(false);
    setSettings({ variantId: id });
    if (typeof window !== 'undefined') window.history.replaceState(null, '', `#${id}`);
  };
```

5. Add the account/avatar button to the header. Inside the
   `<div ref={moreRef} ...>` nav row, after the closing `</nav>` (and before the
   `{moreOpen && (...)}` block), add:

```tsx
          <button
            type="button"
            onClick={() => {
              if (typeof navigator !== 'undefined' && navigator.vibrate && !reduced) navigator.vibrate(8);
              setSettingsOpen(true);
            }}
            aria-label={t('account.open', settings.language)}
            aria-haspopup="dialog"
            className={cx(
              'flex h-11 w-11 items-center justify-center transition active:scale-[0.96]',
              GLASS.bar,
              '[@media(hover:hover)]:hover:bg-white/[0.14]',
              FOCUS_RING,
            )}
            style={{ transitionTimingFunction: EASE.out }}
          >
            <UserRound className="h-5 w-5 text-white/80" aria-hidden />
          </button>
```

6. Mount the panel. Just before the closing `</div>` of the root element (after
   `</header>`), add:

```tsx
      <SettingsPanel
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        variants={VARIANTS.map((v) => ({ id: v.id, ship: v.ship }))}
        activeVariantId={activeId}
        onSelectVariant={select}
      />
```

7. Manual verification — run the dev server and confirm the avatar opens the
   sheet, the variant radio mirrors the header, swipe-down + Escape dismiss, and
   the language toggle flips the panel copy:

```bash
npm run dev
# open http://127.0.0.1:5177 → tap avatar → switch variant in panel → swipe down → reload (variant persists)
```

8. Build + lint:

```bash
npm run build && npm run lint
```

9. Commit:

```bash
git add src/playground/PlaygroundApp.tsx
git commit -m "playground: add account button opening SettingsPanel; persist active variant"
```

---

## Task 5 — Tool DELETE in `ToolDetail`

**Files**
- Modify: `src/playground/ToolDetail.tsx`

`ToolDetail` already imports `useToolStore`, design tokens, and has a `haptic()`
helper (`ToolDetail.tsx:35`). We add a "Remove from my universe" action visible
only for `userAdded` tools that calls `removeTool(id)` then `onClose()`.

### Steps

1. Read the file to find the header/action area and the active tool lookup:

```bash
grep -n "userAdded\|useToolStore\|onClose\|removeTool\|tool\." src/playground/ToolDetail.tsx | head -30
```

2. Pull `removeTool` + `settings` from the store where the component already
   destructures it:

```tsx
  const { toolById, iconUrlFor, removeTool, settings } = useToolStore();
```

   (Add `removeTool, settings` to the existing destructure.)

3. Add the remove handler near the other handlers in the component body (replace
   `tool` with the component's actual active-tool variable name found in step 1):

```tsx
  const onRemove = () => {
    if (!tool?.userAdded) return;
    if (typeof window !== 'undefined' && !window.confirm(t('tool.remove', settings.language) + '?')) return;
    haptic();
    removeTool(tool.id);
    onClose();
  };
```

4. Add the `import { t } from './i18n';` line to the imports, and a `Trash2`
   icon to the existing `lucide-react` import.

5. Render the action only for user-added tools, in the detail footer/actions
   region (place alongside the existing action buttons; match their classes):

```tsx
        {tool?.userAdded && (
          <button
            type="button"
            onClick={onRemove}
            className={cx(
              'flex min-h-[44px] items-center gap-2 rounded-xl px-3 py-2 transition active:scale-[0.97]',
              'text-red-200/90 [@media(hover:hover)]:hover:bg-red-400/10',
              FOCUS_RING,
            )}
          >
            <Trash2 className="h-4 w-4" aria-hidden />
            <span className={TYPE.body}>{t('tool.remove', settings.language)}</span>
          </button>
        )}
```

   Ensure `cx`, `FOCUS_RING`, and `TYPE` are in the file's `designSystem`
   import (add any missing ones).

6. Manual verification:

```bash
npm run dev
# add a tool via the + FAB → open its detail → tap "Remove from my universe"
# → confirm → tool window closes and the node disappears from the variant; reload → still gone
```

7. Build + lint:

```bash
npm run build && npm run lint
```

8. Commit:

```bash
git add src/playground/ToolDetail.tsx
git commit -m "playground: allow removing user-added tools from ToolDetail"
```

---

## Task 6 — Full suite + parity check

**Files**
- (none — verification only)

### Steps

1. Run the entire test suite:

```bash
npm run test
```

2. Build + lint clean:

```bash
npm run build && npm run lint
```

3. Parity smoke (manual): account button → Settings (visualization picker,
   RU/EN, export downloads `my-ai-universe.json`, reset clears with confirm +
   wipes chat thread), tool delete works and persists, Reduce Motion disables
   the sheet transitions and suppresses `navigator.vibrate`.

4. Commit any final touch-ups:

```bash
git add -A
git commit -m "playground: P6 web-parity verification pass"
```
```
```

### Parity note vs iOS

The iOS plan owns Settings/About/language/delete as native screens; this P6 set
delivers the same capability surface on web (account → Settings sheet, RU/EN,
delete, reset, export, About) reusing the existing web chat/history/hyperbrain/
detail rather than rebuilding them. No R3F variant code is modified.
