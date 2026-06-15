# Visualization Playground Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a contained Visual Lab that lets us compare three alternate AI Map visualizations: AI Brain, Vision Space, and AI Galaxy.

**Architecture:** Add a separate `VisualizationLab` component tree that reads from the existing seed data through a shared adapter. `App.tsx` gets a lightweight mode switch so the current universe map remains the default and the lab is easy to remove. Each visual variant is a focused component that consumes the same `LabData` contract.

**Tech Stack:** React 19, TypeScript strict, Vite 8, Tailwind CSS 4, existing Three/R3F stack, Vitest for pure adapter tests.

---

## Baseline Refs

- Spec: `docs/superpowers/specs/2026-06-15-visualization-playground-design.md`
- Product context: `docs/PRODUCT_CTO.md`
- App structure: `docs/APP_STRUCTURE.md`
- Existing entry point: `src/App.tsx`
- Existing data source: `src/data/ai-tool-universe.ts`
- Existing 3D stack: `src/components/AIToolUniverse3D/*`

## Compatibility Boundary

- The existing map must still open first.
- Do not change `AIToolUniverseMap` behavior.
- Do not change seed data or schema.
- Do not add a routing library.
- Keep `.superpowers/` ignored.

## File Map

- Create `src/components/VisualizationLab/visualization-data.ts`: data adapter and deterministic layout helpers.
- Create `src/components/VisualizationLab/visualization-data.test.ts`: adapter tests.
- Create `src/components/VisualizationLab/VisualizationLab.tsx`: lab shell, tabs, selected tool state.
- Create `src/components/VisualizationLab/BrainGraphVariant.tsx`: Obsidian-style 2D animated graph.
- Create `src/components/VisualizationLab/VisionSpaceVariant.tsx`: Vision Pro-like 3D object space.
- Create `src/components/VisualizationLab/GalaxyMapVariant.tsx`: galaxy/RTS-style 3D map.
- Create `src/components/VisualizationLab/index.ts`: public export.
- Modify `src/App.tsx`: add Map/Lab switch without changing the map default.
- Modify `src/index.css` only if needed for reusable lab animation classes.

## Task 1: Shared Visualization Data Adapter

**Files:**
- Create: `src/components/VisualizationLab/visualization-data.ts`
- Test: `src/components/VisualizationLab/visualization-data.test.ts`

**Why:** All three variants must compare visual metaphors using identical seed data.

**Impact/Compatibility:** Pure data module only. No UI behavior changes.

**Verification:** `npm test -- src/components/VisualizationLab/visualization-data.test.ts`

- [ ] **Step 1: Write the failing test**

Create `src/components/VisualizationLab/visualization-data.test.ts`:

```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
npm test -- src/components/VisualizationLab/visualization-data.test.ts
```

Expected: fails because `visualization-data.ts` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `src/components/VisualizationLab/visualization-data.ts`:

```ts
import type { AITool, ToolCategory, ToolCategoryId, UniverseLink, WorkflowStageId } from '../../data/ai-tool-universe';

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
    links: [...linksByKey.values()],
    clusters,
    nodeById: new Map(nodes.map((node) => [node.id, node])),
    clusterById: new Map(clusters.map((cluster) => [cluster.id, cluster])),
  };
}

export function getConnectedNodeIds(data: LabData, focusId: string): Set<string> {
  const ids = new Set<string>([focusId]);
  data.links.forEach((link) => {
    if (link.source === focusId) ids.add(link.target);
    if (link.target === focusId) ids.add(link.source);
  });
  return ids;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
npm test -- src/components/VisualizationLab/visualization-data.test.ts
```

Expected: all adapter tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/components/VisualizationLab/visualization-data.ts src/components/VisualizationLab/visualization-data.test.ts
git commit -m "test: add visualization lab data adapter"
```

## Task 2: Visual Lab Shell and App Switch

**Files:**
- Create: `src/components/VisualizationLab/VisualizationLab.tsx`
- Create: `src/components/VisualizationLab/index.ts`
- Modify: `src/App.tsx`

**Why:** Provide an isolated place to compare variants without changing the current default map.

**Impact/Compatibility:** Current map remains default. New button switches to lab mode.

**Verification:** `npm run typecheck`

- [ ] **Step 1: Write the failing shell integration**

Modify `src/App.tsx` so it imports a component that does not exist yet:

```tsx
import { useState } from 'react';
import { AIToolUniverseMap } from './components/AIToolUniverseMap';
import { VisualizationLab } from './components/VisualizationLab';

