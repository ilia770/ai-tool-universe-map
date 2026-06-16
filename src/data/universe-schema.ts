import {
  type AITool,
  type ToolCategoryId,
  type WorkflowStageId,
  categories,
  categoryById,
  tools,
  toolById,
  workflowLinks,
  workflowStages,
} from './ai-tool-universe';

const allowedOrbits = new Set([0, 1, 2, 3]);
const allowedLinkStrengths = new Set(['primary', 'secondary']);
const stageIds = new Set<WorkflowStageId>(
  Object.keys(workflowStages) as WorkflowStageId[],
);

export const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const isValidUrl = (value: string) => {
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

const isValidClassification = (value: unknown) => {
  if (!isRecord(value)) return false;
  return typeof value.confidence === 'number'
    && value.confidence >= 0
    && value.confidence <= 1
    && Array.isArray(value.matchedKeywords)
    && value.matchedKeywords.every((keyword) => typeof keyword === 'string')
    && typeof value.reason === 'string';
};

interface ToolPayloadOptions {
  knownToolIds?: ReadonlySet<string>;
}

export const isValidCustomToolPayload = (
  value: unknown,
  options: ToolPayloadOptions = {},
): value is AITool => {
  if (!isRecord(value)) return false;

  const {
    angle,
    category,
    classification,
    id,
    logoDomain,
    name,
    orbit,
    relationIds,
    stage,
    summary,
    url,
  } = value;

  if (typeof id !== 'string' || !id.trim() || id === 'founder-os' || /\s/.test(id)) return false;
  if (typeof name !== 'string' || !name.trim()) return false;
  if (typeof summary !== 'string' || !summary.trim()) return false;
  if (typeof category !== 'string' || !categoryById.has(category as ToolCategoryId)) return false;
  if (typeof stage !== 'string' || !stageIds.has(stage as WorkflowStageId)) return false;
  if (typeof orbit !== 'number' || !Number.isInteger(orbit) || !allowedOrbits.has(orbit)) return false;
  if (typeof angle !== 'number' || !Number.isFinite(angle)) return false;
  if (url !== undefined && (typeof url !== 'string' || !isValidUrl(url))) return false;
  if (logoDomain !== undefined && typeof logoDomain !== 'string') return false;
  if (classification !== undefined && !isValidClassification(classification)) return false;
  if (!Array.isArray(relationIds) || !relationIds.every((relationId) => typeof relationId === 'string')) return false;

  const uniqueRelationIds = new Set(relationIds);
  if (uniqueRelationIds.size !== relationIds.length) return false;
  if (uniqueRelationIds.has(id)) return false;

  if (options.knownToolIds) {
    for (const relationId of uniqueRelationIds) {
      if (!options.knownToolIds.has(relationId)) return false;
    }
  }

  return true;
};

export const getToolArrayPayload = (value: unknown): unknown[] | null => {
  if (Array.isArray(value)) return value;
  if (isRecord(value) && Array.isArray(value.tools)) return value.tools;
  return null;
};

export const filterValidCustomTools = (
  value: unknown,
  existingToolIds: ReadonlySet<string> = new Set(toolById.keys()),
): AITool[] => {
  const payload = getToolArrayPayload(value);
  if (!payload) return [];

  const basicValidTools = payload.filter((tool): tool is AITool =>
    isValidCustomToolPayload(tool),
  );
  const knownToolIds = new Set([
    ...existingToolIds,
    ...basicValidTools.map((tool) => tool.id),
  ]);

  const seenIds = new Set<string>();
  return basicValidTools.filter((tool) => {
    if (seenIds.has(tool.id)) return false;
    seenIds.add(tool.id);
    return isValidCustomToolPayload(tool, { knownToolIds });
  });
};

export interface UniverseValidationResult {
  errors: string[];
  ok: boolean;
}

export const validateUniverseData = (): UniverseValidationResult => {
  const errors: string[] = [];
  const categoryIds = new Set<string>();
  const toolIds = new Set<string>();
  const knownStageIds = new Set(Object.keys(workflowStages));

  categories.forEach((category) => {
    if (categoryIds.has(category.id)) errors.push(`Duplicate category id: ${category.id}`);
    categoryIds.add(category.id);
    if (categoryById.get(category.id) !== category) errors.push(`categoryById is out of sync for ${category.id}`);
    if (!category.name.trim()) errors.push(`Category ${category.id} is missing a name`);
    if (!category.shortName.trim()) errors.push(`Category ${category.id} is missing a shortName`);
    if (!category.description.trim()) errors.push(`Category ${category.id} is missing a description`);
    if (!Number.isFinite(category.angle)) errors.push(`Category ${category.id} has an invalid angle`);
  });

  tools.forEach((tool, index) => {
    if (toolIds.has(tool.id)) errors.push(`Duplicate tool id: ${tool.id}`);
    toolIds.add(tool.id);
    if (toolById.get(tool.id) !== tool) errors.push(`toolById is out of sync for ${tool.id}`);
    if (index === 0 && tool.id !== 'founder-os') errors.push('tools[0] must be founder-os');
    if (!categoryIds.has(tool.category)) errors.push(`${tool.id} uses unknown category ${tool.category}`);
    if (!knownStageIds.has(tool.stage)) errors.push(`${tool.id} uses unknown stage ${tool.stage}`);
    if (!allowedOrbits.has(tool.orbit)) errors.push(`${tool.id} uses invalid orbit ${tool.orbit}`);
    if (!Number.isFinite(tool.angle)) errors.push(`${tool.id} has an invalid angle`);
    if (!tool.name.trim()) errors.push(`${tool.id} is missing a name`);
    if (!tool.summary.trim()) errors.push(`${tool.id} is missing a summary`);
    if (tool.url && !isValidUrl(tool.url)) errors.push(`${tool.id} has an invalid url`);
    if (tool.classification && !isValidClassification(tool.classification)) {
      errors.push(`${tool.id} has invalid classification metadata`);
    }
  });

  tools.forEach((tool) => {
    const relationIds = new Set(tool.relationIds);
    if (relationIds.size !== tool.relationIds.length) errors.push(`${tool.id} has duplicate relation ids`);
    if (relationIds.has(tool.id)) errors.push(`${tool.id} has a self relation`);
    relationIds.forEach((relationId) => {
      if (!toolIds.has(relationId)) errors.push(`${tool.id} points to missing relation ${relationId}`);
    });
  });

  workflowLinks.forEach((link) => {
    if (!toolIds.has(link.source)) errors.push(`Workflow link source is missing: ${link.source}`);
    if (!toolIds.has(link.target)) errors.push(`Workflow link target is missing: ${link.target}`);
    if (!allowedLinkStrengths.has(link.strength)) {
      errors.push(`Workflow link ${link.source} -> ${link.target} has invalid strength`);
    }
    if (link.confidence !== undefined && (link.confidence < 0 || link.confidence > 1)) {
      errors.push(`Workflow link ${link.source} -> ${link.target} has invalid confidence`);
    }
  });

  return { errors, ok: errors.length === 0 };
};
