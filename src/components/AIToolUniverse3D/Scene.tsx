import { useMemo, useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { EffectComposer, Bloom, Vignette } from '@react-three/postprocessing';
import { tools, categories, workflowLinks, categoryById } from '../../data/ai-tool-universe';
import type { ToolCategoryId, WorkflowStageId, AITool } from '../../data/ai-tool-universe';
import { StarField } from './StarField';
import { FounderOSNode } from './FounderOSNode';
import { GalaxyDust } from './GalaxyDust';
import { CategoryRing } from './CategoryRing';
import { ToolNode } from './ToolNode';
import { ConnectionLines } from './ConnectionLines';
import { CameraController } from './CameraController';
import { categoryPosition, toolPosition } from './layout';

interface SceneProps {
  selectedId: string;
  onSelectId: (id: string) => void;
  activeCategory: ToolCategoryId | 'all';
  activeStage: WorkflowStageId | 'all';
  query: string;
  customTools: AITool[];
  onSelectCategory: (category: ToolCategoryId | 'all') => void;
}

export function Scene({
  selectedId,
  onSelectId,
  activeCategory,
  activeStage,
  query,
  customTools,
  onSelectCategory,
}: SceneProps) {
  const [hoveredCategory, setHoveredCategory] = useState<ToolCategoryId | null>(null);
  const allTools = useMemo(() => [...tools, ...customTools], [customTools]);

  const positionById = useMemo(() => {
    const map = new Map<string, [number, number, number]>();
    allTools.forEach((tool) => {
      const cat = categoryById.get(tool.category);
      if (!cat) return;
      map.set(tool.id, toolPosition(tool.angle, tool.orbit, cat.angle));
    });
    return map;
  }, [allTools]);

  const selectedTool = allTools.find((t) => t.id === selectedId);
  const focusedCategory = hoveredCategory ?? (activeCategory !== 'all' ? activeCategory : null);
  const toolCategoryById = useMemo(
    () => new Map(allTools.map((tool) => [tool.id, tool.category])),
    [allTools],
  );
  const relationDepthById = useMemo(() => {
    const map = new Map<string, number>();
    if (!selectedTool) return map;
    map.set(selectedTool.id, 0);

    const directIds = new Set<string>(selectedTool.relationIds);
    allTools.forEach((tool) => {
      if (tool.relationIds.includes(selectedTool.id)) directIds.add(tool.id);
    });

    directIds.forEach((id) => map.set(id, 1));
    directIds.forEach((id) => {
      const directTool = allTools.find((tool) => tool.id === id);
      directTool?.relationIds.forEach((nextId) => {
        if (!map.has(nextId)) map.set(nextId, 2);
      });
    });

    return map;
  }, [allTools, selectedTool]);

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

  const activeCategoryPosition = activeCategory !== 'all'
    ? categoryPosition(categoryById.get(activeCategory)?.angle ?? 0)
    : null;
  const targetPosition = selectedId !== 'founder-os'
    ? (positionById.get(selectedId) ?? null)
    : activeCategoryPosition;

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
    <Canvas
      camera={{ position: [0, 5.4, 20.5], fov: 58 }}
      gl={{ antialias: true, toneMapping: 0 }}
      style={{ background: '#020008', width: '100%', height: '100%' }}
    >
      <ambientLight intensity={0.15} />
      <StarField />
      <GalaxyDust />
      <CameraController targetPosition={targetPosition} />

      <FounderOSNode
        selected={selectedId === 'founder-os'}
        onSelect={() => onSelectId('founder-os')}
      />

      {categories.filter((c) => c.id !== 'core').map((cat) => (
        <CategoryRing
          key={cat.id}
          category={cat}
          position={categoryPosition(cat.angle)}
          active={activeCategory === 'all' || activeCategory === cat.id || hoveredCategory === cat.id}
          hovered={hoveredCategory === cat.id}
          onSelect={onSelectCategory}
          onHover={setHoveredCategory}
        />
      ))}

      {allTools.filter((t) => t.id !== 'founder-os').map((tool) => {
        const pos = positionById.get(tool.id);
        const cat = categoryById.get(tool.category);
        if (!pos || !cat) return null;
        return (
          <ToolNode
            key={tool.id}
            id={tool.id}
            name={tool.name}
            category={tool.category}
            position={pos}
            color={cat.color}
            glow={cat.glow}
            selected={tool.id === selectedId}
            relationDepth={relationDepthById.get(tool.id)}
            labelVisible={focusedCategory === tool.category}
            dimmed={
              !visibleIds.has(tool.id)
              || (selectedId !== 'founder-os' && !relationDepthById.has(tool.id))
              || (Boolean(focusedCategory) && tool.category !== focusedCategory)
            }
            onSelect={onSelectId}
            onCategoryHover={setHoveredCategory}
          />
        );
      })}

      <ConnectionLines
        links={allLinks}
        positionById={positionById}
        relationDepthById={relationDepthById}
        toolCategoryById={toolCategoryById}
        focusedCategory={focusedCategory}
        selectedId={selectedId}
      />

      <EffectComposer>
        <Bloom
          luminanceThreshold={0.2}
          luminanceSmoothing={0.9}
          intensity={1.5}
          mipmapBlur
          radius={0.85}
          levels={8}
        />
        <Vignette offset={0.4} darkness={0.6} />
      </EffectComposer>
    </Canvas>
  );
}
