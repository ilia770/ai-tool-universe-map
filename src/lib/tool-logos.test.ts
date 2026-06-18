import { describe, expect, it } from 'vitest';
import { tools } from '../data/ai-tool-universe';
import { getDomainFromUrl, getToolInitials, getToolLogoDisplayDomain, getToolLogoDomain } from './tool-logos';

describe('tool logo helpers', () => {
  it('extracts domains from valid URLs', () => {
    expect(getDomainFromUrl('https://www.cursor.com/')).toBe('cursor.com');
    expect(getDomainFromUrl('not a url')).toBeNull();
  });

  it('uses explicit domain overrides before URLs', () => {
    expect(getToolLogoDomain({ id: 'codex', url: undefined, logoDomain: undefined })).toBe('openai.com');
    expect(getToolLogoDomain({ id: 'custom-tool', url: 'https://example.com/path', logoDomain: undefined })).toBe('example.com');
    expect(getToolLogoDomain({ id: 'custom-tool', url: 'https://example.com', logoDomain: 'custom.com' })).toBe('custom.com');
  });

  it('covers existing branded tools whose seed URLs are missing or nested', () => {
    expect(getToolLogoDomain(tools.find((tool) => tool.id === 'figma')!)).toBe('figma.com');
    expect(getToolLogoDomain(tools.find((tool) => tool.id === 'paper-design')!)).toBe('paper.design');
    expect(getToolLogoDomain(tools.find((tool) => tool.id === 'hyperframes')!)).toBe('heygen.com');
    expect(getToolLogoDomain(tools.find((tool) => tool.id === 'wisprflow')!)).toBe('wisprflow.ai');
    expect(getToolLogoDomain(tools.find((tool) => tool.id === 'agent-skills')!)).toBe('github.com');
    expect(getToolLogoDomain(tools.find((tool) => tool.id === 'claude-code')!)).toBe('anthropic.com');
  });

  it('creates short display domains for fallback logo tiles', () => {
    expect(getToolLogoDisplayDomain(tools.find((tool) => tool.id === 'agent-skills')!)).toBe('GitHub');
    expect(getToolLogoDisplayDomain(tools.find((tool) => tool.id === 'hyperframes')!)).toBe('HeyGen');
    expect(getToolLogoDisplayDomain({ id: 'custom-tool', url: 'https://app.example.ai/path', logoDomain: undefined })).toBe('example.ai');
  });

  it('creates compact fallback initials', () => {
    expect(getToolInitials('Claude Code')).toBe('CC');
    expect(getToolInitials('Figma / Make')).toBe('FM');
    expect(getToolInitials('API Mega List')).toBe('API');
    expect(getToolInitials('VS Code')).toBe('VS');
  });
});
