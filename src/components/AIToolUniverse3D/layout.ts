const CATEGORY_RADIUS_X = 4.55;
const CATEGORY_RADIUS_Z = 3.45;
const ORBIT_RADII = [0, 0.96, 1.48, 1.98] as const;
const POCKET_ORBIT_RADII = [0, 2.9, 4.6, 6.4] as const;

export const POCKET_WORLD_RADIUS = 7.0;
const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));

export function categoryPosition(angle: number): [number, number, number] {
  const rad = (angle * Math.PI) / 180;
  return [
    Math.cos(rad) * CATEGORY_RADIUS_X,
    Math.sin(rad * 1.7) * 1.35,
    Math.sin(rad) * CATEGORY_RADIUS_Z,
  ];
}

export function toolPosition(
  angle: number,
  orbit: 0 | 1 | 2 | 3,
  categoryAngle: number,
): [number, number, number] {
  if (orbit === 0) return [0, 0, 0];

  const [catX, catY, catZ] = categoryPosition(categoryAngle);
  const toolRad = (angle * Math.PI) / 180;
  const radius = ORBIT_RADII[orbit];
  const verticalLift = Math.sin(toolRad * 1.35 + categoryAngle * 0.03) * (0.48 + orbit * 0.12);

  return [
    catX + Math.cos(toolRad) * radius,
    catY + verticalLift,
    catZ + Math.sin(toolRad) * radius * 0.78,
  ];
}

export function pocketToolPosition(
  angle: number,
  orbit: 0 | 1 | 2 | 3,
  categoryAngle: number,
  slotIndex = 0,
  slotCount = 1,
): [number, number, number] {
  if (orbit === 0) return [0, 0, 0];

  const [catX, catY, catZ] = categoryPosition(categoryAngle);
  const safeSlotCount = Math.max(slotCount, 1);

  // Fibonacci-sphere distribution: even surface coverage, no stacking lanes.
  // y in [-1, 1], xz radius derived from y, phi advances by golden angle so
  // neighbouring slots never collide.
  const y = 1 - (slotIndex + 0.5) * (2 / safeSlotCount);
  const yRadius = Math.sqrt(Math.max(0, 1 - y * y));
  const localRad = ((angle - categoryAngle) * Math.PI) / 180;
  // Blend golden-angle spiral with the tool's own angle so stage/relation
  // groupings remain visually clustered instead of fully randomised.
  const phi = slotIndex * GOLDEN_ANGLE + localRad * 0.22;

  const radius = POCKET_ORBIT_RADII[orbit];
  return [
    catX + Math.cos(phi) * yRadius * radius,
    catY + y * radius * 0.62,
    catZ + Math.sin(phi) * yRadius * radius,
  ];
}
