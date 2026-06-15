// Aspect-aware overview camera framing (QA findings 1 + 2).
//
// The scene used one fixed camera offset for every viewport. The category
// ellipse is WIDE (radiusX 4.55) and VERTICALLY THIN, and three.js fov is
// vertical — so on a tall/narrow portrait the fixed framing leaves the scene
// small and high with an empty band below (finding 2), and the nodes read as
// a tight unreadable cluster (finding 1). This module maps viewport aspect to
// the overview camera's height (downward tilt) and depth (distance):
//
//   - Wide (desktop) aspect: the untouched baseline — that surface is already
//     good, so we must not change it.
//   - Narrower: pull the camera IN (less depth) so the scene fills the taller
//     frame — denser, more readable, and no stranded band — and lower the
//     height (flatter tilt) so it centres. Edge categories sit closer to the
//     frame edge, which is fine on web: tool labels are viewport-clamped HTML
//     overlays, not in-scene billboards, so they stay readable.
//
// Pure + framework-free so it's unit-tested in cameraFraming.test.ts; the
// CameraController samples it from the live viewport aspect.

/** Desktop-baseline camera height above the look target (downward tilt). */
export const OVERVIEW_BASE_HEIGHT = 6.3;
/** Desktop-baseline camera distance behind the look target. */
export const OVERVIEW_BASE_DEPTH = 19.5;

/** At/above this aspect, use the baseline unchanged. */
const WIDE_ASPECT = 1.5;
/** At/below this aspect, framing is fully clamped to the portrait extreme. */
const NARROW_ASPECT = 0.5;

/** Distance removed at the narrow extreme so the scene fills the tall frame. */
const DEPTH_REDUCE = 5.5;
/** Height removed at the narrow extreme to flatten the tilt and centre. */
const HEIGHT_DROP = 2.5;

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, value));
}

export interface OverviewFraming {
  /** Camera Y above the look target. */
  height: number;
  /** Camera Z behind the look target. */
  depth: number;
}

/**
 * Overview camera offsets for a viewport `aspect` (width / height).
 * `t` ramps 0 (wide/desktop) → 1 (narrow/portrait), clamped at both ends.
 */
export function overviewFraming(aspect: number): OverviewFraming {
  const t = clamp01((WIDE_ASPECT - aspect) / (WIDE_ASPECT - NARROW_ASPECT));
  return {
    height: OVERVIEW_BASE_HEIGHT - t * HEIGHT_DROP,
    depth: OVERVIEW_BASE_DEPTH - t * DEPTH_REDUCE,
  };
}
