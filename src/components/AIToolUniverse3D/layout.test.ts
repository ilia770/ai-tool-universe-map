import { describe, expect, it } from 'vitest';
import {
  POCKET_WORLD_RADIUS,
  categoryPosition,
  pocketToolPosition,
  toolPosition,
} from './layout';

const CATEGORY_RADIUS_X = 4.55;
const CATEGORY_RADIUS_Z = 3.45;

const isFiniteVec = (vec: [number, number, number]) =>
  vec.every((component) => Number.isFinite(component));

const length = (vec: [number, number, number]) =>
  Math.hypot(vec[0], vec[1], vec[2]);

const distance = (a: [number, number, number], b: [number, number, number]) =>
  Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

describe('categoryPosition', () => {
  it('places angle 0 on the +x axis at the x radius with zero z', () => {
    const [x, y, z] = categoryPosition(0);
    expect(x).toBeCloseTo(CATEGORY_RADIUS_X, 6);
    expect(y).toBeCloseTo(0, 6);
    expect(z).toBeCloseTo(0, 6);
  });

  it('wraps the horizontal (x,z) ring at 360 but NOT the vertical lift', () => {
    // The xz ring uses cos/sin(rad) so it is 360-periodic, but the vertical
    // lift uses sin(rad * 1.7), a non-integer harmonic, so y at 360 differs
    // from y at 0. This is intentional source behaviour, not a bug.
    const at0 = categoryPosition(0);
    const at360 = categoryPosition(360);
    expect(at360[0]).toBeCloseTo(at0[0], 6);
    expect(at360[2]).toBeCloseTo(at0[2], 6);
    expect(at360[1]).not.toBeCloseTo(at0[1], 3);
  });

  it('places angle 90 on the +z axis at the z radius with near-zero x', () => {
    const [x, , z] = categoryPosition(90);
    expect(x).toBeCloseTo(0, 6);
    expect(z).toBeCloseTo(CATEGORY_RADIUS_Z, 6);
  });

  it('mirrors x across 180 and z across 270', () => {
    expect(categoryPosition(180)[0]).toBeCloseTo(-CATEGORY_RADIUS_X, 6);
    expect(categoryPosition(270)[2]).toBeCloseTo(-CATEGORY_RADIUS_Z, 6);
  });

  it('keeps the vertical lift inside the documented +/-1.35 band for any angle', () => {
    for (let angle = 0; angle < 360; angle += 5) {
      const y = categoryPosition(angle)[1];
      expect(y).toBeGreaterThanOrEqual(-1.35 - 1e-9);
      expect(y).toBeLessThanOrEqual(1.35 + 1e-9);
    }
  });

  it('returns finite components for negative and large angles', () => {
    expect(isFiniteVec(categoryPosition(-45))).toBe(true);
    expect(isFiniteVec(categoryPosition(1080))).toBe(true);
  });
});

describe('toolPosition', () => {
  it('returns the origin for orbit 0 regardless of angles', () => {
    expect(toolPosition(0, 0, 0)).toEqual([0, 0, 0]);
    expect(toolPosition(137, 0, 215)).toEqual([0, 0, 0]);
  });

  it('anchors a tool to its category centre offset by the orbit radius', () => {
    const categoryAngle = 30;
    const [catX, catY, catZ] = categoryPosition(categoryAngle);
    const [x, , z] = toolPosition(0, 1, categoryAngle);
    // angle 0 -> cos = 1, sin = 0, so it offsets along +x by the orbit radius.
    expect(x).toBeCloseTo(catX + 0.96, 6);
    expect(z).toBeCloseTo(catZ, 6);
    void catY;
  });

  it('grows the orbital radius monotonically with orbit index', () => {
    const categoryAngle = 0;
    const center = categoryPosition(categoryAngle);
    // Measure horizontal (xz) offset at angle 0 where vertical lift is shared.
    const horizontalOffset = (orbit: 0 | 1 | 2 | 3) => {
      const [x, , z] = toolPosition(0, orbit, categoryAngle);
      return Math.hypot(x - center[0], z - center[2]);
    };
    expect(horizontalOffset(1)).toBeLessThan(horizontalOffset(2));
    expect(horizontalOffset(2)).toBeLessThan(horizontalOffset(3));
  });

  it('produces finite positions across a sweep of angles and orbits', () => {
    for (const orbit of [1, 2, 3] as const) {
      for (let angle = 0; angle <= 360; angle += 15) {
        for (const categoryAngle of [0, 90, 180, 270]) {
          expect(isFiniteVec(toolPosition(angle, orbit, categoryAngle))).toBe(true);
        }
      }
    }
  });

  it('wraps the horizontal offset at 360 but not the vertical lift', () => {
    // cos/sin(toolRad) repeat at 360, but verticalLift uses sin(toolRad * 1.35)
    // so the y component is not 360-periodic. Confirm the documented behaviour.
    const a = toolPosition(0, 2, 45);
    const b = toolPosition(360, 2, 45);
    expect(b[0]).toBeCloseTo(a[0], 6);
    expect(b[2]).toBeCloseTo(a[2], 6);
    expect(b[1]).not.toBeCloseTo(a[1], 3);
  });
});

