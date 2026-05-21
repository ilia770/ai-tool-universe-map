const CATEGORY_RADIUS_X = 4.55;
const CATEGORY_RADIUS_Z = 3.45;
const ORBIT_RADII = [0, 0.96, 1.48, 1.98] as const;

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
