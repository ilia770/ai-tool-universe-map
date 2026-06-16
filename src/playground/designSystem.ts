/**
 * Playground design tokens — the single, dependency-free source of truth the
 * shell components import. Values are calibrated against the liquid-glass +
 * ChatGPT/Duolingo/Linear/visionOS references and the overnight reviews.
 *
 * Rules of the road:
 * - Glass strings are Tailwind utility strings; compose with `cx(...)`.
 * - Never re-hand-code glass/radii/shadow in a component — reference these.
 * - Tint is semantic only (ACCENT for focus/active; SEMANTIC for state).
 *
 * The companion spec is docs/design/PLAYGROUND_DESIGN_SYSTEM.md.
 */

import { categories, categoryById } from '../data/ai-tool-universe';
import type { ToolCategoryId } from '../data/ai-tool-universe';

/** Tiny class-name joiner (drops falsy entries). */
export function cx(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(' ');
}

/* ------------------------------------------------------------------ */
/* Color roles                                                         */
/* ------------------------------------------------------------------ */

/** The one product accent (cyan) — wins 3/4 finalists. Focus + active only. */
export const ACCENT = {
  /** rgba for focus rings / glows (sky-300-ish, ≥3:1 on #03040a). */
  ring: 'rgba(125, 211, 252, 0.9)',
  text: 'text-cyan-200',
  textDim: 'text-cyan-200/70',
  /** translucent fill over blur for active/selected glass. */
  fill: 'bg-cyan-300/15',
  border: 'border-cyan-300/30',
} as const;

/** Base canvas color. One value; variants only layer gradients on top. */
export const BG_BASE = '#03040a';

/** Text-opacity ladder over the dark base (AA-tuned). */
export const TEXT = {
  primary: 'text-white/85',
  body: 'text-white/80',
  secondary: 'text-white/60',
  /** smallest legible step; reserve for non-essential meta only. */
  meta: 'text-white/55',
  placeholder: 'placeholder-white/40',
} as const;

/** Semantic state colors — never decorative. */
export const SEMANTIC = {
  positive: 'text-emerald-300/85',
  caution: 'text-amber-300/85',
  danger: 'text-red-200/85',
} as const;

/* ------------------------------------------------------------------ */
/* Glass material levels                                               */
/* ------------------------------------------------------------------ */

/**
 * Glass surfaces. Every glass = blur + saturate + translucent fill + inner
 * specular top-highlight + soft outer shadow (never blur alone). No
 * `bg-black/*` dark-tint glass anywhere; that material is banned.
 */
export const GLASS = {
  /** Primary modal / hero sheet (AddToolModal, ToolDetail, FindBar bar). */
  panel: cx(
    'rounded-3xl border border-white/10 bg-white/[0.07]',
    'backdrop-blur-2xl backdrop-saturate-[1.7]',
    'shadow-[0_24px_80px_rgba(0,0,0,0.55),inset_0_1px_0_0_rgba(255,255,255,0.14)]',
  ),
  /** Floating secondary panel (variant HUDs, peek bubble). */
  floating: cx(
    'rounded-2xl border border-white/10 bg-white/[0.07]',
    'backdrop-blur-2xl backdrop-saturate-[1.7]',
    'shadow-[0_12px_40px_rgba(0,0,0,0.45),inset_0_1px_0_0_rgba(255,255,255,0.14)]',
  ),
  /** Resting nav / chrome bar (header nav). */
  bar: cx(
    'rounded-2xl border border-white/10 bg-white/[0.07]',
    'backdrop-blur-2xl backdrop-saturate-[1.7]',
    'shadow-[0_8px_30px_rgba(0,0,0,0.35),inset_0_1px_0_0_rgba(255,255,255,0.12)]',
  ),
  /** Chip / small control surface. */
  chip: 'rounded-xl border border-white/10 bg-white/[0.06]',
  /** Dim scrim behind a live modal (only place blur is allowed without glass). */
  scrim: 'bg-black/50 backdrop-blur-sm',
} as const;

/* ------------------------------------------------------------------ */
/* Radius / spacing scale                                              */
/* ------------------------------------------------------------------ */

/** Radius tokens by role. ~40px icon buttons all share `control`. */
export const RADIUS = {
  chip: 'rounded-xl', // 12px — chips, small controls, inputs
  panel: 'rounded-2xl', // 16px — mid panels, cards
  sheet: 'rounded-3xl', // 24px — primary/modal sheets
  control: 'rounded-2xl', // 16px — all ~40px icon buttons (FAB/send/close)
  pill: 'rounded-full', // pills / toggles only
} as const;

