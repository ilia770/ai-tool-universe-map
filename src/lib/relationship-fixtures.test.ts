import { describe, expect, it } from 'vitest';
import type { AITool } from '../data/ai-tool-universe';
import { inferRelationships } from './relationship-intelligence';
import fixtures from './relationship-fixtures.json';

describe('relationship fixtures (cross-lane contract)', () => {
  const universe = fixtures.universe as AITool[];
  for (const c of fixtures.cases) {
    it(`case ${c.candidate.id}`, () => {
      const edges = inferRelationships(c.candidate as AITool, universe);
      for (const e of c.expect) {
        expect(edges.find((x) => x.toId === e.toId)?.kind).toBe(e.kind);
      }
      for (const id of c.forbid ?? []) {
        expect(edges.some((x) => x.toId === id)).toBe(false);
      }
    });
  }
});
