import { describe, expect, it } from 'vitest';
import { tools } from '../data/ai-tool-universe';
import { runQuery } from './query';

describe('runQuery', () => {
  it('returns nothing for an empty query', () => {
    expect(runQuery('', tools).matches).toHaveLength(0);
    expect(runQuery('the to a', tools).matches).toHaveLength(0);
  });

  it('ranks a name match to the top', () => {
    const first = tools[0];
    const res = runQuery(first.name, tools);
    expect(res.matches[0]?.id).toBe(first.id);
  });

  it('biases results toward the intended category', () => {
    // A design/UI ask should surface design-category tools.
    const res = runQuery('design and ui tools', tools);
    expect(res.matches.length).toBeGreaterThan(0);
    expect(res.matches.some((m) => m.category === 'design')).toBe(true);
  });

  it('always returns at most 5 matches', () => {
    const res = runQuery('agent code design research', tools);
    expect(res.matches.length).toBeLessThanOrEqual(5);
  });

  it('produces a non-empty answer when there are matches', () => {
    const res = runQuery('coding agent', tools);
    if (res.matches.length > 0) expect(res.answer.length).toBeGreaterThan(0);
  });

  it('answers gracefully when nothing matches', () => {
    const res = runQuery('zzzqqq nonexistent xyzzy', tools);
    expect(res.matches).toHaveLength(0);
    expect(res.answer).toContain('+');
  });
});
