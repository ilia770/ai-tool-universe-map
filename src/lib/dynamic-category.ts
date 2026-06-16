import type { ToolCategory } from '../data/ai-tool-universe';
import { makeSlug } from './classify-ai-tool';

const GOLDEN_ANGLE = 137.508;

function stableHash(value: string): number {
  let h = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/** First word of the name, for the compact `shortName` chip label. */
function firstWord(name: string): string {
  const word = name.trim().split(/\s+/)[0];
  return word || name.trim();
}

/**
 * Next orbital slot that does not collide with any existing category angle.
 * Steps by the golden angle from the current max so dynamic branches fan out
 * evenly around the ring instead of stacking.
 */
function nextFreeAngle(existing: readonly ToolCategory[]): number {
  const used = new Set(existing.map((c) => Math.round(c.angle)));
  const maxAngle = existing.reduce((m, c) => Math.max(m, c.angle), 0);
  let angle = (maxAngle + GOLDEN_ANGLE) % 360;
  for (let i = 0; i < 360 && used.has(Math.round(angle)); i += 1) {
    angle = (angle + GOLDEN_ANGLE) % 360;
  }
  return Math.round(angle);
}

/**
 * Mints a runtime-only category for a tool that fits no existing branch.
 * Deterministic: same name + same existing set always yields the same id,
 * colour, and angle.
 */
export function makeDynamicCategory(
  name: string,
  existing: readonly ToolCategory[],
): ToolCategory {
  const id = `dyn-${makeSlug(name)}`;
  const hue = stableHash(id) % 360;
  const color = `hsl(${hue}, 82%, 68%)`;
  const glow = `hsla(${hue}, 82%, 68%, 0.28)`;
  return {
    id: id as ToolCategory['id'],
    name,
    shortName: firstWord(name),
    description: `User-created branch for ${name}.`,
    color,
    glow,
    angle: nextFreeAngle(existing),
  };
}
