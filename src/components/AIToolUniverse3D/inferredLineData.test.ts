import { describe, expect, it } from 'vitest';
import { buildInferredLineData } from './inferredLineData';

const pos = new Map<string, [number, number, number]>([
  ['a', [0, 0, 0]], ['b', [1, 0, 0]],
]);

describe('buildInferredLineData', () => {
  it('higher confidence → higher opacity', () => {
    const lo = buildInferredLineData([{ fromId: 'a', toId: 'b', kind: 'alternative-to', reason: 'x', confidence: 0.45 }], pos);
    const hi = buildInferredLineData([{ fromId: 'a', toId: 'b', kind: 'extension-of', reason: 'x', confidence: 0.9 }], pos);
    expect(hi[0].opacity).toBeGreaterThan(lo[0].opacity);
  });

  it('drops edges whose endpoints have no position', () => {
    const out = buildInferredLineData([{ fromId: 'a', toId: 'ghost', kind: 'integrates-with', reason: 'x', confidence: 0.8 }], pos);
    expect(out).toEqual([]);
  });
});