describe('pocketToolPosition', () => {
  it('returns the origin for orbit 0', () => {
    expect(pocketToolPosition(0, 0, 0)).toEqual([0, 0, 0]);
    expect(pocketToolPosition(90, 0, 180, 3, 8)).toEqual([0, 0, 0]);
  });

  it('never produces NaN even when slotCount is 0 (sqrt(max(0,...)) guard)', () => {
    // safeSlotCount clamps to 1; y = 1 - 0.5*2 = 0, yRadius = sqrt(max(0,1)) = 1.
    const vec = pocketToolPosition(45, 2, 0, 0, 0);
    expect(isFiniteVec(vec)).toBe(true);
  });

  it('guards sqrt against a negative radicand for the extreme top slot', () => {
    // slotIndex 0 of a single slot gives y = 0 exactly; the first slot of a
    // large set pushes y towards +1 where 1 - y*y is a tiny positive number.
    const top = pocketToolPosition(0, 3, 0, 0, 64);
    expect(isFiniteVec(top)).toBe(true);
  });

  it('produces finite positions across full slot distributions', () => {
    const slotCount = 12;
    for (let slotIndex = 0; slotIndex < slotCount; slotIndex += 1) {
      const vec = pocketToolPosition(slotIndex * 30, 2, 90, slotIndex, slotCount);
      expect(isFiniteVec(vec)).toBe(true);
    }
  });

  it('spreads slots so no two occupy the same point (non-overlap)', () => {
    const slotCount = 10;
    const points: [number, number, number][] = [];
    for (let slotIndex = 0; slotIndex < slotCount; slotIndex += 1) {
      points.push(pocketToolPosition(0, 3, 0, slotIndex, slotCount));
    }
    for (let i = 0; i < points.length; i += 1) {
      for (let j = i + 1; j < points.length; j += 1) {
        expect(distance(points[i], points[j])).toBeGreaterThan(0.05);
      }
    }
  });

  it('keeps every slot inside the pocket world radius around its category', () => {
    const categoryAngle = 0;
    const center = categoryPosition(categoryAngle);
    const slotCount = 16;
    for (let slotIndex = 0; slotIndex < slotCount; slotIndex += 1) {
      const vec = pocketToolPosition(slotIndex * 23, 3, categoryAngle, slotIndex, slotCount);
      const radial = distance(vec, center);
      expect(radial).toBeLessThanOrEqual(POCKET_WORLD_RADIUS + 1e-6);
    }
  });

  it('grows the outer-slot radius with orbit index', () => {
    const categoryAngle = 0;
    const center = categoryPosition(categoryAngle);
    // Use a mid slot (y away from the poles) so yRadius is non-trivial.
    const radial = (orbit: 1 | 2 | 3) =>
      distance(pocketToolPosition(45, orbit, categoryAngle, 4, 9), center);
    expect(radial(1)).toBeLessThan(radial(2));
    expect(radial(2)).toBeLessThan(radial(3));
  });

  it('exposes a positive pocket world radius constant', () => {
    expect(POCKET_WORLD_RADIUS).toBeGreaterThan(0);
  });

  it('defaults slotIndex/slotCount to a single centred slot', () => {
    const withDefaults = pocketToolPosition(60, 2, 30);
    const explicit = pocketToolPosition(60, 2, 30, 0, 1);
    withDefaults.forEach((component, index) => {
      expect(explicit[index]).toBeCloseTo(component, 9);
    });
  });

  it('keeps the single default slot on the category equator (y component flat)', () => {
    // slotCount 1 -> y = 1 - 0.5*2 = 0, so vertical offset equals category y.
    const categoryAngle = 75;
    const center = categoryPosition(categoryAngle);
    const vec = pocketToolPosition(120, 3, categoryAngle);
    expect(vec[1]).toBeCloseTo(center[1], 6);
  });
});

describe('layout vectors stay bounded', () => {
  it('keeps category and tool vectors at a sane finite magnitude', () => {
    for (let angle = 0; angle < 360; angle += 11) {
      expect(length(categoryPosition(angle))).toBeLessThan(10);
      expect(length(toolPosition(angle, 3, angle))).toBeLessThan(15);
    }
  });
});
