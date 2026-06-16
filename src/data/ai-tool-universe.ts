import universeSeed from './ai-tool-universe.seed.json';

export type ToolCategoryId =
  | 'coding'
  | 'design'
  | 'research'
  | 'media'
  | 'distribution'
  | 'infrastructure'
  | 'knowledge'
  | 'core'
  | 'analytics';

export type WorkflowStageId = 'research' | 'planning' | 'execution' | 'approval' | 'review';
export type LinkStrength = 'primary' | 'secondary';

export interface AITool {
  id: string;
  name: string;
  category: ToolCategoryId;
  summary: string;
  stage: WorkflowStageId;
  orbit: 0 | 1 | 2 | 3;
  angle: number;
  url?: string;
  logoDomain?: string;
  relationIds: string[];
  classification?: {
    confidence: number;
    matchedKeywords: string[];
    reason: string;
  };
}

export interface ToolCategory {
  id: ToolCategoryId;
  name: string;
  shortName: string;
  description: string;
  color: string;
  glow: string;
  angle: number;
}

export interface UniverseLink {
  source: string;
  target: string;
  strength: LinkStrength;
  label: string;
  /**
   * Optional 0-1 confidence in this relation. Undefined for hand-curated
   * links; set by a future API-backed classifier when provenance matters.
   */
  confidence?: number;
}

export interface WorkflowStage {
  name: string;
  description: string;
}

interface UniverseSeed {
  version: 1;
  categories: ToolCategory[];
  workflowStages: Record<WorkflowStageId, WorkflowStage>;
  tools: AITool[];
  workflowLinks: UniverseLink[];
}

const typedUniverseSeed = universeSeed as UniverseSeed;

export const categories: ToolCategory[] = typedUniverseSeed.categories;
export const workflowStages: Record<WorkflowStageId, WorkflowStage> = typedUniverseSeed.workflowStages;
export const tools: AITool[] = typedUniverseSeed.tools;
export const workflowLinks: UniverseLink[] = typedUniverseSeed.workflowLinks;

export const categoryById = new Map(categories.map((c) => [c.id, c]));
export const toolById = new Map(tools.map((t) => [t.id, t]));
