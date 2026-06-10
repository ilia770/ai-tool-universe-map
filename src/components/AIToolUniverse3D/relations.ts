import type { AITool } from '../../data/ai-tool-universe';

export type RelationLens = 'direct' | 'adjacent' | 'stage' | 'category';

/**
 * Breadth-first relation depth from a focus tool:
 *   0 = the focus tool itself
 *   1 = directly related (focus -> X or X -> focus)
 *   2 = one hop past a direct relation
 * Tools further than depth 2, or with no path, are absent from the map.
 * An unknown / null focus id yields an empty map.
 */
export function buildRelationDepthMap(focusId: string | null, tools: AITool[]): Map<string, number> {
  const map = new Map<string, number>();
  const activeTool = tools.find((tool) => tool.id === focusId);
  if (!activeTool) return map;

  const adjacency = new Map<string, Set<string>>();
  tools.forEach((tool) => {
    if (!adjacency.has(tool.id)) adjacency.set(tool.id, new Set());
    tool.relationIds.forEach((relationId) => {
      adjacency.get(tool.id)?.add(relationId);
      if (!adjacency.has(relationId)) adjacency.set(relationId, new Set());
      adjacency.get(relationId)?.add(tool.id);
    });
  });

  const queue: Array<{ id: string; depth: number }> = [{ id: activeTool.id, depth: 0 }];
  map.set(activeTool.id, 0);

  for (let index = 0; index < queue.length; index += 1) {
    const current = queue[index];
    if (current.depth >= 2) continue;

    adjacency.get(current.id)?.forEach((nextId) => {
      if (map.has(nextId)) return;
      const depth = current.depth + 1;
      map.set(nextId, depth);
      queue.push({ id: nextId, depth });
    });
  }

  return map;
}

/**
 * The set of tool ids a relation lens keeps "relevant" for the focus tool.
 * - stage / category: every tool sharing the focus tool's stage / category.
 * - direct: focus + depth-1 nodes.
 * - adjacent: focus + depth-1 and depth-2 nodes.
 * Always includes the focus tool itself. Empty for an unknown focus id.
 */
export function buildLensRelevantIds(
  focusId: string | null,
  tools: AITool[],
  lens: RelationLens,
  depthMap: Map<string, number>,
): Set<string> {
  const ids = new Set<string>();
  const activeTool = tools.find((tool) => tool.id === focusId);
  if (!activeTool) return ids;

  ids.add(activeTool.id);

  if (lens === 'stage') {
    tools.forEach((tool) => {
      if (tool.stage === activeTool.stage) ids.add(tool.id);
    });
    return ids;
  }

  if (lens === 'category') {
    tools.forEach((tool) => {
      if (tool.category === activeTool.category) ids.add(tool.id);
    });
    return ids;
  }

  const maxDepth = lens === 'adjacent' ? 2 : 1;
  depthMap.forEach((depth, id) => {
    if (depth <= maxDepth) ids.add(id);
  });

  return ids;
}
