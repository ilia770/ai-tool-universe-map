import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { Html } from '@react-three/drei';
import { tools, categories, workflowLinks, categoryById } from '../../data/ai-tool-universe';
import type { ToolCategoryId, WorkflowStageId, AITool } from '../../data/ai-tool-universe';
import { StarField } from './StarField';
import { FounderOSNode } from './FounderOSNode';
import { GalaxyDust } from './GalaxyDust';
import { CategoryRing } from './CategoryRing';
import { ToolNode } from './ToolNode';
import { ConnectionLines } from './ConnectionLines';
import { CameraController } from './CameraController';
import { PocketWorldShell } from './PocketWorldShell';
import { ProximityCategoryWatcher } from './ProximityCategoryWatcher';
import { categoryPosition, pocketToolPosition, toolPosition } from './layout';
import { buildLensRelevantIds, buildRelationDepthMap, type RelationLens } from './relations';

type MapClarityMode = 'focus' | 'context' | 'atlas';

interface SceneProps {
  selectedId: string;
  onSelectId: (id: string) => void;
  activeCategory: ToolCategoryId | 'all';
  activeStage: WorkflowStageId | 'all';
  query: string;
  customTools: AITool[];
  relationLens: RelationLens;
  mapClarity: MapClarityMode;
  cameraVersion: number;
  onSelectCategory: (category: ToolCategoryId | 'all') => void;
}

