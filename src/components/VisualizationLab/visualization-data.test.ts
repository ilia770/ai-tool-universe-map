import { describe, expect, it } from 'vitest';
import { categories, tools, workflowLinks } from '../../data/ai-tool-universe';
import { buildVisualizationData, getConnectedNodeIds } from './visualization-data';

describe('buildVisualizationData', () => {
  const data = buildVisualizationData({ categories, tools, workflowLinks });

  it('creates one node per tool in deterministic order', () => {
    expect(data.nodes.map((node) => node.id)).toEqual(tools.map((tool) => tool.id));
  });

  it('creates category clusters containing only their own tools', () => {
    for (const cluster of data.clusters) {
      const expected = tools.filter((tool) => tool.category === cluster.id).map((tool) => tool.id);
      expect(cluster.nodeIds).toEqual(expected);
    }
  });

  it('creates links that reference known nodes', () => {
    const ids = new Set(data.nodes.map((node) => node.id));
    for (const link of data.links) {
      expect(ids.has(link.source)).toBe(true);
      expect(ids.has(link.target)).toBe(true);
    }
  });

  it('deduplicates reciprocal relation ids and workflow links', () => {
    const keys = data.links.map((link) => [link.source, link.target].sort().join('::'));
    expect(new Set(keys).size).toBe(keys.length);
  });

  it('returns focus plus direct neighbors for connected ids', () => {
    const focus = data.nodes.find((node) => node.relationIds.length > 0);

    expect(focus).toBeDefined();

    const connected = getConnectedNodeIds(data, focus!.id);

    expect(connected.has(focus!.id)).toBe(true);
    for (const relationId of focus!.relationIds) {
      expect(connected.has(relationId)).toBe(true);
    }
  });
});
