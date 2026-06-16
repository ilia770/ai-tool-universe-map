import { describe, expect, it } from 'vitest';
import { RELATION_KINDS, isInferredEdge } from './relationship-intelligence.types';

describe('relationship-intelligence types', () => {
  it('exposes the five typed edge kinds', () => {
    expect([...RELATION_KINDS].sort()).toEqual(
      ['alternative-to', 'data-flows-to', 'extension-of', 'integrates-with', 'same-vendor'],
    );
  });

  it('accepts a well-formed edge and rejects malformed ones', () => {
    expect(isInferredEdge({
      fromId: 'a', toId: 'b', kind: 'extension-of',
      reason: 'A is an extension for B.', confidence: 0.7,
    })).toBe(true);
    expect(isInferredEdge({ fromId: 'a', toId: 'a', kind: 'extension-of', reason: 'x', confidence: 0.5 })).toBe(false); // self
    expect(isInferredEdge({ fromId: 'a', toId: 'b', kind: 'nope', reason: 'x', confidence: 0.5 })).toBe(false); // bad kind
    expect(isInferredEdge({ fromId: 'a', toId: 'b', kind: 'extension-of', reason: 'x', confidence: 2 })).toBe(false); // out of range
  });
});
