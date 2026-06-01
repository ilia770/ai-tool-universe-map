import { ChangeEvent, FormEvent, lazy, Suspense, useEffect, useMemo, useRef, useState } from 'react';
import {
  Brain,
  Check,
  Download,
  Filter,
  Globe,
  Link2,
  RotateCcw,
  Search,
  Sparkles,
  Upload,
  X,
  Zap,
} from 'lucide-react';
import {
  type AITool,
  type ToolCategoryId,
  type WorkflowStageId,
  categories,
  workflowStages,
  categoryById,
  tools,
} from '../data/ai-tool-universe';
import { classifyToolDetailed, makeSlug, getDisplayName } from '../lib/classify-ai-tool';
import { hasLogoDevKey } from '../lib/tool-logos';
import { ToolLogo } from './ToolLogo';

const AIToolUniverse3D = lazy(() =>
  import('./AIToolUniverse3D').then((m) => ({ default: m.Scene })),
);

interface AIToolUniverseMapProps {
  onClose: () => void;
}

type RelationLens = 'direct' | 'adjacent' | 'stage' | 'category';
type MapClarityMode = 'focus' | 'context' | 'atlas';

const CUSTOM_TOOLS_STORAGE_KEY = 'ai-tool-universe.custom-tools.v1';
const orderedStages: WorkflowStageId[] = ['research', 'planning', 'execution', 'approval', 'review'];
const stageDockLabels: Record<WorkflowStageId, string> = {
  research: 'Research',
  planning: 'Plan',
  execution: 'Build',
  approval: 'Approve',
  review: 'Review',
};

const stageActions: Record<WorkflowStageId, string> = {
  research: 'Use it to collect context before planning the build.',
  planning: 'Use it to shape scope, flows, screens, and implementation order.',
  execution: 'Use it when the plan is clear and the product needs to be built.',
  approval: 'Use it as a human checkpoint before publishing or merging.',
  review: 'Use it to critique, test, and improve the work after execution.',
};

const relationLensOptions: Array<{
  id: RelationLens;
  label: string;
  shortLabel: string;
  description: string;
}> = [
  {
    id: 'direct',
    label: 'Direct network',
    shortLabel: 'Direct',
    description: 'Shows the first dependency layer: tools this service directly uses or is used with.',
  },
  {
    id: 'adjacent',
    label: 'Adjacent orbit',
    shortLabel: 'Orbit',
    description: 'Expands the map one hop wider so nearby companion tools become visible.',
  },
  {
    id: 'stage',
    label: 'Same stage',
    shortLabel: 'Stage',
    description: 'Groups tools by the current workflow moment: research, planning, build, approval, or review.',
  },
  {
    id: 'category',
    label: 'Same group',
    shortLabel: 'Group',
    description: 'Keeps attention inside the selected tool category so the cluster reads as one system.',
  },
];

const mapClarityOptions: Array<{
  id: MapClarityMode;
  label: string;
  description: string;
}> = [
  {
    id: 'focus',
    label: 'Focus map',
    description: 'Quiet view. Shows the selected service, hover target, and first-order relationships.',
  },
  {
    id: 'context',
    label: 'Context map',
    description: 'Balanced view. Keeps the active cluster readable without turning the whole galaxy into labels.',
  },
  {
    id: 'atlas',
    label: 'Atlas map',
    description: 'Wide view. Useful for scanning the full ecosystem when you want more visible labels.',
  },
];

const stageIds = new Set<WorkflowStageId>(orderedStages);

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const getNormalizedHost = (value: string | undefined) => {
  if (!value) return null;

  try {
    const url = new URL(value.startsWith('http') ? value : `https://${value}`);
    return url.hostname.replace(/^www\./, '').toLowerCase();
  } catch {
    return null;
  }
};

const isValidToolPayload = (value: unknown): value is AITool => {
  if (!isRecord(value)) return false;
  const category = value.category;
  const stage = value.stage;
  const orbit = value.orbit;

  return typeof value.id === 'string'
    && typeof value.name === 'string'
    && typeof value.summary === 'string'
    && typeof category === 'string'
    && categoryById.has(category as ToolCategoryId)
    && typeof stage === 'string'
    && stageIds.has(stage as WorkflowStageId)
    && typeof orbit === 'number'
    && [0, 1, 2, 3].includes(orbit)
    && typeof value.angle === 'number'
    && value.id !== 'founder-os'
    && (!('logoDomain' in value) || typeof value.logoDomain === 'string')
    && Array.isArray(value.relationIds)
    && value.relationIds.every((id) => typeof id === 'string');
};

