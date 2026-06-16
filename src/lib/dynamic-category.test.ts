import { describe, expect, it } from 'vitest';
import { makeDynamicCategory } from './dynamic-category';
import { categories } from '../data/ai-tool-universe';

describe('makeDynamicCategory', () => {
  it('creates a stable id, a non-empty name, and a unique angle', () => {
    const existing = categories;
    const cat = makeDynamicCategory('Voice Cloning', existing);
    expect(cat.id).toBe('dyn-voice-cloning');
    expect(cat.shortName.length).toBeGreaterThan(0);
    expect(existing.some((c) => c.angle === cat.angle)).toBe(false);
  });

  it('is deterministic for the same name', () => {
    expect(makeDynamicCategory('Voice Cloning', categories))
      .toEqual(makeDynamicCategory('Voice Cloning', categories));
  });
});
