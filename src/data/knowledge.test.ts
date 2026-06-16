import { describe, expect, it } from 'vitest';
import { ENRICHED_DATA } from '../playground/knowledge.data';
import { tools } from './ai-tool-universe';
import knowledgeJson from './knowledge.json';

const PRICING_MODELS = new Set([
  'free', 'open-source', 'freemium', 'subscription',
  'usage-based', 'enterprise', 'mixed', 'unknown',
]);

describe('knowledge.json', () => {
  it('is byte-equal to the canonical emit of ENRICHED_DATA', () => {
    // Same sort + serialization the generator uses. Drift fails here.
    const sorted = Object.fromEntries(
      Object.keys(ENRICHED_DATA).sort().map((k) => [k, ENRICHED_DATA[k]]),
    );
    const expected = JSON.parse(JSON.stringify(sorted));
    expect(knowledgeJson).toEqual(expected);
  });

  it('has exactly one record per seed tool id', () => {
    const seedIds = new Set(tools.map((t) => t.id));
    const knowledgeIds = new Set(Object.keys(knowledgeJson));
    expect(knowledgeIds.size).toBe(seedIds.size);
    for (const id of seedIds) {
      expect(knowledgeIds.has(id), `missing knowledge for ${id}`).toBe(true);
    }
    for (const id of knowledgeIds) {
      expect(seedIds.has(id), `orphan knowledge for ${id}`).toBe(true);
    }
  });

  it('every record is structurally complete', () => {
    for (const [id, k] of Object.entries(knowledgeJson)) {
      expect(Array.isArray(k.killerFeatures), `${id}.killerFeatures`).toBe(true);
      expect(typeof k.whatFor === 'string' && k.whatFor.length > 0, `${id}.whatFor`).toBe(true);
      expect(Array.isArray(k.advantages), `${id}.advantages`).toBe(true);
      expect(Array.isArray(k.weaknesses), `${id}.weaknesses`).toBe(true);
      expect(typeof k.whoUses === 'string', `${id}.whoUses`).toBe(true);
      expect(PRICING_MODELS.has(k.pricing.model), `${id}.pricing.model`).toBe(true);
      expect(typeof k.pricing.summary === 'string' && k.pricing.summary.length > 0, `${id}.pricing.summary`).toBe(true);
    }
  });
});
