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

  it('classifies pasted product URLs with domain-specific signals', () => {
    expect(classifyTool('https://www.perplexity.ai/')).toBe('research');
    expect(classifyTool('https://runwayml.com/')).toBe('media');
    expect(classifyTool('https://www.notion.so/product/ai')).toBe('knowledge');
    expect(classifyTool('https://supabase.com/dashboard/projects')).toBe('infrastructure');
  });

  it('uses URL path words when a domain is generic', () => {
    const result = classifyToolDetailed('https://github.com/addyosmani/agent-skills');

    expect(result.category).toBe('knowledge');
    expect(result.matchedKeywords).toContain('skills');
  });
});

describe('tool input helpers', () => {
  it('creates stable slugs and display names', () => {
    expect(makeSlug('https://www.supadata.ai/')).toBe('supadata-ai');
    expect(getDisplayName('https://wisprflow.ai/')).toBe('Wispr Flow');
  });

  it('falls back to a stable ASCII slug when the input has no latin token', () => {
    expect(makeSlug('聊天工具')).toMatch(/^tool-[a-z0-9]+$/);
    expect(makeSlug('🤖')).toMatch(/^tool-[a-z0-9]+$/);
    expect(makeSlug('聊天工具')).toBe(makeSlug('聊天工具'));
  });
});
