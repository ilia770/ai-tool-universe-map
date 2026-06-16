import type { InferredEdge, RelationKind } from '../lib/relationship-intelligence.types';

const LABEL: Record<RelationKind, string> = {
  'extension-of': 'Extension of',
  'integrates-with': 'Integrates with',
  'same-vendor': 'Same vendor',
  'data-flows-to': 'Feeds into',
  'alternative-to': 'Alternative to',
};

export const relationLabel = (kind: RelationKind): string => LABEL[kind];

export const connectedBecause = (edge: InferredEdge): string =>
  `${LABEL[edge.kind]} · ${edge.reason} (${Math.round(edge.confidence * 100)}%)`;
