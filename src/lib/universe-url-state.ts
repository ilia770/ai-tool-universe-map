import type { ToolCategoryId, WorkflowStageId } from '../data/ai-tool-universe';

export type UniverseRelationLens = 'direct' | 'adjacent' | 'stage' | 'category';
export type UniverseCategoryFilter = ToolCategoryId | 'all';
export type UniverseStageFilter = WorkflowStageId | 'all';

export interface UniverseAcquisitionSource {
  utmSource?: string;
  utmMedium?: string;
  utmCampaign?: string;
  ref?: string;
  tgStart?: string;
}

export interface InvalidUniverseParam {
  name: string;
  value: string;
}

export interface UniverseUrlState {
  toolId?: string;
  category: UniverseCategoryFilter;
  stage: UniverseStageFilter;
  query: string;
  lens: UniverseRelationLens;
  source: UniverseAcquisitionSource;
  hasExplicitState: boolean;
  invalidParams: InvalidUniverseParam[];
}

export interface UniverseUrlWritableState {
  selectedId: string;
  activeCategory: UniverseCategoryFilter;
  activeStage: UniverseStageFilter;
  query: string;
  relationLens: UniverseRelationLens;
}

interface ParseOptions {
  toolIds: ReadonlySet<string>;
  categoryIds: ReadonlySet<string>;
}

const stageIds = new Set<WorkflowStageId>(['research', 'planning', 'execution', 'approval', 'review']);
const relationLensIds = new Set<UniverseRelationLens>(['direct', 'adjacent', 'stage', 'category']);
const acquisitionParamNames = new Set(['utm_source', 'utm_medium', 'utm_campaign', 'ref', 'tg_start']);

const cleanParam = (value: string | null) => {
  const cleaned = value?.trim();
  return cleaned ? cleaned : undefined;
};

const appendInvalid = (invalidParams: InvalidUniverseParam[], name: string, value: string | undefined) => {
  if (value) invalidParams.push({ name, value });
};

export const parseUniverseUrlState = (search: string, options: ParseOptions): UniverseUrlState => {
  const params = new URLSearchParams(search);
  const invalidParams: InvalidUniverseParam[] = [];
  const tool = cleanParam(params.get('tool'));
  const category = cleanParam(params.get('category'));
  const stage = cleanParam(params.get('stage'));
  const query = cleanParam(params.get('q') ?? params.get('query')) ?? '';
  const lens = cleanParam(params.get('lens'));

  const state: UniverseUrlState = {
    category: 'all',
    stage: 'all',
    query,
    lens: 'direct',
    source: {
      utmSource: cleanParam(params.get('utm_source')),
      utmMedium: cleanParam(params.get('utm_medium')),
      utmCampaign: cleanParam(params.get('utm_campaign')),
      ref: cleanParam(params.get('ref')),
      tgStart: cleanParam(params.get('tg_start')),
    },
    hasExplicitState: false,
    invalidParams,
  };

  if (tool) {
    if (options.toolIds.has(tool)) {
      state.toolId = tool;
      state.hasExplicitState = true;
    } else {
      appendInvalid(invalidParams, 'tool', tool);
    }
  }

  if (category) {
    if (category === 'all' || options.categoryIds.has(category)) {
      state.category = category as UniverseCategoryFilter;
      state.hasExplicitState = true;
    } else {
      appendInvalid(invalidParams, 'category', category);
    }
  }

  if (stage) {
    if (stage === 'all' || stageIds.has(stage as WorkflowStageId)) {
      state.stage = stage as UniverseStageFilter;
      state.hasExplicitState = true;
    } else {
      appendInvalid(invalidParams, 'stage', stage);
    }
  }

  if (query) state.hasExplicitState = true;

  if (lens) {
    if (relationLensIds.has(lens as UniverseRelationLens)) {
      state.lens = lens as UniverseRelationLens;
      state.hasExplicitState = true;
    } else {
      appendInvalid(invalidParams, 'lens', lens);
    }
  }

  return state;
};

export const hasAcquisitionSource = (source: UniverseAcquisitionSource) =>
  Boolean(source.utmSource || source.utmMedium || source.utmCampaign || source.ref || source.tgStart);

export const getAcquisitionLabel = (source: UniverseAcquisitionSource) => {
  if (source.utmCampaign) return source.utmCampaign;
  if (source.tgStart) return source.tgStart;
  if (source.utmSource) return source.utmSource;
  if (source.ref) return source.ref;
  return null;
};

const setOrDelete = (params: URLSearchParams, name: string, value: string | null, defaultValue?: string) => {
  if (!value || value === defaultValue) {
    params.delete(name);
    return;
  }
  params.set(name, value);
};

export const buildUniverseSearch = (currentSearch: string, state: UniverseUrlWritableState) => {
  const currentParams = new URLSearchParams(currentSearch);
  const nextParams = new URLSearchParams();

  for (const [key, value] of currentParams.entries()) {
    if (acquisitionParamNames.has(key)) nextParams.set(key, value);
  }

  setOrDelete(nextParams, 'tool', state.selectedId, 'founder-os');
  setOrDelete(nextParams, 'category', state.activeCategory, 'all');
  setOrDelete(nextParams, 'stage', state.activeStage, 'all');
  setOrDelete(nextParams, 'q', state.query.trim() || null);
  setOrDelete(nextParams, 'lens', state.relationLens, 'direct');

  const serialized = nextParams.toString();
  return serialized ? `?${serialized}` : '';
};
