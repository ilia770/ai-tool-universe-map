import type { AITool, WorkflowStageId } from '../data/ai-tool-universe';
import type { InferredEdge, RelationKind } from './relationship-intelligence.types';
import type { ToolKnowledge } from '../playground/knowledge';

export const CONFIDENCE_THRESHOLD = 0.4;
export const MAX_EDGES_PER_KIND = 4;

export type KnowledgeLookup = (id: string) => ToolKnowledge | null;

const EXT_RE = /\b(chrome|browser|firefox|edge)?\s*(extension|add-?on|plugin)\b/i;

const registrable = (domain?: string): string | undefined =>
  domain?.toLowerCase().split('.').slice(-2).join('.') || undefined;

const haystack = (t: AITool, k?: ToolKnowledge | null): string =>
  [t.name, t.summary, k?.whatFor ?? '', t.logoDomain ?? '', t.url ?? '']
    .join(' ').toLowerCase();

const nameTokens = (t: AITool): string[] =>
  t.name.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length >= 3);

const STAGE_ORDER: WorkflowStageId[] = ['research', 'planning', 'execution', 'approval', 'review'];

/** Score a single directed candidate→target relationship; null = no edge. */
function scorePair(
  cand: AITool, target: AITool, text: string,
): { kind: RelationKind; reason: string; confidence: number } | null {
  // 1. extension-of: candidate is explicitly an extension AND names target.
  const namesTarget = nameTokens(target).some((tok) => text.includes(tok));
  if (EXT_RE.test(text) && namesTarget) {
    return { kind: 'extension-of', confidence: 0.82,
      reason: `It is an extension/add-on built for ${target.name}.` };
  }
  // 2. same-vendor: shared registrable domain (and not identical tool).
  const cv = registrable(cand.logoDomain), tv = registrable(target.logoDomain);
  if (cv && tv && cv === tv) {
    return { kind: 'same-vendor', confidence: 0.78,
      reason: `Both are part of the ${target.name.split(' ')[0]} family (same vendor).` };
  }
  // 3. integrates-with: candidate text explicitly names the target tool.
  if (namesTarget && nameTokens(target).join('').length >= 4) {
    return { kind: 'integrates-with', confidence: 0.6,
      reason: `It explicitly works with ${target.name}.` };
  }
  // 4. data-flows-to: adjacent workflow stage, shared category lineage.
  if (cand.category === target.category
    && STAGE_ORDER.indexOf(target.stage) === STAGE_ORDER.indexOf(cand.stage) + 1) {
    return { kind: 'data-flows-to', confidence: 0.5,
      reason: `Output from this stage typically flows into ${target.name}.` };
  }
  // 5. alternative-to: same category, same stage, no stronger signal.
  if (cand.category === target.category && cand.stage === target.stage) {
    return { kind: 'alternative-to', confidence: 0.45,
      reason: `A category alternative to ${target.name}.` };
  }
  return null;
}

export function inferRelationships(
  candidate: AITool,
  universe: AITool[],
  knowledgeFor?: KnowledgeLookup,
): InferredEdge[] {
  const k = knowledgeFor?.(candidate.id) ?? null;
  const text = haystack(candidate, k);

  const scored = universe
    .filter((t) => t.id !== candidate.id)
    .map((target) => {
      const s = scorePair(candidate, target, text);
      return s ? { ...s, fromId: candidate.id, toId: target.id } : null;
    })
    .filter((e): e is InferredEdge => e !== null && e.confidence >= CONFIDENCE_THRESHOLD);

  // Cap per kind — this is what stops a hub from over-connecting.
  const byKind = new Map<RelationKind, InferredEdge[]>();
  for (const e of scored) {
    const list = byKind.get(e.kind) ?? [];
    list.push(e);
    byKind.set(e.kind, list);
  }
  const capped: InferredEdge[] = [];
  for (const list of byKind.values()) {
    list.sort((a, b) => b.confidence - a.confidence || a.toId.localeCompare(b.toId));
    capped.push(...list.slice(0, MAX_EDGES_PER_KIND));
  }
  // Deterministic global order: confidence desc, then kind, then toId.
  return capped.sort((a, b) =>
    b.confidence - a.confidence || a.kind.localeCompare(b.kind) || a.toId.localeCompare(b.toId));
}
