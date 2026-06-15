import { describe, expect, it } from 'vitest';
import { overviewFraming, OVERVIEW_BASE_HEIGHT, OVERVIEW_BASE_DEPTH } from './cameraFraming';

describe('overviewFraming', () => {
  it('uses the desktop baseline at wide aspect', () => {
    const wide = overviewFraming(1.6);
    expect(wide.height).toBeCloseTo(OVERVIEW_BASE_HEIGHT, 5);
    expect(wide.depth).toBeCloseTo(OVERVIEW_BASE_DEPTH, 5);
  });

  it('clamps very wide aspect to the baseline (no over-zoom)', () => {
    const ultrawide = overviewFraming(3.2);
    expect(ultrawide.height).toBeCloseTo(OVERVIEW_BASE_HEIGHT, 5);
    expect(ultrawide.depth).toBeCloseTo(OVERVIEW_BASE_DEPTH, 5);
  });

  it('pulls the camera in as the viewport gets narrower', () => {
    // Narrow portrait zooms in so the wide-but-thin scene fills the taller
    // frame (denser nodes, no empty band) instead of sitting small and high.
    expect(overviewFraming(0.5).depth).toBeLessThan(overviewFraming(1.0).depth);
    expect(overviewFraming(1.0).depth).toBeLessThan(overviewFraming(1.5).depth);
  });

  it('flattens the downward tilt as the viewport gets narrower', () => {
    // Lower camera height = flatter look = the vertically-thin scene centres
    // instead of leaving an empty band on tall portrait.
    expect(overviewFraming(0.5).height).toBeLessThan(overviewFraming(1.0).height);
    expect(overviewFraming(1.0).height).toBeLessThanOrEqual(overviewFraming(1.5).height);
  });

  it('clamps the narrow end (extreme aspect ratios stay bounded)', () => {
    const narrowest = overviewFraming(0.5);
    const beyond = overviewFraming(0.2);
    expect(beyond.depth).toBeCloseTo(narrowest.depth, 5);
    expect(beyond.height).toBeCloseTo(narrowest.height, 5);
  });

  it('never produces a negative or zero depth/height', () => {
    for (let a = 0.2; a <= 3.5; a += 0.1) {
      const f = overviewFraming(a);
      expect(f.depth).toBeGreaterThan(0);
      expect(f.height).toBeGreaterThan(0);
    }
  });
});
