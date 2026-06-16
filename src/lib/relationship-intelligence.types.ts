export const RELATION_KINDS = [
  'extension-of', 'integrates-with', 'same-vendor', 'data-flows-to', 'alternative-to',
] as const;
export type RelationKind = (typeof RELATION_KINDS)[number];
const KIND_SET: ReadonlySet<string> = new Set(RELATION_KINDS);

export interface InferredEdge {
  fromId: string;
  toId: string;
  kind: RelationKind;
  reason: string;
  confidence: number; // [0,1]
}

export const isInferredEdge = (value: unknown): value is InferredEdge => {
  if (typeof value !== 'object' || value === null) return false;
  const e = value as Record<string, unknown>;
  return typeof e.fromId === 'string' && e.fromId.trim() !== ''
    && typeof e.toId === 'string' && e.toId.trim() !== ''
    && e.fromId !== e.toId
    && typeof e.kind === 'string' && KIND_SET.has(e.kind)
    && typeof e.reason === 'string' && e.reason.trim() !== ''
    && typeof e.confidence === 'number'
    && e.confidence >= 0 && e.confidence <= 1;
};
