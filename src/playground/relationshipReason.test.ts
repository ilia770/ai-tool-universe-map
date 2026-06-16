import { describe, expect, it } from 'vitest';
import { connectedBecause } from './relationshipReason';

describe('connectedBecause', () => {
  it('renders a kind label + reason + percent confidence', () => {
    expect(connectedBecause({
      fromId: 'x', toId: 'google', kind: 'extension-of',
      reason: 'It is an extension/add-on built for Google.', confidence: 0.82,
    })).toBe('Extension of · It is an extension/add-on built for Google. (82%)');
  });
});