/** Padding tokens. Standard panels `p-4`; primary modal/hero `p-5`. */
export const SPACE = {
  panel: 'p-4',
  sheet: 'p-5',
  row: 'px-3 py-2',
} as const;

/* ------------------------------------------------------------------ */
/* Type scale                                                          */
/* ------------------------------------------------------------------ */

/** 5-step type scale. No arbitrary `text-[Npx]` outside this set. */
export const TYPE = {
  eyebrow: 'text-[10px] font-medium uppercase tracking-[0.2em]', // one tracking, one size
  chip: 'text-xs', // chips / secondary
  body: 'text-sm', // body
  title: 'text-base font-semibold', // panel / sheet title
} as const;

/* ------------------------------------------------------------------ */
/* Shadows / elevation                                                 */
/* ------------------------------------------------------------------ */

/** 3 elevation tokens (Tailwind shadow presets are banned). */
export const SHADOW = {
  resting: 'shadow-[0_8px_30px_rgba(0,0,0,0.35)]',
  floating: 'shadow-[0_12px_40px_rgba(0,0,0,0.45)]',
  modal: 'shadow-[0_24px_80px_rgba(0,0,0,0.55)]',
  /** inner specular top-highlight every glass surface carries. */
  highlight: 'shadow-[inset_0_1px_0_0_rgba(255,255,255,0.14)]',
} as const;

/* ------------------------------------------------------------------ */
/* Motion tokens                                                       */
/* ------------------------------------------------------------------ */

/** Durations (ms). Response layer is fast; sheets are slower hero moments. */
export const DURATION = {
  press: 90, // button / toggle press-down
  hover: 150, // hover / focus glow
  state: 200, // state swap, send-icon morph
  enter: 300, // standard fade / focus ring
  turn: 460, // message / turn / section enter
  sheet: 360, // sheet / modal present
  exit: 260, // sheet dismiss (snappier than enter)
  peek: 400, // long-press peek present
  celebrate: 600, // rare milestone burst
} as const;

/** Stagger steps (ms) for list / chip reveals. Cap the count at ~6. */
export const STAGGER = {
  chip: 45,
  section: 42,
  word: 16, // per-word stream fade
} as const;

/** Long-press threshold (ms) and move-cancel slop (px). */
export const LONG_PRESS_MS = 420;
export const LONG_PRESS_SLOP_PX = 10;

/** Easing curves. */
export const EASE = {
  /** iOS-feeling ease-out — the default for ~80% of motion. */
  out: 'cubic-bezier(0.22, 1, 0.36, 1)',
  /** iOS sheet present/dismiss curve. */
  sheet: 'cubic-bezier(0.32, 0.72, 0, 1)',
  /** Duolingo response-layer ease (no overshoot). */
  response: 'cubic-bezier(0.4, 0, 0.2, 1)',
  /** Gentle overshoot — celebration / icon settle ONLY. */
  back: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
} as const;

/* ------------------------------------------------------------------ */
/* Gesture thresholds (unified across all sheets)                      */
/* ------------------------------------------------------------------ */

/** One dismiss contract: down past distance OR a downward flick. */
export const DISMISS = {
  /** px of downward drag that commits a dismiss. */
  distancePx: 100,
  /** downward release velocity (px/ms) that commits even on a short flick. */
  velocity: 0.5,
  /** rubber-band resistance applied to over-drag past the axis. */
  resistance: 0.25,
} as const;

/* ------------------------------------------------------------------ */
/* Focus ring (shared)                                                 */
/* ------------------------------------------------------------------ */

/** Apply to every interactive control for keyboard parity. */
export const FOCUS_RING =
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300/80 focus-visible:ring-offset-2 focus-visible:ring-offset-[#03040a]';

/** Gate hover lifts behind a real pointer so they don't stick on touch. */
export const HOVER_LIFT = '[@media(hover:hover)]:hover:-translate-y-0.5';

/* ------------------------------------------------------------------ */
/* Category colors (8) — re-exported from the data layer               */
/* ------------------------------------------------------------------ */

/** id → hex for the 8 tool categories. Single source: the seed data. */
export const CATEGORY_COLORS: Record<ToolCategoryId, string> = categories.reduce(
  (acc, c) => {
    acc[c.id] = c.color;
    return acc;
  },
  {} as Record<ToolCategoryId, string>,
);

/** Look up a category's accent hex, with a neutral fallback. */
export function categoryColor(id: ToolCategoryId | string): string {
  return categoryById.get(id as ToolCategoryId)?.color ?? '#3a3f55';
}

/** Translucent category fill for a tinted chip/plate (hex + alpha suffix). */
export function categoryTint(id: ToolCategoryId | string, alphaHex = '33'): string {
  return `${categoryColor(id)}${alphaHex}`;
}
