import { describe, expect, it } from 'vitest';
import { classifyIntake, UNSURE_PROMPT } from './intake';

describe('classifyIntake — confidence gating', () => {
  it('returns "classified" for a confident, known tool', () => {
    const out = classifyIntake('https://cursor.com');
    expect(out.kind).toBe('classified');
    if (out.kind === 'classified') expect(out.result.category).toBe('coding');
  });

  it('returns "unsure" (NOT a guess) for an unknown low-confidence token', () => {
    const out = classifyIntake('zxqwobble');
    expect(out.kind).toBe('unsure');
    if (out.kind === 'unsure') {
      expect(out.prompt).toBe(UNSURE_PROMPT);
      expect(out.prompt).toContain('скинь ссылку на сайт');
    }
  });

  it('re-classifies from a pasted URL after an unsure result', () => {
    const out = classifyIntake('zxqwobble', { url: 'https://posthog.com' });
    expect(out.kind).toBe('classified');
    if (out.kind === 'classified') expect(out.result.category).toBe('analytics');
  });

  it('mints a newCategory when a URL fits no existing branch', () => {
    const out = classifyIntake('QuantumKnitting', { url: 'https://quantumknitting.io' });
    expect(out.kind).toBe('newCategory');
    if (out.kind === 'newCategory') expect(out.suggestedName.length).toBeGreaterThan(0);
  });
});
