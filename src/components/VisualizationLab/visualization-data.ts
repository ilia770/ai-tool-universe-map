import type {
  AITool,
  ToolCategory,
  ToolCategoryId,
  UniverseLink,
  WorkflowStageId,
} from '../../data/ai-tool-universe';

export interface LabNode {
  id: string;
  label: string;
  category: ToolCategoryId;
  categoryName: string;
  color: string;
  stage: WorkflowStageId;
  orbit: AITool['orbit'];
  angle: number;
  relationIds: string[];
  weight: number;
  summary: string;
}

export interface LabLink {
  id: string;
  source: string;
  target: string;
  strength: UniverseLink['strength'];
  label: string;
  confidence?: number;
}

export interface LabCluster {
  id: ToolCategoryId;
  label: string;
  color: string;
  nodeIds: string[];
}

export interface LabData {
  nodes: LabNode[];
  links: LabLink[];
  clusters: LabCluster[];
  nodeById: Map<string, LabNode>;
  clusterById: Map<ToolCategoryId, LabCluster>;
}

interface BuildVisualizationDataInput {
  categories: ToolCategory[];
  tools: AITool[];
  workflowLinks: UniverseLink[];
}

const linkKey = (source: string, target: string) => [source, target].sort().join('::');

export function buildVisualizationData({ categories, tools, workflowLinks }: BuildVisualizationDataInput): LabData {
  const categoryById = new Map(categories.map((category) => [category.id, category]));
  const knownToolIds = new Set(tools.map((tool) => tool.id));

  const nodes: LabNode[] = tools.map((tool) => {
    const category = categoryById.get(tool.category);

    return {
      id: tool.id,
      label: tool.name,
      category: tool.category,
      categoryName: category?.name ?? tool.category,
      color: category?.color ?? '#9be8ff',
      stage: tool.stage,
      orbit: tool.orbit,
      angle: tool.angle,
      relationIds: tool.relationIds.filter((relationId) => knownToolIds.has(relationId)),
      weight: 1 + tool.orbit * 0.35 + tool.relationIds.length * 0.08,
      summary: tool.summary,
    };
  });

  const linksByKey = new Map<string, LabLink>();

  workflowLinks.forEach((link) => {
    if (!knownToolIds.has(link.source) || !knownToolIds.has(link.target)) return;

    const key = linkKey(link.source, link.target);
    linksByKey.set(key, {
      id: key,
      source: link.source,
      target: link.target,
      strength: link.strength,
      label: link.label,
      confidence: link.confidence,
    });
  });

  tools.forEach((tool) => {
    tool.relationIds.forEach((relationId) => {
      if (!knownToolIds.has(relationId)) return;

      const key = linkKey(tool.id, relationId);
      if (linksByKey.has(key)) return;

      linksByKey.set(key, {
        id: key,
        source: tool.id,
        target: relationId,
        strength: 'secondary',
        label: 'Related',
      });
    });
  });

  const clusters: LabCluster[] = categories.map((category) => ({
    id: category.id,
    label: category.name,
    color: category.color,
    nodeIds: tools.filter((tool) => tool.category === category.id).map((tool) => tool.id),
  }));

  return {
    nodes,
    links: Array.from(linksByKey.values()),
    clusters,
    nodeById: new Map(nodes.map((node) => [node.id, node])),
    clusterById: new Map(clusters.map((cluster) => [cluster.id, cluster])),
  };
}

export function getConnectedNodeIds(data: LabData, focusId: string): Set<string> {
  const connected = new Set<string>([focusId]);

  data.links.forEach((link) => {
    if (link.source === focusId) connected.add(link.target);
    if (link.target === focusId) connected.add(link.source);
  });

  const focusNode = data.nodeById.get(focusId);
  focusNode?.relationIds.forEach((relationId) => connected.add(relationId));

  return connected;
}
