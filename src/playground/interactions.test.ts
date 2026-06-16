import { describe, expect, it, vi, beforeEach } from 'vitest';
import {
  haptic,
  fireHaptic,
  prefersReducedMotion,
  shouldDismiss,
  rubberBand,
} from './interactions';
import { DISMISS } from './designSystem';

describe('interactions', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('haptic() calls navigator.vibrate with the default 8ms tick', () => {
    const vibrate = vi.fn();
    vi.stubGlobal('navigator', { vibrate });
    haptic();
    expect(vibrate).toHaveBeenCalledWith(8);
  });

  it('fireHaptic(ms) forwards a custom duration', () => {
    const vibrate = vi.fn();
    vi.stubGlobal('navigator', { vibrate });
    fireHaptic(20);
    expect(vibrate).toHaveBeenCalledWith(20);
  });

  it('haptic() is a no-op when navigator.vibrate is missing', () => {
    vi.stubGlobal('navigator', {});
    expect(() => haptic()).not.toThrow();
  });

  it('prefersReducedMotion reads the reduce media query', () => {
    vi.stubGlobal('window', {
      matchMedia: (q: string) => ({ matches: q.includes('reduce') }),
    });
    expect(prefersReducedMotion()).toBe(true);
  });

  it('drag-dismiss commits past distance OR a downward flick over velocity', () => {
    // committed by distance alone (slow drag, zero velocity)
    expect(shouldDismiss(DISMISS.distancePx + 1, 0)).toBe(true);
    // committed by velocity alone (short flick)
    expect(shouldDismiss(10, DISMISS.velocity + 0.1)).toBe(true);
    // neither → springs back
    expect(shouldDismiss(10, 0)).toBe(false);
  });

  it('rubberBand follows down 1:1 and resists upward over-drag', () => {
    expect(rubberBand(50)).toBe(50);
    expect(rubberBand(-100)).toBe(-100 * DISMISS.resistance);
  });
});
