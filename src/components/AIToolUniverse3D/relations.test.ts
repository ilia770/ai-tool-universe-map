import { describe, expect, it } from 'vitest';
import type { AITool } from '../../data/ai-tool-universe';
import { buildLensRelevantIds, buildRelationDepthMap } from './relations';

function tool(id: string, overrides: Partial<AITool> = {}): AITool {
  return {
    id,
    name: id,
    category: 'coding',
    summary: '',
    stage: 'execution',
    orbit: 1,
    angle: 0,
    relationIds: [],
    ...overrides,
  };
}

// focus -> a -> c ; b -> focus (back-reference) ; inbound-hop -> b ; d is unrelated
const fixture: AITool[] = [
  tool('focus', { relationIds: ['a'], stage: 'planning', category: 'coding' }),
  tool('a', { relationIds: ['c'], stage: 'execution', category: 'design' }),
  tool('b', { relationIds: ['focus'], stage: 'planning', category: 'research' }),
  tool('inbound-hop', { relationIds: ['b'], stage: 'review', category: 'knowledge' }),
  tool('c', { relationIds: [], stage: 'review', category: 'media' }),
  tool('d', { relationIds: [], stage: 'planning', category: 'coding' }),
];

describe('buildRelationDepthMap', () => {
  it('marks the focus tool at depth 0', () => {
    expect(buildRelationDepthMap('focus', fixture).get('focus')).toBe(0);
  });

  it('marks outgoing and incoming direct relations at depth 1', () => {
    const map = buildRelationDepthMap('focus', fixture);
    expect(map.get('a')).toBe(1); // focus -> a
    expect(map.get('b')).toBe(1); // b -> focus
  });

  it('marks a second hop at depth 2', () => {
    expect(buildRelationDepthMap('focus', fixture).get('c')).toBe(2); // focus -> a -> c
    expect(buildRelationDepthMap('focus', fixture).get('inbound-hop')).toBe(2); // inbound-hop -> b -> focus
  });

  it('omits tools with no path to the focus', () => {
    expect(buildRelationDepthMap('focus', fixture).has('d')).toBe(false);
  });

  it('returns an empty map for an unknown or null focus', () => {
    expect(buildRelationDepthMap('nope', fixture).size).toBe(0);
    expect(buildRelationDepthMap(null, fixture).size).toBe(0);
  });
});

describe('buildLensRelevantIds', () => {
  const depth = buildRelationDepthMap('focus', fixture);

  it('direct lens keeps the focus and depth-1 nodes only', () => {
    const ids = buildLensRelevantIds('focus', fixture, 'direct', depth);
    expect([...ids].sort()).toEqual(['a', 'b', 'focus']);
  });

  it('adjacent lens additionally keeps depth-2 nodes', () => {
    const ids = buildLensRelevantIds('focus', fixture, 'adjacent', depth);
    expect([...ids].sort()).toEqual(['a', 'b', 'c', 'focus', 'inbound-hop']);
  });

  it('stage lens keeps every tool sharing the focus stage', () => {
    const ids = buildLensRelevantIds('focus', fixture, 'stage', depth);
    // focus, b, d are all stage "planning"
    expect([...ids].sort()).toEqual(['b', 'd', 'focus']);
  });

  it('category lens keeps every tool sharing the focus category', () => {
    const ids = buildLensRelevantIds('focus', fixture, 'category', depth);
    // focus, d are both category "coding"
    expect([...ids].sort()).toEqual(['d', 'focus']);
  });

  it('returns an empty set for an unknown focus', () => {
    expect(buildLensRelevantIds('nope', fixture, 'direct', depth).size).toBe(0);
  });
});
