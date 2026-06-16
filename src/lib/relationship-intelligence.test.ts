import { describe, expect, it } from 'vitest';
import type { AITool } from '../data/ai-tool-universe';
import { inferRelationships, CONFIDENCE_THRESHOLD } from './relationship-intelligence';

const tool = (id: string, o: Partial<AITool> = {}): AITool => ({
  id, name: id, category: 'coding', summary: '', stage: 'execution',
  orbit: 2, angle: 0, relationIds: [], ...o,
});

// A small universe with a clear hub (google) + unrelated tools.
const universe: AITool[] = [
  tool('google', { name: 'Google', category: 'research', stage: 'research', logoDomain: 'google.com' }),
  tool('figma', { name: 'Figma', category: 'design', stage: 'planning', logoDomain: 'figma.com' }),
  tool('elevenlabs', { name: 'ElevenLabs', category: 'media', stage: 'execution', logoDomain: 'elevenlabs.io' }),
  tool('cursor', { name: 'Cursor', category: 'coding', stage: 'execution', logoDomain: 'cursor.com' }),
];

describe('inferRelationships — pinpoint, explained edges', () => {
  it('(a) a Chrome extension FOR Google links to google as extension-of, not to unrelated tools', () => {
    const candidate = tool('google-translate-ext', {
      name: 'Google Translate (Chrome extension)',
      summary: 'A Chrome extension for Google Translate.',
      category: 'research',
    });
    const edges = inferRelationships(candidate, universe);
    const targets = edges.map((e) => e.toId);
    expect(targets).toContain('google');
    expect(edges.find((e) => e.toId === 'google')!.kind).toBe('extension-of');
    expect(targets).not.toContain('figma');
    expect(targets).not.toContain('elevenlabs');
  });

  it('(b) a hub tool does not over-connect (capped, no blanket fan-out)', () => {
    const hub = tool('google', { name: 'Google', category: 'research', stage: 'research' });
    const big = [hub, ...Array.from({ length: 30 }, (_, i) =>
      tool(`coder-${i}`, { name: `Coder ${i}`, category: 'coding' }))];
    const edges = inferRelationships(hub, big);
    // No edge to a tool that neither names nor extends the hub.
    expect(edges.every((e) => e.toId !== 'coder-0')).toBe(true);
    // Hard cap: a hub never emits more than MAX_EDGES_PER_KIND * kinds.
    expect(edges.length).toBeLessThanOrEqual(12);
  });

  it('(c) same-category peers with no stronger signal link as alternative-to', () => {
    const candidate = tool('windsurf', { name: 'Windsurf', category: 'coding', stage: 'execution' });
    const edges = inferRelationships(candidate, universe);
    const alt = edges.find((e) => e.toId === 'cursor');
    expect(alt).toBeDefined();
    expect(alt!.kind).toBe('alternative-to');
    expect(alt!.reason).toMatch(/cursor/i);
  });

  it('thresholds low-confidence edges out and is deterministic', () => {
    const candidate = tool('windsurf', { category: 'coding' });
    const edges = inferRelationships(candidate, universe);
    expect(edges.every((e) => e.confidence >= CONFIDENCE_THRESHOLD)).toBe(true);
    expect(edges).toEqual(inferRelationships(candidate, universe)); // stable order
  });

  it('never returns a self edge', () => {
    const edges = inferRelationships(universe[0], universe);
    expect(edges.every((e) => e.fromId !== e.toId)).toBe(true);
  });
});
