/**
 * Shared interaction primitives for the playground shell. Previously these
 * were copy-pasted into FindBar/ToolDetail/AddToolModal/SettingsPanel; this is
 * the single source so every P1–P6 surface gets identical tap/peek/swipe/
 * haptic/reduce-motion behavior. Pair with the tokens in `designSystem.ts`.
 */
import { useEffect, useState } from 'react';
import { DISMISS, LONG_PRESS_MS, LONG_PRESS_SLOP_PX } from './designSystem';

/** True when the user asked for reduced motion (SSR-safe). */
export function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    !!window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

/** Reactive reduce-motion hook — re-renders when the OS preference flips. */
export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(prefersReducedMotion);
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);
  return reduced;
}

/** Fire a tactile tick. Default 8ms = the standard "tap landed" cue. */
export function fireHaptic(ms = 8): void {
  if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
    navigator.vibrate(ms);
  }
}

/** Convenience alias for the default tick (matches existing call sites). */
export function haptic(): void {
  fireHaptic(8);
}

/** Unified dismiss contract: past distance OR a downward flick over velocity. */
export function shouldDismiss(dy: number, velocity: number): boolean {
  return dy > DISMISS.distancePx || velocity > DISMISS.velocity;
}

/** Rubber-band an over-drag past the dismiss axis (follow 1:1 downward). */
export function rubberBand(dy: number): number {
  return dy > 0 ? dy : dy * DISMISS.resistance;
}

export { LONG_PRESS_MS, LONG_PRESS_SLOP_PX };