type AppMode = 'map' | 'lab';

export function App() {
  const [isOpen, setIsOpen] = useState(true);
  const [mode, setMode] = useState<AppMode>('map');

  if (mode === 'lab') {
    return <VisualizationLab onBack={() => setMode('map')} />;
  }

  return (
    <div className="min-h-[100dvh] bg-[#03040a] text-text-primary">
      {isOpen ? (
        <AIToolUniverseMap onClose={() => setIsOpen(false)} />
      ) : (
        <main className="flex min-h-[100dvh] flex-col items-center justify-center gap-3 px-6">
          <button
            type="button"
            onClick={() => setIsOpen(true)}
            className="rounded-xl border border-white/15 bg-white/[0.08] px-5 py-3 text-sm font-semibold text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_24px_80px_rgba(0,0,0,0.45)] backdrop-blur-2xl transition hover:bg-white/[0.12] active:scale-[0.98]"
          >
            Open AI Tool Universe Map
          </button>
          <button
            type="button"
            onClick={() => setMode('lab')}
            className="rounded-xl border border-cyan-300/25 bg-cyan-300/[0.08] px-5 py-3 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/[0.14] active:scale-[0.98]"
          >
            Open Visual Lab
          </button>
        </main>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Run typecheck to verify it fails**

Run:

```bash
npm run typecheck
```

Expected: fails with missing `./components/VisualizationLab`.

- [ ] **Step 3: Create the shell**

Create `src/components/VisualizationLab/VisualizationLab.tsx`:

```tsx
import { useMemo, useState, type ReactNode } from 'react';
import { ArrowLeft, Brain, Orbit, Sparkles } from 'lucide-react';
import { categories, tools, workflowLinks } from '../../data/ai-tool-universe';
import { buildVisualizationData } from './visualization-data';

type LabVariant = 'brain' | 'vision' | 'galaxy';

interface VisualizationLabProps {
  onBack: () => void;
}

const variants: Array<{ id: LabVariant; label: string; description: string }> = [
  { id: 'brain', label: 'AI Brain', description: 'Obsidian-style relationship graph' },
  { id: 'vision', label: 'Vision Space', description: 'Minimal floating AI worlds' },
  { id: 'galaxy', label: 'AI Galaxy', description: 'RTS-scale sectors and stars' },
];

export function VisualizationLab({ onBack }: VisualizationLabProps) {
  const data = useMemo(() => buildVisualizationData({ categories, tools, workflowLinks }), []);
  const [variant, setVariant] = useState<LabVariant>('brain');
  const [selectedId, setSelectedId] = useState('founder-os');
  const selected = data.nodeById.get(selectedId) ?? data.nodes[0];

  return (
    <main className="min-h-[100dvh] bg-[#03040a] text-white">
      <header className="flex flex-wrap items-center justify-between gap-3 border-b border-white/10 px-4 py-3 lg:px-6">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onBack}
            className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-white/15 bg-white/[0.06] text-white transition hover:bg-white/[0.12]"
            aria-label="Back to universe map"
          >
            <ArrowLeft size={18} />
          </button>
          <div>
            <p className="text-xs uppercase tracking-[0.22em] text-cyan-100/60">Visual Lab</p>
            <h1 className="text-xl font-semibold">AI map visualization variants</h1>
          </div>
        </div>

        <div className="flex rounded-full border border-white/10 bg-white/[0.05] p-1">
          {variants.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setVariant(item.id)}
              className={`rounded-full px-4 py-2 text-sm font-medium transition ${
                variant === item.id ? 'bg-white text-slate-950' : 'text-white/70 hover:text-white'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </header>

      <section className="grid min-h-[calc(100dvh-74px)] grid-cols-1 lg:grid-cols-[1fr_320px]">
        <div className="relative min-h-[620px] overflow-hidden">
          <PendingVariant variant={variant} />
        </div>
        <aside className="border-t border-white/10 bg-black/30 p-5 lg:border-l lg:border-t-0">
          <div className="rounded-lg border border-white/10 bg-white/[0.05] p-4">
            <p className="text-xs uppercase tracking-[0.18em] text-white/45">Selected</p>
            <h2 className="mt-2 text-lg font-semibold">{selected.label}</h2>
            <p className="mt-2 text-sm leading-6 text-white/62">{selected.summary}</p>
            <div className="mt-4 flex flex-wrap gap-2">
              <span className="rounded-full bg-white/[0.08] px-3 py-1 text-xs text-white/70">{selected.categoryName}</span>
              <span className="rounded-full bg-white/[0.08] px-3 py-1 text-xs text-white/70">{selected.stage}</span>
            </div>
          </div>

          <div className="mt-5 space-y-3">
            <ComparisonNote icon={<Brain size={16} />} label="Relationship clarity" value={variant === 'brain' ? 'High' : 'Medium'} />
            <ComparisonNote icon={<Sparkles size={16} />} label="Premium feel" value={variant === 'vision' ? 'High' : 'Medium'} />
            <ComparisonNote icon={<Orbit size={16} />} label="Scale feeling" value={variant === 'galaxy' ? 'High' : 'Medium'} />
          </div>
        </aside>
      </section>
    </main>
  );
}

function PendingVariant({ variant }: { variant: LabVariant }) {
  return (
    <div className="flex h-full min-h-[620px] items-center justify-center bg-[radial-gradient(circle_at_50%_45%,rgba(34,211,238,0.12),transparent_42%),#03040a]">
      <p className="rounded-full border border-white/10 bg-white/[0.05] px-4 py-2 text-sm text-white/65">
        {variant} variant mounts in the next tasks
      </p>
    </div>
  );
}

function ComparisonNote({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-white/10 bg-white/[0.04] px-3 py-3 text-sm">
      <span className="flex items-center gap-2 text-white/62">{icon}{label}</span>
      <span className="font-semibold text-white">{value}</span>
    </div>
  );
}
```

Create `src/components/VisualizationLab/index.ts`:

```ts
export { VisualizationLab } from './VisualizationLab';
```

- [ ] **Step 4: Run typecheck to verify it passes**

Run:

```bash
npm run typecheck
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add src/App.tsx src/components/VisualizationLab/VisualizationLab.tsx src/components/VisualizationLab/index.ts
git commit -m "feat: add visualization lab shell"
```

## Task 3: AI Brain Variant

**Files:**
- Create: `src/components/VisualizationLab/BrainGraphVariant.tsx`
- Modify: `src/components/VisualizationLab/VisualizationLab.tsx`

**Why:** Prototype the Obsidian-style 2D animated graph requested by the user.

**Impact/Compatibility:** Lab-only component. No production map changes.

**Verification:** `npm run typecheck && npm run build`

- [ ] **Step 1: Wire the missing variant**

Modify `VisualizationLab.tsx` imports and variant area:

```tsx
import { BrainGraphVariant } from './BrainGraphVariant';
```

Replace the temporary variant area for `brain` with:

```tsx
{variant === 'brain' ? (
  <BrainGraphVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
) : (
  <PendingVariant variant={variant} />
)}
```

- [ ] **Step 2: Run typecheck to verify it fails**

Run:

```bash
npm run typecheck
```

Expected: fails with missing `BrainGraphVariant`.

- [ ] **Step 3: Create the component**

Create `src/components/VisualizationLab/BrainGraphVariant.tsx`:

```tsx
import { useMemo } from 'react';
import type { LabData } from './visualization-data';
import { getConnectedNodeIds } from './visualization-data';

interface BrainGraphVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

const width = 1100;
const height = 680;
const centerX = width / 2;
const centerY = height / 2;

function positionFor(index: number, count: number, orbit: number, angle: number) {
  const ring = 90 + orbit * 86 + (index % 5) * 12;
  const theta = (angle * Math.PI) / 180 + (index / Math.max(count, 1)) * Math.PI * 0.4;
  return {
    x: centerX + Math.cos(theta) * ring,
    y: centerY + Math.sin(theta) * ring * 0.72,
  };
}

export function BrainGraphVariant({ data, selectedId, onSelect }: BrainGraphVariantProps) {
  const connected = useMemo(() => getConnectedNodeIds(data, selectedId), [data, selectedId]);
  const positions = useMemo(() => {
    const map = new Map<string, { x: number; y: number }>();
    data.nodes.forEach((node, index) => {
      map.set(node.id, node.id === selectedId ? { x: centerX, y: centerY } : positionFor(index, data.nodes.length, node.orbit, node.angle));
    });
    return map;
  }, [data.nodes, selectedId]);

  return (
    <div className="h-full min-h-[620px] bg-[radial-gradient(circle_at_50%_50%,rgba(103,232,249,0.16),transparent_35%),#03040a]">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" role="img" aria-label="AI Brain relationship graph">
        <g>
          {data.links.map((link) => {
            const source = positions.get(link.source);
            const target = positions.get(link.target);
            if (!source || !target) return null;
            const active = connected.has(link.source) && connected.has(link.target);
            return (
              <line
                key={link.id}
                x1={source.x}
                y1={source.y}
                x2={target.x}
                y2={target.y}
                stroke={active ? 'rgba(155,232,255,0.62)' : 'rgba(255,255,255,0.10)'}
                strokeWidth={active ? 1.8 : 1}
              />
            );
          })}
        </g>
        <g>
          {data.nodes.map((node, index) => {
            const position = positions.get(node.id) ?? positionFor(index, data.nodes.length, node.orbit, node.angle);
            const isSelected = node.id === selectedId;
            const isConnected = connected.has(node.id);
            const radius = isSelected ? 30 : 9 + node.weight * 3.2;
            return (
              <g
                key={node.id}
                transform={`translate(${position.x} ${position.y})`}
                opacity={isSelected || isConnected ? 1 : 0.28}
                role="button"
                tabIndex={0}
                aria-label={`Select ${node.label}`}
                onClick={() => onSelect(node.id)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    onSelect(node.id);
                  }
                }}
                style={{ cursor: 'pointer', outline: 'none' }}
              >
                <circle r={radius + 16} fill={node.color} opacity={isSelected ? 0.18 : 0.08} />
                <circle r={radius} fill={node.color} opacity={isSelected ? 0.95 : 0.78} />
                {(isSelected || isConnected) && (
                  <text y={radius + 20} textAnchor="middle" fill="white" fontSize={isSelected ? 17 : 12} fontWeight={isSelected ? 700 : 500}>
                    {node.label}
                  </text>
                )}
              </g>
            );
          })}
        </g>
      </svg>
    </div>
  );
}
```

- [ ] **Step 4: Run verification**

Run:

```bash
npm run typecheck
npm run build
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add src/components/VisualizationLab/BrainGraphVariant.tsx src/components/VisualizationLab/VisualizationLab.tsx
git commit -m "feat: add AI Brain visual lab variant"
```

## Task 4: Vision Space Variant

**Files:**
- Create: `src/components/VisualizationLab/VisionSpaceVariant.tsx`
- Modify: `src/components/VisualizationLab/VisualizationLab.tsx`

**Why:** Prototype the minimal Apple/Vision Pro object-space direction.

**Impact/Compatibility:** Lab-only R3F scene.

**Verification:** `npm run typecheck && npm run build`

- [ ] **Step 1: Wire the missing variant**

Modify `VisualizationLab.tsx`:

```tsx
import { VisionSpaceVariant } from './VisionSpaceVariant';
```

Add the branch:

```tsx
{variant === 'vision' ? (
  <VisionSpaceVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
) : variant === 'brain' ? (
  <BrainGraphVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
) : (
  <PendingVariant variant={variant} />
)}
```

- [ ] **Step 2: Run typecheck to verify it fails**

Run:

```bash
npm run typecheck
```

Expected: fails with missing `VisionSpaceVariant`.

- [ ] **Step 3: Create the component**

Create `src/components/VisualizationLab/VisionSpaceVariant.tsx`:

```tsx
import { Canvas } from '@react-three/fiber';
import { Billboard, Text } from '@react-three/drei';
import type { LabData, LabNode } from './visualization-data';

interface VisionSpaceVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

function objectPosition(index: number, total: number): [number, number, number] {
  const angle = (index / Math.max(total, 1)) * Math.PI * 2;
  const radius = 4.6 + (index % 3) * 1.2;
  return [Math.cos(angle) * radius, Math.sin(index * 1.7) * 0.8, Math.sin(angle) * radius];
}

function FloatingObject({ node, index, total, selected, onSelect }: { node: LabNode; index: number; total: number; selected: boolean; onSelect: (id: string) => void }) {
  const position = objectPosition(index, total);
  const scale = selected ? 1.45 : 0.86 + node.orbit * 0.12;
  return (
    <group position={position} scale={scale} onClick={(event) => { event.stopPropagation(); onSelect(node.id); }}>
      <mesh>
        <sphereGeometry args={[0.42, 32, 32]} />
        <meshStandardMaterial color={node.color} emissive={node.color} emissiveIntensity={selected ? 1.2 : 0.38} roughness={0.42} metalness={0.12} />
      </mesh>
      <Billboard position={[0, -0.78, 0]}>
        <Text fontSize={0.18} color="white" anchorX="center" anchorY="middle" maxWidth={2.0}>
          {node.label}
        </Text>
      </Billboard>
    </group>
  );
}

export function VisionSpaceVariant({ data, selectedId, onSelect }: VisionSpaceVariantProps) {
  const visibleNodes = data.nodes.slice(0, 18);
  return (
    <div className="h-full min-h-[620px] bg-black">
      <Canvas camera={{ position: [0, 4.4, 11], fov: 45 }} dpr={[1, 1.6]}>
        <color attach="background" args={['#020207']} />
        <ambientLight intensity={0.32} />
        <directionalLight position={[4, 6, 5]} intensity={2.4} />
        <pointLight position={[-4, -2, 3]} intensity={8} color="#67e8f9" />
        {visibleNodes.map((node, index) => (
          <FloatingObject key={node.id} node={node} index={index} total={visibleNodes.length} selected={node.id === selectedId} onSelect={onSelect} />
        ))}
      </Canvas>
    </div>
  );
}
```

- [ ] **Step 4: Run verification**

Run:

```bash
npm run typecheck
npm run build
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add src/components/VisualizationLab/VisionSpaceVariant.tsx src/components/VisualizationLab/VisualizationLab.tsx
git commit -m "feat: add Vision Space visual lab variant"
```

## Task 5: AI Galaxy Variant

**Files:**
- Create: `src/components/VisualizationLab/GalaxyMapVariant.tsx`
- Modify: `src/components/VisualizationLab/VisualizationLab.tsx`

**Why:** Prototype the Google Earth / No Man's Sky / RTS scale metaphor.

**Impact/Compatibility:** Lab-only R3F scene.

**Verification:** `npm run typecheck && npm run build`

- [ ] **Step 1: Wire the missing variant**

Modify `VisualizationLab.tsx`:

```tsx
import { GalaxyMapVariant } from './GalaxyMapVariant';
```

Use the branch:

```tsx
{variant === 'brain' ? (
  <BrainGraphVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
) : variant === 'vision' ? (
  <VisionSpaceVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
) : (
  <GalaxyMapVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
)}
```

- [ ] **Step 2: Run typecheck to verify it fails**

Run:

```bash
npm run typecheck
```

Expected: fails with missing `GalaxyMapVariant`.

- [ ] **Step 3: Create the component**

Create `src/components/VisualizationLab/GalaxyMapVariant.tsx`:

```tsx
import { Canvas } from '@react-three/fiber';
import { Billboard, Line, Text } from '@react-three/drei';
import type { LabData, LabNode } from './visualization-data';
import { getConnectedNodeIds } from './visualization-data';

interface GalaxyMapVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

function galaxyPosition(node: LabNode, index: number): [number, number, number] {
  const arm = index % 5;
  const radius = 1.4 + node.orbit * 1.8 + (index % 7) * 0.18;
  const theta = (node.angle * Math.PI) / 180 + arm * 0.38 + radius * 0.24;
  return [Math.cos(theta) * radius, Math.sin(theta * 1.6) * 0.26, Math.sin(theta) * radius * 0.72];
}

export function GalaxyMapVariant({ data, selectedId, onSelect }: GalaxyMapVariantProps) {
  const connected = getConnectedNodeIds(data, selectedId);
  const positions = new Map(data.nodes.map((node, index) => [node.id, galaxyPosition(node, index)]));
  return (
    <div className="h-full min-h-[620px] bg-[#02030b]">
      <Canvas camera={{ position: [0, 7.5, 12.5], fov: 48 }} dpr={[1, 1.6]}>
        <color attach="background" args={['#02030b']} />
        <ambientLight intensity={0.55} />
        <pointLight position={[0, 2, 0]} intensity={18} color="#9be8ff" />
        <mesh rotation={[-Math.PI / 2, 0, 0]}>
          <ringGeometry args={[1.2, 8.8, 96]} />
          <meshBasicMaterial color="#67e8f9" transparent opacity={0.06} />
        </mesh>
        {data.links.slice(0, 90).map((link) => {
          const source = positions.get(link.source);
          const target = positions.get(link.target);
          if (!source || !target) return null;
          const active = connected.has(link.source) && connected.has(link.target);
          return <Line key={link.id} points={[source, target]} color={active ? '#9be8ff' : '#ffffff'} transparent opacity={active ? 0.5 : 0.08} lineWidth={active ? 1.2 : 0.45} />;
        })}
        {data.nodes.map((node, index) => {
          const position = positions.get(node.id) ?? [0, 0, 0];
          const selected = node.id === selectedId;
          const active = connected.has(node.id);
          return (
            <group key={node.id} position={position} onClick={(event) => { event.stopPropagation(); onSelect(node.id); }}>
              <mesh scale={selected ? 1.9 : 1}>
                <sphereGeometry args={[0.08 + node.orbit * 0.035, 16, 16]} />
                <meshBasicMaterial color={node.color} transparent opacity={selected || active ? 1 : 0.44} />
              </mesh>
              {(selected || active) && (
                <Billboard position={[0, 0.28, 0]}>
                  <Text fontSize={selected ? 0.2 : 0.13} color="white" anchorX="center" anchorY="middle" maxWidth={1.8}>
                    {node.label}
                  </Text>
                </Billboard>
              )}
            </group>
          );
        })}
      </Canvas>
    </div>
  );
}
```

- [ ] **Step 4: Run verification**

Run:

```bash
npm run typecheck
npm run build
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add src/components/VisualizationLab/GalaxyMapVariant.tsx src/components/VisualizationLab/VisualizationLab.tsx
git commit -m "feat: add AI Galaxy visual lab variant"
```

## Task 6: Final Verification and Local Review

**Files:**
- Modify only files created in previous tasks if verification exposes issues.

**Why:** Confirm the lab is buildable and ready for visual comparison.

**Impact/Compatibility:** No new behavior beyond the Visual Lab path.

**Verification:** `npm run typecheck && npm test && npm run build`

- [ ] **Step 1: Run full checks**

Run:

```bash
npm run typecheck
npm test
npm run build
```

Expected: all pass.

- [ ] **Step 2: Start dev server**

Run:

```bash
npm run dev
```

Expected: Vite serves at `http://127.0.0.1:5177`.

- [ ] **Step 3: Browser review**

Open `http://127.0.0.1:5177`, switch to Visual Lab, and verify:

- Brain, Vision, and Galaxy tabs render.
- Clicking a node updates the selected panel.
- Returning to Universe Map still works.
- Existing map still opens first after refresh.

- [ ] **Step 4: Fix only verification defects**

If any issue appears, patch the smallest relevant file and repeat:

```bash
npm run typecheck
npm test
npm run build
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/App.tsx src/components/VisualizationLab
git commit -m "chore: verify visualization lab variants"
```

## Execution Notes

- Prefer subagent-driven execution if available: one task per subagent, with review between tasks.
- If executing inline, complete Task 1 first and do not start UI work until adapter tests pass.
- Do not edit `AIToolUniverseMap.tsx`.
- Do not edit seed JSON unless a test proves invalid source data.
- Do not run Playwright unless asked after the lab is visually inspected.
