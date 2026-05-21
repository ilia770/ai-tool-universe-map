import { FormEvent, lazy, Suspense, useEffect, useMemo, useState } from 'react';
import { Brain, Check, Filter, Globe, Link2, RotateCcw, Search, Sparkles, X, Zap } from 'lucide-react';
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

const AIToolUniverse3D = lazy(() =>
  import('./AIToolUniverse3D').then((m) => ({ default: m.Scene })),
);

interface AIToolUniverseMapProps {
  onClose: () => void;
}

const CUSTOM_TOOLS_STORAGE_KEY = 'ai-tool-universe.custom-tools.v1';
const orderedStages: WorkflowStageId[] = ['research', 'planning', 'execution', 'approval', 'review'];
const stageDockLabels: Record<WorkflowStageId, string> = {
  research: 'Research',
  planning: 'Plan',
  execution: 'Build',
  approval: 'Approve',
  review: 'Review',
};

const readStoredCustomTools = (): AITool[] => {
  if (typeof window === 'undefined') return [];

  try {
    const raw = window.localStorage.getItem(CUSTOM_TOOLS_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

export const AIToolUniverseMap = ({ onClose }: AIToolUniverseMapProps) => {
  const [selectedId, setSelectedId] = useState('founder-os');
  const [query, setQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState<ToolCategoryId | 'all'>('all');
  const [activeStage, setActiveStage] = useState<WorkflowStageId | 'all'>('all');
  const [toolInput, setToolInput] = useState('');
  const [customTools, setCustomTools] = useState<AITool[]>(readStoredCustomTools);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [onClose]);

  useEffect(() => {
    window.localStorage.setItem(CUSTOM_TOOLS_STORAGE_KEY, JSON.stringify(customTools));
  }, [customTools]);

  const allTools = useMemo(() => [...tools, ...customTools], [customTools]);
  const nodeById = useMemo(() => new Map(allTools.map((tool) => [tool.id, tool])), [allTools]);
  const selectedTool = nodeById.get(selectedId) ?? allTools[0];
  const selectedCategory = categoryById.get(selectedTool.category) ?? categories[0];
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

  const handleAddTool = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const value = toolInput.trim();
    if (!value) return;

    const classification = classifyToolDetailed(value);
    const category = classification.category;
    const categoryMeta = categoryById.get(category) ?? categories[0];
    const siblingCount = allTools.filter((tool) => tool.category === category).length;
    const displayName = getDisplayName(value);
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
      url: value.startsWith('http') ? value : undefined,
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
    setToolInput('');
  };

  return (
    <div
      className="fixed inset-0 z-[80] overflow-hidden bg-[#03040a] text-text-primary"
      role="dialog"
      aria-modal="true"
      aria-label="AI Tool Universe Map"
      data-testid="ai-tool-universe-map"
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
            className="flex h-9 w-9 items-center justify-center rounded-md border border-white/10 bg-white/5 text-text-secondary transition-colors hover:bg-white/10 hover:text-white"
            title="Close map"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      </header>

      <main className="relative z-10 grid h-[calc(100dvh-4rem)] grid-cols-1 overflow-y-auto lg:grid-cols-[280px_minmax(0,1fr)_340px] lg:overflow-hidden">
        <aside className="order-2 border-t border-white/10 bg-black/20 p-4 backdrop-blur-xl lg:order-1 lg:border-t-0 lg:border-r">
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
                onChange={(event) => setToolInput(event.target.value)}
                placeholder="Tool name or URL"
                className="min-w-0 flex-1 rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none transition focus:border-cyan-300/50 focus:ring-2 focus:ring-cyan-300/20"
              />
              <button
                type="submit"
                className="flex h-9 w-9 items-center justify-center rounded-lg bg-cyan-300 text-slate-950 transition hover:bg-cyan-200"
                title="Classify tool"
              >
                <Check className="h-4 w-4" />
              </button>
            </div>
            <p className="mt-2 text-xs leading-relaxed text-text-secondary">
              Rule-based draft classifier. Later it can become an AI classifier with persisted relations.
            </p>
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
          </div>

          <div className="mt-4 space-y-2">
            <button
              onClick={() => setActiveCategory('all')}
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
              const count = allTools.filter((tool) => tool.category === category.id).length;
              return (
                <button
                  key={category.id}
                  onClick={() => setActiveCategory(category.id)}
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
            <button
              type="button"
              onClick={() => {
                setCustomTools([]);
                setSelectedId('founder-os');
                setActiveCategory('all');
                setActiveStage('all');
              }}
              className="mt-4 flex w-full items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-xs text-text-muted transition hover:bg-white/10 hover:text-white"
            >
              <RotateCcw className="h-3.5 w-3.5" />
              Reset custom tools
            </button>
          )}
        </aside>

        <section className="order-1 relative min-h-[520px] overflow-hidden md:min-h-[640px] lg:order-2 lg:h-[calc(100dvh-4rem)] lg:min-h-0">
          <Suspense fallback={
            <div className="absolute inset-0 flex items-center justify-center bg-[#020008]">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-cyan-300/30 border-t-cyan-300" />
            </div>
          }>
            <AIToolUniverse3D
              selectedId={selectedId}
              onSelectId={setSelectedId}
              activeCategory={activeCategory}
              activeStage={activeStage}
              query={query}
              customTools={customTools}
              onSelectCategory={setActiveCategory}
            />
          </Suspense>

          <div className="pointer-events-none absolute inset-x-3 bottom-3 z-20 md:inset-x-5 md:bottom-4">
            <div className="pointer-events-auto mx-auto max-w-5xl rounded-2xl border border-white/15 bg-[#050814]/76 p-2.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_22px_80px_rgba(0,0,0,0.45)] backdrop-blur-2xl">
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-cyan-100/75">
                    Universe controls
                  </p>
                  <p className="text-xs text-text-muted">
                    Switch group focus, then narrow by workflow stage.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setActiveCategory('all');
                    setActiveStage('all');
                    setSelectedId('founder-os');
                  }}
                  className="hidden rounded-lg border border-white/10 bg-white/[0.05] px-3 py-2 text-xs text-text-secondary transition hover:bg-white/10 hover:text-white md:block"
                >
                  Reset view
                </button>
              </div>

              <div className="mt-2 flex gap-2 overflow-x-auto pb-1">
                <button
                  type="button"
                  onClick={() => setActiveCategory('all')}
                  className={`shrink-0 rounded-full border px-3 py-2 text-xs transition ${
                    activeCategory === 'all'
                      ? 'border-white/30 bg-white/15 text-white'
                      : 'border-white/10 bg-white/[0.04] text-text-secondary hover:bg-white/10'
                  }`}
                >
                  All groups
                </button>
                {categories.filter((category) => category.id !== 'core').map((category) => {
                  const count = allTools.filter((tool) => tool.category === category.id).length;
                  const isActive = activeCategory === category.id;
                  return (
                    <button
                      key={category.id}
                      type="button"
                      onClick={() => setActiveCategory(category.id)}
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
                  const count = allTools.filter((tool) => tool.stage === stage).length;
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

        <aside className="order-3 border-t border-white/10 bg-black/30 p-4 backdrop-blur-2xl lg:border-t-0 lg:border-l">
          <div className="rounded-xl border border-white/12 bg-white/[0.06] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.1)]">
            <div className="mb-3 flex items-start justify-between gap-3">
              <div>
                <p className="text-xs uppercase text-text-muted">{selectedCategory.name}</p>
                <h2 className="mt-1 text-xl font-semibold text-white">{selectedTool.name}</h2>
              </div>
              <span
                className="rounded-full px-2.5 py-1 text-xs font-medium text-black"
                style={{ backgroundColor: selectedCategory.color }}
              >
                {workflowStages[selectedTool.stage].name}
              </span>
            </div>
            <p className="text-sm leading-6 text-text-secondary">{selectedTool.summary}</p>
            {selectedTool.url && (
              <a
                href={selectedTool.url}
                target="_blank"
                rel="noopener noreferrer"
                className="mt-4 inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-cyan-100 transition hover:bg-white/10"
              >
                <Globe className="h-4 w-4" />
                Open link
              </a>
            )}
            {selectedTool.classification && (
              <div className="mt-4 rounded-lg border border-white/10 bg-black/20 p-3">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-text-muted">Classifier confidence</span>
                  <span className="font-semibold text-cyan-100">
                    {Math.round(selectedTool.classification.confidence * 100)}%
                  </span>
                </div>
                {selectedTool.classification.matchedKeywords.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {selectedTool.classification.matchedKeywords.map((keyword) => (
                      <span
                        key={keyword}
                        className="rounded-full border border-white/10 bg-white/[0.06] px-2 py-1 text-[11px] text-text-secondary"
                      >
                        {keyword}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="mt-4 rounded-xl border border-white/10 bg-black/25 p-4">
            <h3 className="mb-3 text-sm font-semibold text-white">Why this category exists</h3>
            <p className="text-sm leading-6 text-text-secondary">{selectedCategory.description}</p>
          </div>

          <div className="mt-4 rounded-xl border border-white/10 bg-black/25 p-4">
            <h3 className="mb-3 text-sm font-semibold text-white">Workflow role</h3>
            <p className="text-sm leading-6 text-text-secondary">
              {workflowStages[selectedTool.stage].description}
            </p>
          </div>

          <div className="mt-4 rounded-xl border border-white/10 bg-black/25 p-4">
            <h3 className="mb-3 text-sm font-semibold text-white">Direct network</h3>
            <div className="flex flex-wrap gap-2">
              {directConnectedTools.length > 0 ? (
                directConnectedTools.map((tool) => (
                  <button
                    key={tool.id}
                    onClick={() => setSelectedId(tool.id)}
                    className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-text-secondary transition hover:bg-white/10 hover:text-white"
                  >
                    {tool.name}
                  </button>
                ))
              ) : (
                <span className="text-sm text-text-muted">No direct relations yet.</span>
              )}
            </div>
            {adjacentConnectedTools.length > 0 && (
              <>
                <h4 className="mt-4 text-xs font-semibold uppercase tracking-[0.16em] text-text-muted">
                  Adjacent orbit
                </h4>
                <div className="mt-2 flex flex-wrap gap-2">
                  {adjacentConnectedTools.map((tool) => (
                    <button
                      key={tool.id}
                      onClick={() => setSelectedId(tool.id)}
                      className="rounded-full border border-white/10 bg-black/20 px-3 py-1.5 text-xs text-text-muted transition hover:bg-white/10 hover:text-white"
                    >
                      {tool.name}
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>

          <div className="mt-4 rounded-xl border border-cyan-300/15 bg-cyan-300/[0.05] p-4">
            <h3 className="mb-3 text-sm font-semibold text-cyan-100">Vibe-coding component loop</h3>
            <div className="grid grid-cols-5 gap-1.5">
              {orderedStages.map((stage, index) => {
                const isActive = activeStage === stage || (activeStage === 'all' && selectedTool.stage === stage);
                return (
                  <button
                    key={stage}
                    type="button"
                    className={`min-h-16 rounded-lg border px-2 py-2 text-left transition ${
                      isActive
                        ? 'border-cyan-200/40 bg-cyan-200/15 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12)]'
                        : 'border-white/10 bg-black/20 text-text-muted hover:bg-white/[0.06] hover:text-text-secondary'
                    }`}
                    onClick={() => setActiveStage(stage)}
                    title={workflowStages[stage].description}
                  >
                    <span className="block text-[10px] font-semibold text-cyan-100/80">{index + 1}</span>
                    <span className="mt-1 block text-[11px] leading-4">{stageDockLabels[stage]}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </aside>
      </main>
    </div>
  );
};