export function Scene({
  selectedId,
  onSelectId,
  activeCategory,
  activeStage,
  query,
  customTools,
  relationLens,
  mapClarity,
  cameraVersion,
  onSelectCategory,
}: SceneProps) {
  const [hoveredCategory, setHoveredCategory] = useState<ToolCategoryId | null>(null);
  const [hoveredToolId, setHoveredToolId] = useState<string | null>(null);
  const [contextLost, setContextLost] = useState(false);
  // Defer heavy ambient layers (StarField, GalaxyDust) until the browser is
  // idle. The main scene paints first; ambient cosmos slides in ~one frame
  // later. Saves ~1-2 s of initial TBT without losing the look.
  const [ambientReady, setAmbientReady] = useState(false);
  useEffect(() => {
    const ric = (window as Window & {
      requestIdleCallback?: (cb: () => void, opts?: { timeout: number }) => number;
      cancelIdleCallback?: (handle: number) => void;
    });
    if (typeof ric.requestIdleCallback === 'function') {
      const handle = ric.requestIdleCallback(() => setAmbientReady(true), { timeout: 600 });
      return () => ric.cancelIdleCallback?.(handle);
    }
    const handle = window.setTimeout(() => setAmbientReady(true), 220);
    return () => window.clearTimeout(handle);
  }, []);
  const hoverClearTimeoutRef = useRef<number | null>(null);
  const toolHoverClearTimeoutRef = useRef<number | null>(null);
  const toolHoverRafRef = useRef<number | null>(null);
  const contextListenerCleanupRef = useRef<(() => void) | null>(null);
  const allTools = useMemo(() => [...tools, ...customTools], [customTools]);

  const handleCanvasCreated = useCallback(({ gl }: { gl: { domElement: HTMLCanvasElement } }) => {
    const canvas = gl.domElement;
    contextListenerCleanupRef.current?.();

    // preventDefault on contextlost is required for the browser to fire a
    // matching contextrestored. Without this overlay the canvas would just go
    // black on a GPU reset with no signal to the user.
    const handleContextLost = (event: Event) => {
      event.preventDefault();
      setContextLost(true);
    };
    const handleContextRestored = () => setContextLost(false);

    canvas.addEventListener('webglcontextlost', handleContextLost);
    canvas.addEventListener('webglcontextrestored', handleContextRestored);
    contextListenerCleanupRef.current = () => {
      canvas.removeEventListener('webglcontextlost', handleContextLost);
      canvas.removeEventListener('webglcontextrestored', handleContextRestored);
    };
  }, []);

  const handleCategoryHover = useCallback((category: ToolCategoryId | null) => {
    if (hoverClearTimeoutRef.current !== null) {
      window.clearTimeout(hoverClearTimeoutRef.current);
      hoverClearTimeoutRef.current = null;
    }

    if (category) {
      setHoveredCategory(category);
      return;
    }

    hoverClearTimeoutRef.current = window.setTimeout(() => {
      setHoveredCategory(null);
      hoverClearTimeoutRef.current = null;
    }, 280);
  }, []);

  const handleToolHover = useCallback((id: string | null) => {
    if (id === null) {
      // Hover-out: cancel any pending hover-in, then debounce the clear so a
      // brief gap while crossing between two adjacent nodes doesn't flicker
      // focus off.
      if (toolHoverRafRef.current !== null) {
        window.cancelAnimationFrame(toolHoverRafRef.current);
        toolHoverRafRef.current = null;
      }
      if (toolHoverClearTimeoutRef.current !== null) {
        window.clearTimeout(toolHoverClearTimeoutRef.current);
      }
      toolHoverClearTimeoutRef.current = window.setTimeout(() => {
        setHoveredToolId(null);
        toolHoverClearTimeoutRef.current = null;
      }, 320);
      return;
    }

    // Hover-in: coalesce to one commit per frame. A fast pointer sweep fires a
    // pointerover per node crossed; without this, each one would invalidate the
    // relation/lens/label memos. Collapsing to the last node in the frame means
    // only the node the pointer settles on triggers the heavy recompute.
    if (toolHoverClearTimeoutRef.current !== null) {
      window.clearTimeout(toolHoverClearTimeoutRef.current);
      toolHoverClearTimeoutRef.current = null;
    }
    if (toolHoverRafRef.current !== null) {
      window.cancelAnimationFrame(toolHoverRafRef.current);
    }
    toolHoverRafRef.current = window.requestAnimationFrame(() => {
      toolHoverRafRef.current = null;
      setHoveredToolId(id);
    });
  }, []);

  useEffect(() => () => {
    if (hoverClearTimeoutRef.current !== null) {
      window.clearTimeout(hoverClearTimeoutRef.current);
    }
    if (toolHoverClearTimeoutRef.current !== null) {
      window.clearTimeout(toolHoverClearTimeoutRef.current);
    }
    if (toolHoverRafRef.current !== null) {
      window.cancelAnimationFrame(toolHoverRafRef.current);
    }
    contextListenerCleanupRef.current?.();
    contextListenerCleanupRef.current = null;
  }, []);

  const selectedTool = allTools.find((t) => t.id === selectedId);
  const activeFocusId = hoveredToolId ?? selectedId;
  const activeFocusTool = allTools.find((t) => t.id === activeFocusId);
  const activeFocusCategory = activeFocusTool?.category ?? null;
  const isToolFocusMode = Boolean(hoveredToolId);
  const lensCategory = relationLens === 'category' && activeFocusCategory && activeFocusCategory !== 'core'
    ? activeFocusCategory
    : null;
  const selectedToolCategory = selectedTool && selectedTool.category !== 'core'
    ? selectedTool.category
    : null;
  const focusedCategory: ToolCategoryId | null = hoveredCategory ?? (activeCategory !== 'all' ? activeCategory : lensCategory);
  const pocketCategory = activeCategory !== 'all' && activeCategory !== 'core'
    ? activeCategory
    : selectedToolCategory;
  const pocketCategoryMeta = pocketCategory ? categoryById.get(pocketCategory) ?? null : null;
  const pocketToolCount = useMemo(
    () => (pocketCategory ? allTools.filter((tool) => tool.category === pocketCategory).length : 0),
    [allTools, pocketCategory],
  );
  const pocketCenterPosition = useMemo<[number, number, number] | null>(
    () => (pocketCategoryMeta ? categoryPosition(pocketCategoryMeta.angle) : null),
    [pocketCategoryMeta],
  );
  const categoryAnchors = useMemo(
    () =>
      categories
        .filter((c) => c.id !== 'core')
        .map((c) => ({ id: c.id, position: categoryPosition(c.angle) as [number, number, number] })),
    [],
  );
  const pocketSlotById = useMemo(() => {
    const map = new Map<string, number>();
    if (!pocketCategory) return map;

    allTools
      .filter((tool) => tool.category === pocketCategory && tool.id !== 'founder-os')
      .sort((a, b) => a.orbit - b.orbit || a.angle - b.angle || a.name.localeCompare(b.name))
      .forEach((tool, index) => map.set(tool.id, index));

    return map;
  }, [allTools, pocketCategory]);
  const pocketSlotCount = pocketSlotById.size;
  const positionById = useMemo(() => {
    const map = new Map<string, [number, number, number]>();
    allTools.forEach((tool) => {
      const cat = categoryById.get(tool.category);
      if (!cat) return;
      const pocketSlotIndex = pocketSlotById.get(tool.id);
      map.set(
        tool.id,
        pocketCategory === tool.category && pocketSlotIndex !== undefined
          ? pocketToolPosition(tool.angle, tool.orbit, cat.angle, pocketSlotIndex, pocketSlotCount)
          : toolPosition(tool.angle, tool.orbit, cat.angle),
      );
    });
    return map;
  }, [allTools, pocketCategory, pocketSlotById, pocketSlotCount]);
  const toolCategoryById = useMemo(
    () => new Map(allTools.map((tool) => [tool.id, tool.category])),
    [allTools],
  );
  const toolStageById = useMemo(
    () => new Map(allTools.map((tool) => [tool.id, tool.stage])),
    [allTools],
  );
  const relationDepthById = useMemo(
    () => buildRelationDepthMap(activeFocusId, allTools),
    [activeFocusId, allTools],
  );

  const lensRelevantIds = useMemo(
    () => buildLensRelevantIds(activeFocusId, allTools, relationLens, relationDepthById),
    [activeFocusId, allTools, relationDepthById, relationLens],
  );

  const normalizedQuery = query.trim().toLowerCase();
  const visibleIds = useMemo(() => new Set(
    allTools
      .filter((t) => {
        const matchCat = activeCategory === 'all' || t.category === activeCategory;
        const matchStage = activeStage === 'all' || t.stage === activeStage;
        const matchQ = !normalizedQuery
          || t.name.toLowerCase().includes(normalizedQuery)
          || t.summary.toLowerCase().includes(normalizedQuery);
        return matchCat && matchStage && matchQ;
      })
      .map((t) => t.id),
  ), [allTools, activeCategory, activeStage, normalizedQuery]);
  const relationDegreeById = useMemo(() => {
    const map = new Map<string, number>();

    allTools.forEach((tool) => {
      map.set(tool.id, (map.get(tool.id) ?? 0) + tool.relationIds.length);
      tool.relationIds.forEach((id) => {
        map.set(id, (map.get(id) ?? 0) + 1);
      });
    });

    return map;
  }, [allTools]);
  const labelBudgetIds = (() => {
    const baseBudget = isToolFocusMode
      ? 9
      : mapClarity === 'focus'
        ? 8
        : mapClarity === 'context'
          ? 13
          : 18;
    const budget = pocketCategory ? Math.min(26, baseBudget + (mapClarity === 'focus' ? 5 : 9)) : baseBudget;

    const scored = allTools
      .filter((tool) => tool.id !== 'founder-os')
      .map((tool) => {
        const relationDepth = relationDepthById.get(tool.id);
        const inLens = lensRelevantIds.has(tool.id);
        let score = 0;

        if (tool.id === selectedId || tool.id === hoveredToolId) score += 1000;
        if (relationDepth === 0) score += 160;
        if (relationDepth === 1) score += 86;
        if (relationDepth === 2) score += 38;
        if (inLens) score += 44;
        if (focusedCategory && tool.category === focusedCategory) score += 42;
        if (pocketCategory && tool.category === pocketCategory) score += 120;
        if (activeCategory !== 'all' && tool.category === activeCategory) score += 28;
        if (tool.orbit === 1) score += 30;
        if (tool.orbit === 2) score += 14;
        score += Math.min(relationDegreeById.get(tool.id) ?? 0, 8) * 3;

        if (mapClarity === 'focus' && selectedId !== 'founder-os' && !inLens) score -= 120;
        if (mapClarity === 'context' && focusedCategory && tool.category !== focusedCategory && !inLens) score -= 80;
        if (normalizedQuery && !visibleIds.has(tool.id)) score -= 240;

        return { id: tool.id, name: tool.name, orbit: tool.orbit, score };
      })
      .filter((item) => item.score > 0)
      .sort((a, b) => b.score - a.score || a.orbit - b.orbit || a.name.localeCompare(b.name));

    return new Set(scored.slice(0, budget).map((item) => item.id));
  })();

  const cameraTargetPosition = useMemo<[number, number, number]>(() => {
    if (selectedId === 'founder-os') return [0, 0, 0];
    if (pocketCenterPosition && activeCategory === pocketCategory) return pocketCenterPosition;
    return positionById.get(selectedId) ?? [0, 0, 0];
  }, [activeCategory, pocketCategory, pocketCenterPosition, positionById, selectedId]);
  const cameraViewMode = selectedId === 'founder-os' ? 'overview' : pocketCategory ? 'pocket' : 'node';
  const hoverReadout = hoveredToolId && activeFocusTool
    ? {
        title: activeFocusTool.name,
        eyebrow: categoryById.get(activeFocusTool.category)?.name ?? 'Unknown group',
        meta: relationDepthById.size > 1
          ? `${Math.max(relationDepthById.size - 1, 0)} connected nodes in focus`
          : 'Click to inspect this service',
        color: categoryById.get(activeFocusTool.category)?.color ?? '#9be8ff',
      }
    : hoveredCategory
      ? {
          title: categoryById.get(hoveredCategory)?.name ?? 'Tool group',
          eyebrow: 'Pocket world',
          meta: 'Click to open this cluster as a roomier mini-system.',
          color: categoryById.get(hoveredCategory)?.color ?? '#9be8ff',
      }
      : null;

  const shouldShowToolLabel = useCallback((tool: AITool, relationDepth: number | undefined, inLens: boolean) => {
    if (tool.id === hoveredToolId) return true;
    if (!isToolFocusMode && tool.id === selectedId) return true;
    if (!labelBudgetIds.has(tool.id)) return false;

    if (pocketCategory && tool.category === pocketCategory) {
      if (mapClarity === 'focus') {
        return tool.orbit <= 2 || inLens || (relationDepth ?? 99) <= 1;
      }
      return tool.orbit <= 3 || inLens;
    }

    if (isToolFocusMode) {
      return (relationDepth ?? 99) <= 1;
    }

    if (mapClarity === 'focus') {
      return selectedId !== 'founder-os' && inLens && (relationDepth ?? 99) <= 1;
    }

    if (mapClarity === 'context') {
      const inCategoryContext = focusedCategory === tool.category && (tool.orbit <= 1 || (relationDepth ?? 99) <= 1);
      const inSelectedContext = selectedId !== 'founder-os' && inLens && (relationDepth ?? 99) <= 1;
      return inCategoryContext || inSelectedContext;
    }

    if (focusedCategory) return tool.category === focusedCategory && tool.orbit <= 2;
    return tool.orbit <= 1 || (selectedId !== 'founder-os' && inLens && (relationDepth ?? 99) <= 2);
  }, [focusedCategory, hoveredToolId, isToolFocusMode, labelBudgetIds, mapClarity, pocketCategory, selectedId]);

  const shouldDimTool = useCallback((tool: AITool, relationDepth: number | undefined, inLens: boolean) => {
    if (!visibleIds.has(tool.id)) return true;

    if (pocketCategory && tool.category !== pocketCategory && !inLens) return true;

    if (isToolFocusMode) {
      return (relationDepth ?? 99) > 1 && tool.id !== activeFocusId;
    }

    if (mapClarity === 'focus') {
      return selectedId !== 'founder-os' && !inLens;
    }

    if (mapClarity === 'context') {
      return (selectedId !== 'founder-os' && !inLens)
        || (Boolean(focusedCategory) && tool.category !== focusedCategory);
    }

    return Boolean(focusedCategory) && activeCategory !== 'all' && tool.category !== focusedCategory;
  }, [activeCategory, activeFocusId, focusedCategory, isToolFocusMode, mapClarity, pocketCategory, selectedId, visibleIds]);

  const allLinks = useMemo(() => {
    const wlKeys = new Set(
      workflowLinks.flatMap((wl) => [`${wl.source}>${wl.target}`, `${wl.target}>${wl.source}`]),
    );
    return [
      ...workflowLinks,
      ...allTools.flatMap((t) =>
        t.relationIds
          .filter((target) => !wlKeys.has(`${t.id}>${target}`))
          .map((target) => ({ source: t.id, target, strength: 'secondary' as const, label: '' })),
      ),
    ];
  }, [allTools]);

  return (
    <>
    <Canvas
      camera={{ position: [0, 5.4, 20.5], fov: 58 }}
      dpr={[1, 1.5]}
      frameloop="always"
      gl={{ alpha: true, antialias: true, toneMapping: 0 }}
      style={{ background: 'transparent', width: '100%', height: '100%' }}
      onCreated={handleCanvasCreated}
    >
      <fog attach="fog" args={['#020008', 18, 46]} />
      <ambientLight intensity={0.15} />
      <pointLight position={[0, 4, 8]} intensity={0.85} color="#9be8ff" />
      <pointLight position={[-7, -2, -4]} intensity={0.35} color="#ff8bd2" />
      {ambientReady && (
        <>
          <StarField />
          <GalaxyDust />
        </>
      )}
      <CameraController
        targetKey={`${selectedId}:${pocketCategory ?? 'none'}:${cameraVersion}:${cameraViewMode}`}
        targetPosition={cameraTargetPosition}
        viewMode={cameraViewMode}
      />
      <ProximityCategoryWatcher
        anchors={categoryAnchors}
        activeCategory={activeCategory}
        enterDistance={11}
        exitDistance={22}
        cooldownMs={1400}
        onEnter={onSelectCategory}
        onExit={() => onSelectCategory('all')}
      />

      <Html fullscreen zIndexRange={[90, 70]} style={{ pointerEvents: 'none' }}>
        <div className={`universe-focus-readout ${hoverReadout ? 'is-visible' : ''}`}>
          {hoverReadout && (
            <>
              <span className="universe-focus-readout__dot" style={{ backgroundColor: hoverReadout.color }} />
              <span className="universe-focus-readout__eyebrow">{hoverReadout.eyebrow}</span>
              <strong>{hoverReadout.title}</strong>
              <span className="universe-focus-readout__meta">{hoverReadout.meta}</span>
            </>
          )}
        </div>
      </Html>

      <FounderOSNode
        selected={selectedId === 'founder-os'}
        onSelect={() => onSelectId('founder-os')}
      />

      {pocketCategoryMeta && pocketCenterPosition && (
        <PocketWorldShell
          category={pocketCategoryMeta}
          position={pocketCenterPosition}
          toolCount={pocketToolCount}
        />
      )}

      {categories.filter((c) => c.id !== 'core').map((cat) => (
        (() => {
          const active = mapClarity === 'focus'
            ? activeCategory === cat.id || hoveredCategory === cat.id || lensCategory === cat.id
            : activeCategory === 'all' || activeCategory === cat.id || hoveredCategory === cat.id || lensCategory === cat.id;
          const labelVisible = !isToolFocusMode && (
            mapClarity === 'atlas'
            || hoveredCategory === cat.id
            || activeCategory === cat.id
            || (mapClarity === 'context' && activeCategory === 'all')
          );

          return (
            <CategoryRing
              key={cat.id}
              category={cat}
              position={categoryPosition(cat.angle)}
              active={active}
              hovered={hoveredCategory === cat.id}
              pocketActive={pocketCategory === cat.id}
              labelVisible={labelVisible}
              onSelect={onSelectCategory}
              onHover={handleCategoryHover}
            />
          );
        })()
      ))}

      {allTools.filter((t) => t.id !== 'founder-os').map((tool) => {
        const pos = positionById.get(tool.id);
        const cat = categoryById.get(tool.category);
        if (!pos || !cat) return null;
        const relationDepth = relationDepthById.get(tool.id);
        const inLens = lensRelevantIds.has(tool.id);
        const dimmed = shouldDimTool(tool, relationDepth, inLens);
        return (
          <ToolNode
            key={tool.id}
            id={tool.id}
            name={tool.name}
            tool={tool}
            position={pos}
            color={cat.color}
            glow={cat.glow}
            selected={tool.id === selectedId}
            activeFocus={tool.id === activeFocusId}
            relationDepth={relationDepth}
            labelVisible={shouldShowToolLabel(tool, relationDepth, inLens)}
            dimmed={dimmed}
            interactive={!dimmed || tool.id === selectedId || tool.id === activeFocusId}
            pocketed={pocketCategory === tool.category}
            onSelect={onSelectId}
            onToolHover={handleToolHover}
          />
        );
      })}

      <ConnectionLines
        links={allLinks}
        positionById={positionById}
        relationDepthById={relationDepthById}
        lensRelevantIds={lensRelevantIds}
        toolCategoryById={toolCategoryById}
        toolStageById={toolStageById}
        focusedCategory={focusedCategory}
        pocketCategory={pocketCategory}
        relationLens={relationLens}
        selectedId={activeFocusId}
      />
    </Canvas>
    {contextLost && (
      <div
        role="status"
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          textAlign: 'center',
          padding: '0 24px',
          background: 'rgba(2, 0, 8, 0.82)',
          color: 'rgba(255, 255, 255, 0.85)',
          font: '600 13px system-ui, sans-serif',
          pointerEvents: 'none',
        }}
      >
        Rendering paused — the graphics context was lost. Restoring when the GPU is ready…
      </div>
    )}
    </>
  );
}
