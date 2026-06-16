import type { InferredEdge } from '../../lib/relationship-intelligence.types';

export interface InferredLine {
  edge: InferredEdge;
  start: [number, number, number];
  end: [number, number, number];
  opacity: number;
  lineWidth: number;
}

export function buildInferredLineData(
  edges: InferredEdge[],
  positionById: Map<string, [number, number, number]>,
): InferredLine[] {
  return edges.flatMap((edge) => {
    const start = positionById.get(edge.fromId);
    const end = positionById.get(edge.toId);
    if (!start || !end) return [];
    const opacity = 0.12 + edge.confidence * 0.5; // 0.12–0.62
    const lineWidth = 0.4 + edge.confidence * 1.1;
    return [{ edge, start, end, opacity, lineWidth }];
  });
}
