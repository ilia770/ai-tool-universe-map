const CATEGORY_RADIUS_X = 4.55;
const CATEGORY_RADIUS_Z = 3.45;
const ORBIT_RADII = [0, 0.96, 1.48, 1.98] as const;
const POCKET_ORBIT_RADII = [0, 2.05, 3.36, 4.82] as const;

export const POCKET_WORLD_RADIUS = 5.32;

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
  const localRad = ((angle - categoryAngle) * Math.PI) / 180;
  const slotRad = ((slotIndex + 0.5) / safeSlotCount) * Math.PI * 2 - Math.PI / 2;
  const fanRad = slotRad + localRad * 0.24 + orbit * 0.18;
  const radius = POCKET_ORBIT_RADII[orbit] + (slotIndex % 2) * 0.2;
  const verticalLane = (slotIndex % 3) - 1;
  const verticalLift = Math.sin(fanRad * 1.12) * 0.42 + verticalLane * 0.48 + (orbit - 2) * 0.08;

  return [
    catX + Math.cos(fanRad) * radius * 1.08,
    catY + verticalLift,
    catZ + Math.sin(fanRad) * radius * 0.84,
  ];
}
