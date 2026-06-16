import { describe, expect, it } from 'vitest';
import type { AITool } from '../data/ai-tool-universe';
import { tools as seedTools } from '../data/ai-tool-universe';
import { inferRelationships } from '../lib/relationship-intelligence';
import { knowledgeFor } from './knowledge';
import { classifyToolDetailed, makeSlug, getDisplayName } from '../lib/classify-ai-tool';

/* ------------------------------------------------------------------ *
 * Store inferred-relationship wiring (P9).
 *
 * `ToolStoreProvider.addTool` (store.tsx) builds an AITool from the
 * classifier, then calls `inferRelationships(tool, universe, knowledgeFor)`
 * and stores the result on `AddedTool.inferredEdges`, exposed via
 * `edgesFor(id)`. The provider is a React hook tree and the repo's vitest
 * runs in the `node` environment (no jsdom dependency available), so this
 * test exercises the exact wiring `addTool` performs — same tool shape,
 * same universe, same knowledge lookup — without a DOM render. It asserts
 * the store attaches a pinpoint `extension-of` edge to `google` and no edge
 * to an unrelated tool (`elevenlabs`).
 * ------------------------------------------------------------------ */

// Mirror store.tsx addTool's tool construction for a plain name input.
function buildTool(text: string): AITool {
  const slug = makeSlug(text);
  const result = classifyToolDetailed(text);
  return {
    id: slug,
    name: getDisplayName(text),
    category: result.category,
    summary: result.reason,
    stage: result.stage,
    orbit: 2,
    angle: 0,
    relationIds: result.relationIds.filter((id) => id !== slug),
  };
}

describe('store inferred relationships', () => {
  it('attaches pinpoint inferred edges to an added tool', () => {
    // The seed has no `google`/`elevenlabs`, so model the store sequence:
    // add google + elevenlabs first, then the Chrome extension.
    const google = buildTool('Google');
    const elevenlabs = buildTool('ElevenLabs');
    const universe = [...seedTools, google, elevenlabs];

    const extension = buildTool('Google Translate Chrome extension');
    const edges = inferRelationships(extension, universe, knowledgeFor);

    expect(edges.some((e) => e.toId === google.id && e.kind === 'extension-of')).toBe(true);
    expect(edges.some((e) => e.toId === elevenlabs.id)).toBe(false);
  });
});
