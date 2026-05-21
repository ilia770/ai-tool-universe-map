import { describe, expect, it } from 'vitest';
import { classifyTool, classifyToolDetailed, getDisplayName, makeSlug } from './classify-ai-tool';

describe('classifyTool', () => {
  it('classifies common builder and coding inputs', () => {
    expect(classifyTool('https://cursor.com')).toBe('coding');
    expect(classifyTool('Claude Code')).toBe('coding');
  });

  it('classifies design and media inputs', () => {
    expect(classifyTool('Make in Figma')).toBe('design');
    expect(classifyTool('Remotion video renderer')).toBe('media');
  });

  it('falls back to core for unknown operating concepts', () => {
    expect(classifyTool('Founder approval loop')).toBe('core');
  });

  it('returns useful classification details for the intake preview', () => {
    const result = classifyToolDetailed('https://buffer.com/');

    expect(result).toMatchObject({
      category: 'distribution',
      stage: 'approval',
    });
    expect(result.confidence).toBeGreaterThan(0.5);
    expect(result.matchedKeywords).toContain('buffer');
    expect(result.relationIds).toContain('approval-gate');
  });
});

describe('tool input helpers', () => {
  it('creates stable slugs and display names', () => {
    expect(makeSlug('https://www.supadata.ai/')).toBe('supadata-ai');
    expect(getDisplayName('https://wisprflow.ai/')).toBe('Wispr Flow');
  });
});