const readStoredCustomTools = (): AITool[] => {
  if (typeof window === 'undefined') return [];

  try {
    const raw = window.localStorage.getItem(CUSTOM_TOOLS_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter(isValidToolPayload) : [];
  } catch {
    return [];
  }
};

export const AIToolUniverseMap = ({ onClose }: AIToolUniverseMapProps) => {
  const dialogRef = useRef<HTMLDivElement>(null);
  const importInputRef = useRef<HTMLInputElement>(null);
  const [selectedId, setSelectedId] = useState('founder-os');
  const [query, setQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState<ToolCategoryId | 'all'>('all');
  const [activeStage, setActiveStage] = useState<WorkflowStageId | 'all'>('all');
  const [relationLens, setRelationLens] = useState<RelationLens>('direct');
  const [mapClarity, setMapClarity] = useState<MapClarityMode>('focus');
  const [toolInput, setToolInput] = useState('');
  const [customTools, setCustomTools] = useState<AITool[]>(readStoredCustomTools);
  const [cameraVersion, setCameraVersion] = useState(0);
  const [intakeMessage, setIntakeMessage] = useState<string | null>(null);
  const [importStatus, setImportStatus] = useState<{
    tone: 'success' | 'error' | 'neutral';
    message: string;
  } | null>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    const previousActiveElement = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null;
    document.body.style.overflow = 'hidden';

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
        return;
      }

      if (event.key !== 'Tab') return;

      const dialog = dialogRef.current;
      if (!dialog) return;

      const focusableElements = Array.from(
        dialog.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      ).filter((element) => !element.hasAttribute('disabled') && element.offsetParent !== null);

      if (focusableElements.length === 0) {
        event.preventDefault();
        dialog.focus();
        return;
      }

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      const activeElement = document.activeElement;

      if (event.shiftKey && activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      } else if (!event.shiftKey && activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    requestAnimationFrame(() => dialogRef.current?.focus({ preventScroll: true }));

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', handleKeyDown);
      previousActiveElement?.focus({ preventScroll: true });
    };
  }, [onClose]);

  useEffect(() => {
    window.localStorage.setItem(CUSTOM_TOOLS_STORAGE_KEY, JSON.stringify(customTools));
  }, [customTools]);

  const allTools = useMemo(() => [...tools, ...customTools], [customTools]);
  const nodeById = useMemo(() => new Map(allTools.map((tool) => [tool.id, tool])), [allTools]);
  const normalizedQuery = query.trim().toLowerCase();
  const visibleTools = useMemo(
    () => allTools.filter((tool) => {
      const matchCategory = activeCategory === 'all' || tool.category === activeCategory;
      const matchStage = activeStage === 'all' || tool.stage === activeStage;
      const matchQuery = !normalizedQuery
        || tool.name.toLowerCase().includes(normalizedQuery)
        || tool.summary.toLowerCase().includes(normalizedQuery);
      return matchCategory && matchStage && matchQuery;
    }),
    [activeCategory, activeStage, allTools, normalizedQuery],
  );
  const queryResultTools = useMemo(() => {
    if (!normalizedQuery) return [];

    return allTools.filter((tool) => {
      if (tool.id === 'founder-os') return false;

      const category = categoryById.get(tool.category);
      return tool.name.toLowerCase().includes(normalizedQuery)
        || tool.summary.toLowerCase().includes(normalizedQuery)
        || (tool.url?.toLowerCase().includes(normalizedQuery) ?? false)
        || (category?.name.toLowerCase().includes(normalizedQuery) ?? false)
        || (category?.shortName.toLowerCase().includes(normalizedQuery) ?? false)
        || workflowStages[tool.stage].name.toLowerCase().includes(normalizedQuery);
    });
  }, [allTools, normalizedQuery]);
  const searchResultTools = useMemo(() => queryResultTools.slice(0, 6), [queryResultTools]);
  const categoryCounts = useMemo(
    () => new Map(categories.map((category) => [
      category.id,
      allTools.filter((tool) => tool.category === category.id).length,
    ])),
    [allTools],
  );
  const stageCounts = useMemo(
    () => new Map(orderedStages.map((stage) => [
      stage,
      allTools.filter((tool) => tool.stage === stage).length,
    ])),
    [allTools],
  );
  const selectedTool = nodeById.get(selectedId) ?? allTools[0];
  const selectedCategory = categoryById.get(selectedTool.category) ?? categories[0];
  const focusLabel = activeCategory === 'all'
    ? 'All groups'
    : (categoryById.get(activeCategory)?.name ?? 'Unknown group');
  const pocketWorldLabel = activeCategory !== 'all'
    ? categoryById.get(activeCategory)?.shortName ?? 'Group'
    : selectedTool.id !== 'founder-os' && selectedTool.category !== 'core'
      ? selectedCategory.shortName
      : null;
  const stageLabel = activeStage === 'all'
    ? 'All workflow stages'
    : workflowStages[activeStage].name;
  const intakePreview = useMemo(
    () => (toolInput.trim() ? classifyToolDetailed(toolInput) : null),
    [toolInput],
  );
  const directRelationIds = useMemo(() => {
    const ids = new Set<string>(selectedTool.relationIds);
    allTools.forEach((tool) => {
      if (tool.relationIds.includes(selectedTool.id)) ids.add(tool.id);
    });
    ids.delete(selectedTool.id);
    return ids;
  }, [allTools, selectedTool]);
  const directConnectedTools = useMemo(() =>
    Array.from(directRelationIds)
      .map((id) => nodeById.get(id))
      .filter((tool): tool is AITool => Boolean(tool))
      .slice(0, 8),
    [directRelationIds, nodeById],
  );
  const adjacentConnectedTools = useMemo(() => {
    const adjacentIds = new Set<string>();
    directConnectedTools.forEach((tool) => {
      tool.relationIds.forEach((id) => {
        if (id !== selectedTool.id && !directRelationIds.has(id)) adjacentIds.add(id);
      });
    });
    return Array.from(adjacentIds)
      .map((id) => nodeById.get(id))
      .filter((tool): tool is AITool => Boolean(tool))
      .slice(0, 8);
  }, [directConnectedTools, directRelationIds, nodeById, selectedTool.id]);
  const sameStageTools = useMemo(
    () => allTools
      .filter((tool) => tool.id !== selectedTool.id && tool.stage === selectedTool.stage)
      .slice(0, 12),
    [allTools, selectedTool.id, selectedTool.stage],
  );
  const sameCategoryTools = useMemo(
    () => allTools
      .filter((tool) => tool.id !== selectedTool.id && tool.category === selectedTool.category)
      .slice(0, 12),
    [allTools, selectedTool.category, selectedTool.id],
  );
  const lensTools = useMemo(() => {
    if (relationLens === 'stage') return sameStageTools;
    if (relationLens === 'category') return sameCategoryTools;
    if (relationLens === 'adjacent') {
      const seen = new Set<string>();
      return [...directConnectedTools, ...adjacentConnectedTools].filter((tool) => {
        if (seen.has(tool.id)) return false;
        seen.add(tool.id);
        return true;
      });
    }
    return directConnectedTools;
  }, [adjacentConnectedTools, directConnectedTools, relationLens, sameCategoryTools, sameStageTools]);
  const relationLensCounts = useMemo(() => new Map<RelationLens, number>([
    ['direct', directConnectedTools.length],
    ['adjacent', new Set([...directConnectedTools, ...adjacentConnectedTools].map((tool) => tool.id)).size],
    ['stage', sameStageTools.length],
    ['category', sameCategoryTools.length],
  ]), [adjacentConnectedTools, directConnectedTools, sameCategoryTools, sameStageTools]);
  const selectedStageIndex = orderedStages.indexOf(selectedTool.stage);
  const activeClusterCategoryId = activeCategory !== 'all' ? activeCategory : selectedTool.category;
  const activeClusterCategory = categoryById.get(activeClusterCategoryId) ?? selectedCategory;
  const clusterTools = useMemo(
    () => allTools
      .filter((tool) => tool.category === activeClusterCategoryId)
      .sort((a, b) => {
        if (a.id === selectedTool.id) return -1;
        if (b.id === selectedTool.id) return 1;
        return a.orbit - b.orbit
          || orderedStages.indexOf(a.stage) - orderedStages.indexOf(b.stage)
          || a.name.localeCompare(b.name);
      }),
    [activeClusterCategoryId, allTools, selectedTool.id],
  );
  const clusterStageCounts = useMemo(
    () => new Map(orderedStages.map((stage) => [
      stage,
      clusterTools.filter((tool) => tool.stage === stage).length,
    ])),
    [clusterTools],
  );

  const focusTool = (tool: AITool) => {
    setSelectedId(tool.id);
    setActiveCategory(tool.category);
    setActiveStage(tool.stage);
    setRelationLens('direct');
    setMapClarity('focus');
    setQuery('');
    setCameraVersion((version) => version + 1);
  };

  const selectToolId = (id: string) => {
    setSelectedId(id);
    setCameraVersion((version) => version + 1);
  };

  const recenterSelectedTool = () => {
    setCameraVersion((version) => version + 1);
  };

  const showAllGroups = () => {
    setActiveCategory('all');
    setActiveStage('all');
    setRelationLens('direct');
    setMapClarity('atlas');
    setQuery('');
    setSelectedId('founder-os');
    setCameraVersion((version) => version + 1);
  };

  const focusCategory = (categoryId: ToolCategoryId | 'all') => {
    if (categoryId === 'all') {
      showAllGroups();
      return;
    }

    const anchorTool = selectedTool.category === categoryId && selectedTool.id !== 'founder-os'
      ? selectedTool
      : allTools
        .filter((tool) => tool.category === categoryId && tool.id !== 'founder-os')
        .sort((a, b) => a.orbit - b.orbit || orderedStages.indexOf(a.stage) - orderedStages.indexOf(b.stage))[0];

    if (anchorTool) setSelectedId(anchorTool.id);
    setActiveCategory(categoryId);
    setActiveStage('all');
    setRelationLens('category');
    setMapClarity('context');
    setQuery('');
    setCameraVersion((version) => version + 1);
  };

  const handleAddTool = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const value = toolInput.trim();
    if (!value) {
      setIntakeMessage('Paste a tool name or URL before adding it.');
      return;
    }

    const classification = classifyToolDetailed(value);
    const category = classification.category;
    const categoryMeta = categoryById.get(category) ?? categories[0];
    const displayName = getDisplayName(value);
    const url = value.startsWith('http')
      ? value
      : value.includes('.') && !value.includes(' ')
        ? `https://${value}`
        : undefined;
    const inputHost = getNormalizedHost(url ?? value);
    const inputSlug = makeSlug(displayName);
    const existingTool = allTools.find((tool) =>
      makeSlug(tool.name) === inputSlug
      || (inputHost && getNormalizedHost(tool.url) === inputHost),
    );

    if (existingTool) {
      focusTool(existingTool);
      setIntakeMessage(`${existingTool.name} already exists in ${categoryById.get(existingTool.category)?.name ?? 'the universe'}. Focused the existing node.`);
      setImportStatus(null);
      setToolInput('');
      return;
    }

    const siblingCount = allTools.filter((tool) => tool.category === category).length;
    const id = `custom-${makeSlug(value)}-${Date.now()}`;
    const relationIds = Array.from(new Set(classification.relationIds)).filter((relationId) =>
      nodeById.has(relationId),
    );
    const customTool: AITool = {
      id,
      name: displayName,
      category,
      summary: `Rule-based intake placed this in ${categoryMeta.name}. ${classification.reason}`,
      stage: classification.stage,
      orbit: 3,
      angle: categoryMeta.angle + 10 + siblingCount * 7,
      url,
      relationIds,
      classification: {
        confidence: classification.confidence,
        matchedKeywords: classification.matchedKeywords,
        reason: classification.reason,
      },
    };

    setCustomTools((current) => [...current, customTool]);
    setSelectedId(id);
    setActiveCategory(category);
    setActiveStage(classification.stage);
    setRelationLens('direct');
    setMapClarity('focus');
    setCameraVersion((version) => version + 1);
    setIntakeMessage(`${displayName} was added to ${categoryMeta.name}.`);
    setImportStatus(null);
    setToolInput('');
  };

  const handleExportCustomTools = () => {
    const payload = JSON.stringify({ version: 1, tools: customTools }, null, 2);
    const blob = new Blob([payload], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'ai-tool-universe-custom-tools.json';
    anchor.click();
    URL.revokeObjectURL(url);
  };

  const handleImportCustomTools = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    try {
      const text = await file.text();
      const parsed = JSON.parse(text);
      const importedTools = Array.isArray(parsed)
        ? parsed
        : isRecord(parsed)
          ? parsed.tools
          : null;
      if (!Array.isArray(importedTools)) {
        setImportStatus({ tone: 'error', message: 'JSON must be an array of tools or an object with a tools array.' });
        return;
      }

      const validTools = importedTools.filter(isValidToolPayload);
      if (validTools.length === 0) {
        setImportStatus({ tone: 'error', message: 'No valid custom tools were found in this JSON file.' });
        return;
      }

      const existingIds = new Set(allTools.map((tool) => tool.id));
      const uniqueImported = validTools.filter((tool) => {
        if (existingIds.has(tool.id)) return false;
        existingIds.add(tool.id);
        return true;
      });
      setCustomTools((current) => [...current, ...uniqueImported]);
      setImportStatus({
        tone: uniqueImported.length > 0 ? 'success' : 'neutral',
        message: uniqueImported.length > 0
          ? `Imported ${uniqueImported.length} custom tool${uniqueImported.length === 1 ? '' : 's'}.`
          : 'Every valid tool in this file already exists in the universe.',
      });
    } catch {
      setImportStatus({ tone: 'error', message: 'This file is not readable JSON.' });
    }
  };

  return (
    <div
      className="fixed inset-0 z-[80] overflow-hidden bg-[#03040a] text-text-primary"
      ref={dialogRef}
      role="dialog"
      aria-modal="true"
      aria-label="AI Tool Universe Map"
      data-testid="ai-tool-universe-map"
      tabIndex={-1}
    >
      <div className="absolute inset-0 ai-universe-stars" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_42%,rgba(93,89,255,0.18),transparent_34%),radial-gradient(circle_at_18%_24%,rgba(20,184,166,0.12),transparent_24%),radial-gradient(circle_at_82%_72%,rgba(236,72,153,0.12),transparent_28%)]" />

      <header className="relative z-20 flex h-16 items-center justify-between border-b border-white/10 bg-black/25 px-4 backdrop-blur-2xl md:px-6">
        <div className="flex min-w-0 items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg border border-cyan-300/30 bg-cyan-300/10 shadow-[0_0_28px_rgba(34,211,238,0.2)]">
            <Brain className="h-5 w-5 text-cyan-100" />
          </div>
          <div className="min-w-0">
            <h1 className="truncate text-sm font-semibold tracking-wide text-white md:text-base">
              AI Tool Universe Map
            </h1>
            <p className="hidden text-xs text-text-secondary md:block">
              Research → Planning → Execution → Approval → AI Agent Review
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="hidden items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-text-secondary backdrop-blur-xl lg:flex">
            <Sparkles className="h-3.5 w-3.5 text-cyan-200" />
            {allTools.length} tools · {categories.length} categories
          </div>
          <button
            onClick={onClose}
            aria-label="Close map"
            className="flex h-9 w-9 items-center justify-center rounded-md border border-white/10 bg-white/5 text-text-secondary transition-colors hover:bg-white/10 hover:text-white"
            title="Close map"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      </header>

      <main className="relative z-10 grid h-[calc(100dvh-4rem)] grid-cols-1 overflow-y-auto lg:grid-cols-[280px_minmax(0,1fr)_340px] lg:overflow-hidden">
        <aside className="order-2 border-t border-white/10 bg-black/20 p-4 backdrop-blur-xl lg:order-1 lg:overflow-y-auto lg:border-t-0 lg:border-r">
          <form
            onSubmit={handleAddTool}
            className="rounded-xl border border-white/15 bg-white/[0.07] p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_18px_60px_rgba(0,0,0,0.28)] backdrop-blur-2xl"
          >
            <label className="mb-2 flex items-center gap-2 text-xs font-medium uppercase text-cyan-100/80">
              <Zap className="h-3.5 w-3.5" />
              Liquid Glass Intake
            </label>
            <div className="flex gap-2">
              <input
                value={toolInput}
                onChange={(event) => {
                  setToolInput(event.target.value);
                  setIntakeMessage(null);
                }}
                placeholder="Tool name or URL"
                className="min-w-0 flex-1 rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none transition focus:border-cyan-300/50 focus:ring-2 focus:ring-cyan-300/20"
              />
              <button
                type="submit"
                aria-label="Classify tool"
                className="flex h-9 w-9 items-center justify-center rounded-lg bg-cyan-300 text-slate-950 transition hover:bg-cyan-200"
                title="Classify tool"
              >
                <Check className="h-4 w-4" />
              </button>
            </div>
            <p className="mt-2 text-xs leading-relaxed text-text-secondary">
              Rule-based draft classifier. Later it can become an AI classifier with persisted relations.
            </p>
            {intakeMessage && (
              <p className="mt-2 text-xs leading-5 text-cyan-50/80" role="status">
                {intakeMessage}
              </p>
            )}
            {intakePreview && (
              <div className="mt-3 rounded-lg border border-cyan-200/15 bg-cyan-200/[0.06] p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="text-xs font-semibold uppercase text-cyan-100">
                    {categoryById.get(intakePreview.category)?.shortName ?? 'Core'}
                  </span>
                  <span className="rounded-full bg-white/10 px-2 py-1 text-[11px] text-cyan-50">
                    {Math.round(intakePreview.confidence * 100)}% match
                  </span>
                </div>
                <p className="mt-2 text-xs leading-5 text-text-secondary">
                  Stage: {workflowStages[intakePreview.stage].name}
                  {intakePreview.matchedKeywords.length > 0 && (
                    <> · Signals: {intakePreview.matchedKeywords.join(', ')}</>
                  )}
                </p>
                <div className="mt-2 flex items-center gap-1.5 text-[11px] text-text-muted">
                  <Link2 className="h-3 w-3" />
                  {intakePreview.relationIds
                    .map((relationId) => nodeById.get(relationId)?.name)
                    .filter(Boolean)
                    .slice(0, 3)
                    .join(' + ')}
                </div>
              </div>
            )}
          </form>

          <div className="mt-4 rounded-xl border border-white/10 bg-black/25 p-3 backdrop-blur-xl">
            <label className="mb-2 flex items-center gap-2 text-xs font-medium uppercase text-text-secondary">
              <Search className="h-3.5 w-3.5" />
              Search
            </label>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Cursor, video, skills..."
              className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none transition focus:border-fuchsia-300/40 focus:ring-2 focus:ring-fuchsia-300/10"
            />
            {normalizedQuery && (
              <div className="mt-3 rounded-lg border border-white/10 bg-black/25 p-2">
                <div className="mb-2 flex items-center justify-between gap-2 px-1">
                  <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-text-muted">
                    Scan results
                  </p>
                  <span className="text-[11px] text-text-muted">
                    {queryResultTools.length}
                  </span>
                </div>
                <div className="space-y-1.5">
                  {searchResultTools.length > 0 ? (
                    searchResultTools.map((tool) => {
                      const category = categoryById.get(tool.category) ?? categories[0];
                      return (
                        <button
                          key={tool.id}
                          type="button"
                          onClick={() => focusTool(tool)}
                          className={`flex w-full items-center gap-2 rounded-lg border px-2 py-2 text-left transition ${
                            selectedTool.id === tool.id
                              ? 'border-cyan-200/30 bg-cyan-200/[0.08] text-white'
                              : 'border-white/10 bg-white/[0.035] text-text-secondary hover:bg-white/[0.075] hover:text-white'
                          }`}
                        >
                          <ToolLogo tool={tool} size={24} />
                          <span className="min-w-0 flex-1">
                            <span className="block truncate text-xs font-semibold">{tool.name}</span>
                            <span className="mt-0.5 block truncate text-[11px] text-text-muted">
                              {category.shortName} · {stageDockLabels[tool.stage]}
                            </span>
                          </span>
                        </button>
                      );
                    })
                  ) : (
                    <div className="rounded-lg border border-white/10 bg-white/[0.035] px-3 py-3 text-xs leading-5 text-text-muted">
                      No matching tools in this universe. Paste it into intake to classify it.
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          <div className="mt-4 space-y-2">
            <button
              onClick={showAllGroups}
              className={`flex w-full items-center justify-between rounded-lg border px-3 py-2 text-sm transition ${
                activeCategory === 'all'
                  ? 'border-white/25 bg-white/12 text-white'
                  : 'border-white/10 bg-white/5 text-text-secondary hover:bg-white/10 hover:text-white'
              }`}
            >
              <span className="flex items-center gap-2">
                <Filter className="h-3.5 w-3.5" />
                All categories
              </span>
              <span>{allTools.length}</span>
            </button>
            {categories.map((category) => {
              const count = categoryCounts.get(category.id) ?? 0;
              return (
                <button
                  key={category.id}
                  onClick={() => focusCategory(category.id)}
                  className={`flex w-full items-center gap-3 rounded-lg border px-3 py-2 text-left text-sm transition ${
                    activeCategory === category.id
                      ? 'border-white/25 bg-white/12 text-white'
                      : 'border-white/10 bg-white/5 text-text-secondary hover:bg-white/10 hover:text-white'
                  }`}
                >
                  <span
                    className="h-2.5 w-2.5 rounded-full"
                    style={{ backgroundColor: category.color, boxShadow: `0 0 16px ${category.glow}` }}
                  />
                  <span className="min-w-0 flex-1 truncate">{category.shortName}</span>
                  <span className="text-xs text-text-muted">{count}</span>
                </button>
              );
            })}
          </div>

          {customTools.length > 0 && (
            <div className="mt-4 grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={handleExportCustomTools}
                className="flex items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-xs text-text-muted transition hover:bg-white/10 hover:text-white"
              >
                <Download className="h-3.5 w-3.5" />
                Export
              </button>
              <button
                type="button"
              onClick={() => {
                setCustomTools([]);
                setSelectedId('founder-os');
                setActiveCategory('all');
                setActiveStage('all');
                setRelationLens('direct');
                setMapClarity('focus');
                setQuery('');
                setCameraVersion((version) => version + 1);
                setImportStatus({ tone: 'neutral', message: 'Custom tools were cleared from this browser.' });
              }}
                className="flex items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-xs text-text-muted transition hover:bg-white/10 hover:text-white"
              >
                <RotateCcw className="h-3.5 w-3.5" />
                Reset
              </button>
            </div>
          )}
          <input
            ref={importInputRef}
            type="file"
            accept="application/json,.json"
            className="hidden"
            onChange={handleImportCustomTools}
          />
          <button
            type="button"
            onClick={() => importInputRef.current?.click()}
            className="mt-2 flex w-full items-center justify-center gap-2 rounded-lg border border-white/10 bg-black/20 px-3 py-2 text-xs text-text-muted transition hover:bg-white/10 hover:text-white"
          >
            <Upload className="h-3.5 w-3.5" />
            Import custom tools JSON
          </button>
          {importStatus && (
            <p
              className={`mt-2 rounded-lg border px-3 py-2 text-xs leading-5 ${
                importStatus.tone === 'error'
                  ? 'border-rose-300/20 bg-rose-300/[0.06] text-rose-100/85'
                  : importStatus.tone === 'success'
                    ? 'border-cyan-200/20 bg-cyan-200/[0.06] text-cyan-50/85'
                    : 'border-white/10 bg-white/[0.04] text-text-muted'
              }`}
              role="status"
            >
              {importStatus.message}
            </p>
          )}
          <p className="mt-3 rounded-lg border border-white/10 bg-white/[0.035] px-3 py-2 text-xs leading-5 text-text-muted">
            Logos use Logo.dev when `VITE_LOGO_DEV_PUBLISHABLE_KEY` is set. Current mode: {hasLogoDevKey ? 'Logo.dev CDN' : 'local SVG fallback'}.
          </p>
        </aside>

        <section className="order-1 relative min-h-[680px] overflow-hidden sm:min-h-[620px] md:min-h-[640px] lg:order-2 lg:h-[calc(100dvh-4rem)] lg:min-h-0">
          <Suspense fallback={
            <div className="absolute inset-0 flex items-center justify-center bg-[#020008]">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-cyan-300/30 border-t-cyan-300" />
            </div>
          }>
            <AIToolUniverse3D
              selectedId={selectedId}
              onSelectId={selectToolId}
              activeCategory={activeCategory}
              activeStage={activeStage}
              query={query}
              customTools={customTools}
              relationLens={relationLens}
              mapClarity={mapClarity}
              cameraVersion={cameraVersion}
              onSelectCategory={focusCategory}
            />
          </Suspense>

          <div className="pointer-events-none absolute inset-x-3 bottom-3 z-20 md:inset-x-5 md:bottom-4">
            <div className="pointer-events-auto mx-auto max-w-5xl rounded-2xl border border-white/15 bg-[#050814]/76 p-2.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_22px_80px_rgba(0,0,0,0.45)] backdrop-blur-2xl">
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-cyan-100/75">
                    Universe lens
                  </p>
                  <p className="text-xs text-text-muted">
                    {pocketWorldLabel ? `Pocket world · ${pocketWorldLabel}` : focusLabel} · {stageLabel} · {visibleTools.length}/{allTools.length} visible
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setActiveCategory('all');
                    setActiveStage('all');
                    setRelationLens('direct');
                    setMapClarity('focus');
                    setSelectedId('founder-os');
                    setQuery('');
                    setCameraVersion((version) => version + 1);
                  }}
                  className="hidden rounded-lg border border-white/10 bg-white/[0.05] px-3 py-2 text-xs text-text-secondary transition hover:bg-white/10 hover:text-white md:block"
                >
                  Reset view
                </button>
              </div>

              <div className="mt-2 flex gap-2 overflow-x-auto pb-1">
                <button
                  type="button"
                  onClick={showAllGroups}
                  className={`shrink-0 rounded-full border px-3 py-2 text-xs transition ${
                    activeCategory === 'all'
                      ? 'border-white/30 bg-white/15 text-white'
                      : 'border-white/10 bg-white/[0.04] text-text-secondary hover:bg-white/10'
                  }`}
                >
                  All groups
                </button>
                {categories.filter((category) => category.id !== 'core').map((category) => {
                  const count = categoryCounts.get(category.id) ?? 0;
                  const isActive = activeCategory === category.id;
                  return (
                    <button
                      key={category.id}
                      type="button"
                      onClick={() => focusCategory(category.id)}
                      className={`flex shrink-0 items-center gap-2 rounded-full border px-3 py-2 text-xs transition ${
                        isActive
                          ? 'border-white/30 bg-white/15 text-white'
                          : 'border-white/10 bg-white/[0.04] text-text-secondary hover:bg-white/10'
                      }`}
                    >
                      <span
                        className="h-2 w-2 rounded-full"
                        style={{ backgroundColor: category.color, boxShadow: `0 0 12px ${category.glow}` }}
                      />
                      {category.shortName}
                      <span className="text-text-muted">{count}</span>
                    </button>
                  );
                })}
              </div>

              <div className="mt-1.5 grid grid-cols-2 gap-1.5 md:grid-cols-4">
                {relationLensOptions.map((option) => {
                  const isActive = relationLens === option.id;
                  return (
                    <button
                      key={option.id}
                      type="button"
                      onClick={() => setRelationLens(option.id)}
                      className={`rounded-xl border px-3 py-2 text-left text-xs transition ${
                        isActive
                          ? 'border-fuchsia-200/35 bg-fuchsia-200/14 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12)]'
                          : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06] hover:text-text-secondary'
                      }`}
                      title={option.description}
                    >
                      <span className="block text-[10px] font-semibold text-fuchsia-100/70">
                        {relationLensCounts.get(option.id) ?? 0} linked
                      </span>
                      {option.label}
                    </button>
                  );
                })}
              </div>

              <div className="mt-1.5 grid grid-cols-3 gap-1.5">
                {mapClarityOptions.map((option) => {
                  const isActive = mapClarity === option.id;
                  return (
                    <button
                      key={option.id}
                      type="button"
                      onClick={() => setMapClarity(option.id)}
                      className={`rounded-xl border px-3 py-2 text-left text-xs transition ${
                        isActive
                          ? 'border-emerald-200/35 bg-emerald-200/14 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12)]'
                          : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06] hover:text-text-secondary'
                      }`}
                      title={option.description}
                    >
                      <span className="block text-[10px] font-semibold text-emerald-100/70">
                        Clarity
                      </span>
                      {option.label}
                    </button>
                  );
                })}
              </div>

              <div className="mt-1.5 grid grid-cols-3 gap-1.5 md:grid-cols-6">
                <button
                  type="button"
                  onClick={() => setActiveStage('all')}
                  className={`rounded-xl border px-3 py-2 text-left text-xs transition ${
                    activeStage === 'all'
                      ? 'border-cyan-200/35 bg-cyan-200/15 text-white'
                      : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06]'
                  }`}
                >
                  <span className="block text-[10px] uppercase text-cyan-100/70">Lens</span>
                  All stages
                </button>
                {orderedStages.map((stage, index) => {
                  const isActive = activeStage === stage;
                  const count = stageCounts.get(stage) ?? 0;
                  return (
                    <button
                      key={stage}
                      type="button"
                      onClick={() => setActiveStage(stage)}
                      className={`rounded-xl border px-3 py-2 text-left text-xs transition ${
                        isActive
                          ? 'border-cyan-200/35 bg-cyan-200/15 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12)]'
                          : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06] hover:text-text-secondary'
                      }`}
                    >
                      <span className="block text-[10px] font-semibold text-cyan-100/70">
                        {index + 1} · {count}
                      </span>
                      {stageDockLabels[stage]}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <aside className="order-3 border-t border-white/10 bg-black/30 p-4 backdrop-blur-2xl lg:overflow-y-auto lg:border-t-0 lg:border-l">
          <article
            key={selectedTool.id}
            className="tool-detail-card rounded-xl border border-white/12 bg-white/[0.06] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.1)]"
          >
            <div className="flex items-start gap-3">
              <ToolLogo tool={selectedTool} size={64} />
              <div className="min-w-0 flex-1">
                <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-text-muted">
                  Selected service
                </p>
                <h2 className="mt-1 truncate text-2xl font-semibold text-white">{selectedTool.name}</h2>
                <div className="mt-2 flex flex-wrap gap-1.5">
                  <span
                    className="rounded-full px-2.5 py-1 text-[11px] font-semibold text-black"
                    style={{ backgroundColor: selectedCategory.color }}
                  >
                    {selectedCategory.shortName}
                  </span>
                  <span className="rounded-full border border-white/10 bg-white/[0.06] px-2.5 py-1 text-[11px] text-text-secondary">
                    {stageDockLabels[selectedTool.stage]}
                  </span>
                </div>
              </div>
            </div>

            <div className="mt-4 grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={recenterSelectedTool}
                className="inline-flex items-center justify-center gap-2 rounded-lg border border-cyan-200/20 bg-cyan-200/[0.08] px-3 py-2 text-sm font-semibold text-cyan-50 transition hover:bg-cyan-200/[0.14]"
              >
                <RotateCcw className="h-4 w-4" />
                Recenter
              </button>
              {selectedTool.url ? (
                <a
                  href={selectedTool.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/[0.06] px-3 py-2 text-sm font-semibold text-text-secondary transition hover:bg-white/10 hover:text-white"
                >
                  <Globe className="h-4 w-4" />
                  Open
                </a>
              ) : (
                <div className="rounded-lg border border-white/10 bg-white/[0.035] px-3 py-2 text-center text-sm text-text-muted">
                  Local node
                </div>
              )}
            </div>

            <section className="mt-4 rounded-lg border border-white/10 bg-black/20 p-3">
              <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-text-muted">
                What it does
              </p>
              <p className="mt-2 text-sm leading-6 text-text-secondary">{selectedTool.summary}</p>
            </section>

            <section className="mt-3 rounded-lg border border-cyan-200/15 bg-cyan-200/[0.045] p-3">
              <div className="flex items-center justify-between gap-3">
                <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-cyan-100/75">
                  Workflow
                </p>
                <span className="text-[11px] text-text-muted">
                  {selectedStageIndex + 1}/{orderedStages.length}
                </span>
              </div>
              <p className="mt-2 text-sm leading-6 text-cyan-50/80">{stageActions[selectedTool.stage]}</p>
              <div className="mt-3 grid grid-cols-5 gap-1">
                {orderedStages.map((stage, index) => {
                  const isCurrent = selectedTool.stage === stage;
                  return (
                    <button
                      key={stage}
                      type="button"
                      aria-current={isCurrent ? 'step' : undefined}
                      onClick={() => setActiveStage(stage)}
                      title={workflowStages[stage].description}
                      className={`min-h-11 rounded-md border px-1.5 py-1.5 text-left transition ${
                        isCurrent
                          ? 'border-cyan-200/40 bg-cyan-200/15 text-white'
                          : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06] hover:text-text-secondary'
                      }`}
                    >
                      <span className="block text-[10px] font-semibold text-cyan-100/70">{index + 1}</span>
                      <span className="mt-0.5 block truncate text-[11px]">{stageDockLabels[stage]}</span>
                    </button>
                  );
                })}
              </div>
            </section>

            <section className="mt-3 rounded-lg border border-fuchsia-200/15 bg-fuchsia-200/[0.055] p-3">
              <div className="flex items-center justify-between gap-3">
                <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-fuchsia-100/75">
                  Relationship lens
                </p>
                <span className="rounded-full bg-white/10 px-2 py-1 text-[11px] text-fuchsia-50/85">
                  {relationLensCounts.get(relationLens) ?? 0}
                </span>
              </div>
              <div className="mt-3 grid grid-cols-2 gap-1.5">
                {relationLensOptions.map((option) => {
                  const isActive = relationLens === option.id;
                  return (
                    <button
                      key={option.id}
                      type="button"
                      onClick={() => setRelationLens(option.id)}
                      title={option.description}
                      className={`rounded-lg border px-2 py-2 text-left text-xs transition ${
                        isActive
                          ? 'border-fuchsia-200/35 bg-fuchsia-200/14 text-white'
                          : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06] hover:text-text-secondary'
                      }`}
                    >
                      <span className="block text-[10px] text-fuchsia-100/70">
                        {relationLensCounts.get(option.id) ?? 0}
                      </span>
                      {option.shortLabel}
                    </button>
                  );
                })}
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                {lensTools.length > 0 ? (
                  lensTools.slice(0, 7).map((tool) => (
                    <button
                      key={tool.id}
                      type="button"
                      onClick={() => focusTool(tool)}
                      className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1.5 text-xs text-text-secondary transition hover:bg-white/10 hover:text-white"
                    >
                      <ToolLogo tool={tool} size={20} />
                      {tool.name}
                    </button>
                  ))
                ) : (
                  <span className="text-sm text-text-muted">No visible tools in this lens yet.</span>
                )}
              </div>
            </section>

            <section className="mt-3 rounded-lg border border-white/10 bg-black/20 p-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-text-muted">
                    Cluster inspector
                  </p>
                  <p className="mt-1 text-sm font-semibold text-white">{activeClusterCategory.name}</p>
                </div>
                <span className="shrink-0 rounded-full border border-white/10 bg-white/[0.05] px-2 py-1 text-[11px] text-text-muted">
                  {clusterTools.length} tools
                </span>
              </div>
              <div className="mt-3 grid grid-cols-5 gap-1">
                {orderedStages.map((stage, index) => {
                  const count = clusterStageCounts.get(stage) ?? 0;
                  const isActive = activeStage === stage;
                  return (
                    <button
                      key={stage}
                      type="button"
                      onClick={() => {
                        setActiveCategory(activeClusterCategory.id);
                        setActiveStage(stage);
                        setRelationLens('stage');
                        setMapClarity('context');
                      }}
                      className={`min-h-10 rounded-md border px-1.5 py-1.5 text-left transition ${
                        isActive
                          ? 'border-cyan-200/35 bg-cyan-200/15 text-white'
                          : 'border-white/10 bg-white/[0.035] text-text-muted hover:bg-white/[0.07] hover:text-text-secondary'
                      }`}
                      title={workflowStages[stage].name}
                    >
                      <span className="block text-[10px] font-semibold text-cyan-100/70">{index + 1}</span>
                      <span className="mt-0.5 block text-[11px]">{count}</span>
                    </button>
                  );
                })}
              </div>
              <div className="mt-3 grid gap-1.5">
                {clusterTools.slice(0, 6).map((tool) => {
                  const isActive = tool.id === selectedTool.id;
                  return (
                    <button
                      key={tool.id}
                      type="button"
                      onClick={() => focusTool(tool)}
                      className={`flex items-center gap-2 rounded-lg border px-2 py-2 text-left transition ${
                        isActive
                          ? 'border-white/25 bg-white/[0.09] text-white'
                          : 'border-white/10 bg-white/[0.035] text-text-secondary hover:bg-white/[0.075] hover:text-white'
                      }`}
                    >
                      <ToolLogo tool={tool} size={24} />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-xs font-semibold">{tool.name}</span>
                        <span className="mt-0.5 block truncate text-[11px] text-text-muted">
                          {stageDockLabels[tool.stage]} · {tool.relationIds.length} links
                        </span>
                      </span>
                    </button>
                  );
                })}
              </div>
            </section>

            {selectedTool.classification && (
              <section className="mt-3 rounded-lg border border-white/10 bg-black/20 p-3">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-text-muted">Classifier confidence</span>
                  <span className="font-semibold text-cyan-100">
                    {Math.round(selectedTool.classification.confidence * 100)}%
                  </span>
                </div>
              </section>
            )}
          </article>
        </aside>
      </main>
    </div>
  );
};
