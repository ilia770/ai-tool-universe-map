# P9 · Relationship Intelligence Implementation Plan

> Part of the **2026-06-16 product-v2** set. Web + iOS. Branch: `feat/product-v2`.
> Depends on **P0** (knowledge layer) and **P8** (intake / categories).

## Goal

Today every link in the universe is one of two blunt instruments:

- **Hand-curated `workflowLinks`** (`src/data/ai-tool-universe.seed.json`,
  decoded on iOS by `UniverseSeed.workflowLinks`), and
- **`AITool.relationIds`** — a flat string array with **no reason and no
  confidence**. When the user adds a tool, `ToolStoreProvider.addTool`
  (`src/playground/store.tsx`) copies `classifyToolDetailed(...).relationIds`
  verbatim — i.e. the classifier rule's `anchors`, which are **category hubs**
  (`founder-os`, `cursor`, `vercel`, …). So a pasted Chrome extension links to
  `founder-os` and three coding hubs, never to the actual Google tool, and a
  hub like Google would (if added) attract every coding tool to it. The edges
  are blanket, not pinpoint, and the UI can only say "Connected to · N" with no
  _why_.

P9 adds a **relationship intelligence layer**: a pure, testable inference
engine that, given a tool (id, category, domain, text, P0 knowledge) and the
existing universe, returns only **meaningful, pinpoint edges**, each carrying a
**typed `kind`**, a short **human `reason`**, and a **`confidence` in [0,1]**.
Low-confidence candidates are thresholded out. The web detail window
(`ToolDetail.tsx`) and the iOS detail sheet (`ToolDetailSection.swift`) render
"Connected because …" per edge; web `ConnectionLines` and iOS `makeLink` draw
the inferred edges with their confidence driving opacity — no per-frame
relayout, 60fps preserved.

### Concrete behaviour contract (drives the tests)

- A **Chrome-extension-for-Google** links to `google` with kind
  `extension-of` and does **not** link to unrelated tools (`figma`,
  `elevenlabs`).
- A **hub** tool (high category fan-out, e.g. `google`) does **not**
  over-connect: it gains edges only to tools that name/extend/integrate it,
  capped per kind.
- Two tools in the **same category** with no stronger signal link with kind
  `alternative-to` at a modest confidence, capped to the top few.

## Architecture

```
                  ┌─────────────────────────────────────────────┐
   shared spec →  │  inferRelationships(candidate, universe, k)  │  PURE
                  │   src/lib/relationship-intelligence.ts (TS)  │  (no React,
                  │   …/Data/RelationshipIntelligence.swift (Sw) │   no RealityKit)
                  └───────────────┬─────────────────────────────┘
                                  │ InferredEdge[] { fromId,toId,kind,reason,confidence }
              ┌───────────────────┴────────────────────┐
        web   │                                    iOS  │
   store.tsx addTool() ──► tool.inferredEdges      UniverseViewModel ──► inferredEdges
        │                                                │
   ConnectionLines.tsx  (confidence → opacity)     UniverseView.makeLink (confidence → alpha)
   ToolDetail.tsx       ("Connected because …")     ToolDetailSection ("Connected because …")
```

`InferredEdge` is a **new, additive** shape. We do **not** change the persisted
`AITool.relationIds` contract validated by `universe-schema.ts`
(`isValidCustomToolPayload`) — inferred edges are derived at runtime / intake
time and rendered alongside the existing `relationIds`-derived chips, so seed
integrity tests and the byte-identical seed/knowledge contract stay green.

The TS and Swift engines implement the **same ruleset** against the same JSON
inputs (the P0 `knowledge.json` and the canonical seed), so a shared fixture
table (`relationship-fixtures.json`) is asserted on both lanes — the same
cross-lane discipline P0 uses for `knowledge.json`.

## Tech Stack

- **Web**: TypeScript, React 18, Vite, R3F + `@react-three/drei`
  (`QuadraticBezierLine` already in `ConnectionLines.tsx`), Vitest
  (`npm run test` → `vitest run src`). Liquid-glass tokens from
  `src/playground/designSystem.ts` (`GLASS`, `TYPE`, `DURATION`, `EASE`,
  `STAGGER`).
- **iOS**: Swift, SwiftUI + RealityKit, `swift-testing` (`@Suite`/`@Test`),
  run via `bash scripts/ios-verify.sh`. Brand haptics (`BrandHaptics`),
  `LiquidGlass`, `PressBounce`, Reduce Motion already wired in the UI layer.
- **Shared**: one fixture JSON asserted on both lanes (P0 pattern).

## Edge kinds (shared enum)

| kind | meaning | example signal |
|---|---|---|
| `extension-of` | A extends / is an add-on for B | "chrome extension for google" → `google` |
| `integrates-with` | A integrates / connects to B | text/knowledge names B explicitly |
| `same-vendor` | A and B share a vendor/brand | shared registrable domain or brand token |
| `data-flows-to` | A produces output B consumes (workflow adjacency) | stage(A)+1 == stage(B), shared category lineage |
| `alternative-to` | A and B compete in one category | same category, no stronger signal, top-N |

---

## Task 1 — Shared types + edge-kind enum (web)

**Files**
- **Create** `/tmp/wt-ios/src/lib/relationship-intelligence.types.ts`
- **Create** `/tmp/wt-ios/src/lib/relationship-intelligence.types.test.ts`

### Steps

1. **Write the failing test** `relationship-intelligence.types.test.ts`:

   ```ts
   import { describe, expect, it } from 'vitest';
   import { RELATION_KINDS, isInferredEdge } from './relationship-intelligence.types';

   describe('relationship-intelligence types', () => {
     it('exposes the five typed edge kinds', () => {
       expect([...RELATION_KINDS].sort()).toEqual(
         ['alternative-to', 'data-flows-to', 'extension-of', 'integrates-with', 'same-vendor'],
       );
     });

     it('accepts a well-formed edge and rejects malformed ones', () => {
       expect(isInferredEdge({
         fromId: 'a', toId: 'b', kind: 'extension-of',
         reason: 'A is an extension for B.', confidence: 0.7,
       })).toBe(true);
       expect(isInferredEdge({ fromId: 'a', toId: 'a', kind: 'extension-of', reason: 'x', confidence: 0.5 })).toBe(false); // self
       expect(isInferredEdge({ fromId: 'a', toId: 'b', kind: 'nope', reason: 'x', confidence: 0.5 })).toBe(false); // bad kind
       expect(isInferredEdge({ fromId: 'a', toId: 'b', kind: 'extension-of', reason: 'x', confidence: 2 })).toBe(false); // out of range
     });
   });
   ```

2. **Run** `npm run test -- relationship-intelligence.types` → fails (module missing).

3. **Minimal impl** `relationship-intelligence.types.ts`:

   ```ts
   export const RELATION_KINDS = [
     'extension-of', 'integrates-with', 'same-vendor', 'data-flows-to', 'alternative-to',
   ] as const;
   export type RelationKind = (typeof RELATION_KINDS)[number];
   const KIND_SET: ReadonlySet<string> = new Set(RELATION_KINDS);

   export interface InferredEdge {
     fromId: string;
     toId: string;
     kind: RelationKind;
     reason: string;
     confidence: number; // [0,1]
   }

   export const isInferredEdge = (value: unknown): value is InferredEdge => {
     if (typeof value !== 'object' || value === null) return false;
     const e = value as Record<string, unknown>;
     return typeof e.fromId === 'string' && e.fromId.trim() !== ''
       && typeof e.toId === 'string' && e.toId.trim() !== ''
       && e.fromId !== e.toId
       && typeof e.kind === 'string' && KIND_SET.has(e.kind)
       && typeof e.reason === 'string' && e.reason.trim() !== ''
       && typeof e.confidence === 'number'
       && e.confidence >= 0 && e.confidence <= 1;
   };
   ```

4. **Run** `npm run test -- relationship-intelligence.types` → passes.

5. **Commit**: `git add src/lib/relationship-intelligence.types.ts src/lib/relationship-intelligence.types.test.ts && git commit -m "P9: shared InferredEdge type + RelationKind enum"`.

---

## Task 2 — The web inference engine (pure)

This is the core deliverable. `inferRelationships` takes a **candidate tool**,
the **existing universe** (`AITool[]`), and an optional **knowledge lookup**
(P0 `knowledgeFor`) and returns thresholded `InferredEdge[]`.

**Files**
- **Create** `/tmp/wt-ios/src/lib/relationship-intelligence.ts`
- **Create** `/tmp/wt-ios/src/lib/relationship-intelligence.test.ts`

### Steps

1. **Write the failing test** `relationship-intelligence.test.ts` — the three
   contract assertions plus thresholding and determinism:

   ```ts
   import { describe, expect, it } from 'vitest';
   import type { AITool } from '../data/ai-tool-universe';
   import { inferRelationships, CONFIDENCE_THRESHOLD } from './relationship-intelligence';

   const tool = (id: string, o: Partial<AITool> = {}): AITool => ({
     id, name: id, category: 'coding', summary: '', stage: 'execution',
     orbit: 2, angle: 0, relationIds: [], ...o,
   });

   // A small universe with a clear hub (google) + unrelated tools.
   const universe: AITool[] = [
     tool('google', { name: 'Google', category: 'research', stage: 'research', logoDomain: 'google.com' }),
     tool('figma', { name: 'Figma', category: 'design', stage: 'planning', logoDomain: 'figma.com' }),
     tool('elevenlabs', { name: 'ElevenLabs', category: 'media', stage: 'execution', logoDomain: 'elevenlabs.io' }),
     tool('cursor', { name: 'Cursor', category: 'coding', stage: 'execution', logoDomain: 'cursor.com' }),
   ];

   describe('inferRelationships — pinpoint, explained edges', () => {
     it('(a) a Chrome extension FOR Google links to google as extension-of, not to unrelated tools', () => {
       const candidate = tool('google-translate-ext', {
         name: 'Google Translate (Chrome extension)',
         summary: 'A Chrome extension for Google Translate.',
         category: 'research',
       });
       const edges = inferRelationships(candidate, universe);
       const targets = edges.map((e) => e.toId);
       expect(targets).toContain('google');
       expect(edges.find((e) => e.toId === 'google')!.kind).toBe('extension-of');
       expect(targets).not.toContain('figma');
       expect(targets).not.toContain('elevenlabs');
     });

     it('(b) a hub tool does not over-connect (capped, no blanket fan-out)', () => {
       const hub = tool('google', { name: 'Google', category: 'research', stage: 'research' });
       const big = [hub, ...Array.from({ length: 30 }, (_, i) =>
         tool(`coder-${i}`, { name: `Coder ${i}`, category: 'coding' }))];
       const edges = inferRelationships(hub, big);
       // No edge to a tool that neither names nor extends the hub.
       expect(edges.every((e) => e.toId !== 'coder-0')).toBe(true);
       // Hard cap: a hub never emits more than MAX_EDGES_PER_KIND * kinds.
       expect(edges.length).toBeLessThanOrEqual(12);
     });

     it('(c) same-category peers with no stronger signal link as alternative-to', () => {
       const candidate = tool('windsurf', { name: 'Windsurf', category: 'coding', stage: 'execution' });
       const edges = inferRelationships(candidate, universe);
       const alt = edges.find((e) => e.toId === 'cursor');
       expect(alt).toBeDefined();
       expect(alt!.kind).toBe('alternative-to');
       expect(alt!.reason).toMatch(/cursor/i);
     });

     it('thresholds low-confidence edges out and is deterministic', () => {
       const candidate = tool('windsurf', { category: 'coding' });
       const edges = inferRelationships(candidate, universe);
       expect(edges.every((e) => e.confidence >= CONFIDENCE_THRESHOLD)).toBe(true);
       expect(edges).toEqual(inferRelationships(candidate, universe)); // stable order
     });

     it('never returns a self edge', () => {
       const edges = inferRelationships(universe[0], universe);
       expect(edges.every((e) => e.fromId !== e.toId)).toBe(true);
     });
   });
   ```

2. **Run** `npm run test -- relationship-intelligence.test` → fails.

3. **Minimal impl** `relationship-intelligence.ts`. Each rule is a scorer that
   yields at most one edge per (candidate, target) pair; the strongest kind
   wins; results are thresholded, capped per kind, and sorted deterministically.

   ```ts
   import type { AITool } from '../data/ai-tool-universe';
   import type { InferredEdge, RelationKind } from './relationship-intelligence.types';
   import type { ToolKnowledge } from '../playground/knowledge';

   export const CONFIDENCE_THRESHOLD = 0.4;
   export const MAX_EDGES_PER_KIND = 4;

   export type KnowledgeLookup = (id: string) => ToolKnowledge | null;

   const EXT_RE = /\b(chrome|browser|firefox|edge)?\s*(extension|add-?on|plugin)\b/i;

   const registrable = (domain?: string): string | undefined =>
     domain?.toLowerCase().split('.').slice(-2).join('.') || undefined;

   const haystack = (t: AITool, k?: ToolKnowledge | null): string =>
     [t.name, t.summary, k?.whatFor ?? '', t.logoDomain ?? '', t.url ?? '']
       .join(' ').toLowerCase();

   const nameTokens = (t: AITool): string[] =>
     t.name.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length >= 3);

   /** Score a single directed candidate→target relationship; null = no edge. */
   function scorePair(
     cand: AITool, target: AITool, text: string,
   ): { kind: RelationKind; reason: string; confidence: number } | null {
     // 1. extension-of: candidate is explicitly an extension AND names target.
     const namesTarget = nameTokens(target).some((tok) => text.includes(tok));
     if (EXT_RE.test(text) && namesTarget) {
       return { kind: 'extension-of', confidence: 0.82,
         reason: `It is an extension/add-on built for ${target.name}.` };
     }
     // 2. same-vendor: shared registrable domain (and not identical tool).
     const cv = registrable(cand.logoDomain), tv = registrable(target.logoDomain);
     if (cv && tv && cv === tv) {
       return { kind: 'same-vendor', confidence: 0.78,
         reason: `Both are part of the ${target.name.split(' ')[0]} family (same vendor).` };
     }
     // 3. integrates-with: candidate text explicitly names the target tool.
     if (namesTarget && nameTokens(target).join('').length >= 4) {
       return { kind: 'integrates-with', confidence: 0.6,
         reason: `It explicitly works with ${target.name}.` };
     }
     // 4. data-flows-to: adjacent workflow stage, shared category lineage.
     const order = ['research', 'planning', 'execution', 'approval', 'review'];
     if (cand.category === target.category
       && order.indexOf(target.stage) === order.indexOf(cand.stage) + 1) {
       return { kind: 'data-flows-to', confidence: 0.5,
         reason: `Output from this stage typically flows into ${target.name}.` };
     }
     // 5. alternative-to: same category, same stage, no stronger signal.
     if (cand.category === target.category && cand.stage === target.stage) {
       return { kind: 'alternative-to', confidence: 0.45,
         reason: `A category alternative to ${target.name}.` };
     }
     return null;
   }

   export function inferRelationships(
     candidate: AITool,
     universe: AITool[],
     knowledgeFor?: KnowledgeLookup,
   ): InferredEdge[] {
     const k = knowledgeFor?.(candidate.id) ?? null;
     const text = haystack(candidate, k);

     const scored = universe
       .filter((t) => t.id !== candidate.id)
       .map((target) => {
         const s = scorePair(candidate, target, text);
         return s ? { ...s, fromId: candidate.id, toId: target.id } : null;
       })
       .filter((e): e is InferredEdge => e !== null && e.confidence >= CONFIDENCE_THRESHOLD);

     // Cap per kind — this is what stops a hub from over-connecting.
     const byKind = new Map<RelationKind, InferredEdge[]>();
     for (const e of scored) {
       const list = byKind.get(e.kind) ?? [];
       list.push(e);
       byKind.set(e.kind, list);
     }
     const capped: InferredEdge[] = [];
     for (const list of byKind.values()) {
       list.sort((a, b) => b.confidence - a.confidence || a.toId.localeCompare(b.toId));
       capped.push(...list.slice(0, MAX_EDGES_PER_KIND));
     }
     // Deterministic global order: confidence desc, then kind, then toId.
     return capped.sort((a, b) =>
       b.confidence - a.confidence || a.kind.localeCompare(b.kind) || a.toId.localeCompare(b.toId));
   }
   ```

4. **Run** `npm run test -- relationship-intelligence.test` → passes (tune
   `CONFIDENCE_THRESHOLD` / scores only if a contract test forces it).

5. **Commit**: `git add src/lib/relationship-intelligence.ts src/lib/relationship-intelligence.test.ts && git commit -m "P9: pure web inference engine — pinpoint, capped, explained edges"`.

---

## Task 3 — Wire inferred edges into the web store

`addTool` currently sets `relationIds` to the classifier anchors. Keep that for
layout, but additionally attach **inferred edges** so the renderer and detail
window can use the typed, explained edges.

**Files**
- **Modify** `/tmp/wt-ios/src/playground/toolStoreContext.ts` (extend `AddedTool`)
- **Modify** `/tmp/wt-ios/src/playground/store.tsx` (compute edges in `addTool` + expose `edgesFor`)
- **Create** `/tmp/wt-ios/src/playground/store.relationships.test.tsx`

### Steps

1. **Write the failing test** `store.relationships.test.tsx` — render the
   provider, add a Google Chrome extension, assert the store exposes an
   `extension-of` edge to `google` and none to unrelated tools:

   ```tsx
   import { render, act } from '@testing-library/react';
   import { describe, expect, it } from 'vitest';
   import { ToolStoreProvider } from './store';
   import { useToolStore } from './useToolStore';

   function Harness({ onReady }: { onReady: (s: ReturnType<typeof useToolStore>) => void }) {
     onReady(useToolStore());
     return null;
   }

   describe('store inferred relationships', () => {
     it('attaches pinpoint inferred edges to an added tool', () => {
       let store!: ReturnType<typeof useToolStore>;
       render(<ToolStoreProvider><Harness onReady={(s) => { store = s; }} /></ToolStoreProvider>);
       let added!: ReturnType<typeof store.addTool>;
       act(() => { added = store.addTool({ text: 'Google Translate Chrome extension' }); });
       const edges = store.edgesFor(added.id);
       expect(edges.some((e) => e.toId === 'google' && e.kind === 'extension-of')).toBe(true);
       expect(edges.some((e) => e.toId === 'elevenlabs')).toBe(false);
     });
   });
   ```

   > Assumes P8 seeded a `google` tool. If not yet present, the test adds it
   > via `store.addTool({ text: 'google.com' })` before the extension.

2. **Run** `npm run test -- store.relationships` → fails.

3. **Minimal impl**:

   In `toolStoreContext.ts` extend the shape and store API:

   ```ts
   import type { InferredEdge } from '../lib/relationship-intelligence.types';
   // AddedTool gains: inferredEdges?: InferredEdge[];
   // ToolStore gains: edgesFor: (id: string) => InferredEdge[];
   ```

   In `store.tsx` `addTool`, after building `tool`, compute edges against the
   current universe and the P0 knowledge lookup:

   ```ts
   import { inferRelationships } from '../lib/relationship-intelligence';
   import { knowledgeFor } from './knowledge';
   // …
   const inferredEdges = inferRelationships(tool, [...seedTools, ...added], knowledgeFor);
   const stored: AddedTool = { ...tool, inferredEdges };
   ```

   Add an `edgesFor` selector to the memoised store value:

   ```ts
   const edgesFor = useCallback(
     (id: string) => toolById.get(id)?.inferredEdges ?? [],
     [toolById],
   );
   ```

4. **Run** `npm run test -- store.relationships` and `npm run test` → all pass.

5. **Commit**: `git add src/playground/toolStoreContext.ts src/playground/store.tsx src/playground/store.relationships.test.tsx && git commit -m "P9: attach inferred edges to added tools in the web store"`.

---

## Task 4 — Web detail window: "Connected because …"

Promote the `ConnectionChip` in `ToolDetail.tsx` to show the edge reason +
confidence for inferred edges, tappable to reveal the full reason. Keep the
existing `relationIds` chips for tools with no inferred edge.

**Files**
- **Create** `/tmp/wt-ios/src/playground/relationshipReason.ts` (pure formatter)
- **Create** `/tmp/wt-ios/src/playground/relationshipReason.test.ts`
- **Modify** `/tmp/wt-ios/src/playground/ToolDetail.tsx`

### Steps

1. **Write the failing test** `relationshipReason.test.ts`:

   ```ts
   import { describe, expect, it } from 'vitest';
   import { connectedBecause } from './relationshipReason';

   describe('connectedBecause', () => {
     it('renders a kind label + reason + percent confidence', () => {
       expect(connectedBecause({
         fromId: 'x', toId: 'google', kind: 'extension-of',
         reason: 'It is an extension/add-on built for Google.', confidence: 0.82,
       })).toBe('Extension of · It is an extension/add-on built for Google. (82%)');
     });
   });
   ```

2. **Run** `npm run test -- relationshipReason` → fails.

3. **Minimal impl** `relationshipReason.ts`:

   ```ts
   import type { InferredEdge, RelationKind } from '../lib/relationship-intelligence.types';

   const LABEL: Record<RelationKind, string> = {
     'extension-of': 'Extension of',
     'integrates-with': 'Integrates with',
     'same-vendor': 'Same vendor',
     'data-flows-to': 'Feeds into',
     'alternative-to': 'Alternative to',
   };

   export const connectedBecause = (edge: InferredEdge): string =>
     `${LABEL[edge.kind]} · ${edge.reason} (${Math.round(edge.confidence * 100)}%)`;
   ```

4. **Run** `npm run test -- relationshipReason` → passes. Then wire into
   `ToolDetail.tsx`: in the `ToolDetail` wrapper resolve `edgesFor(tool.id)`
   from the store; pass an `edgeByToId: Map<string, InferredEdge>` into
   `ToolDetailView`. In `ConnectionChip`, when an edge exists, add a
   long-press/tap reveal (reuse the existing `tap()` haptic + `data-no-drag`)
   that expands a one-line `connectedBecause(edge)` caption under the chip,
   transitioned with `DURATION.enter`/`EASE.out` and skipped under `reduce`.
   Section title stays `Connected to · N`. No layout-thrash: the caption uses a
   `max-height` transition, not a remount.

5. **Run** `npm run test` → green.

6. **Commit**: `git add src/playground/relationshipReason.ts src/playground/relationshipReason.test.ts src/playground/ToolDetail.tsx && git commit -m "P9: web detail window shows Connected because + confidence"`.

---

## Task 5 — Web ConnectionLines: draw inferred edges by confidence

Render inferred edges as `QuadraticBezierLine`s whose opacity/width scale with
`confidence`, alongside the existing curated `links`. Reuse the existing
opacity/width logic; **no per-frame relayout** — line data stays in the same
`useMemo` keyed on the same inputs plus the edge list.

**Files**
- **Create** `/tmp/wt-ios/src/components/AIToolUniverse3D/inferredLineData.ts` (pure)
- **Create** `/tmp/wt-ios/src/components/AIToolUniverse3D/inferredLineData.test.ts`
- **Modify** `/tmp/wt-ios/src/components/AIToolUniverse3D/ConnectionLines.tsx`

### Steps

1. **Write the failing test** `inferredLineData.test.ts` — confidence maps
   monotonically to opacity, and endpoints with no position are dropped:

   ```ts
   import { describe, expect, it } from 'vitest';
   import { buildInferredLineData } from './inferredLineData';

   const pos = new Map<string, [number, number, number]>([
     ['a', [0, 0, 0]], ['b', [1, 0, 0]],
   ]);

   describe('buildInferredLineData', () => {
     it('higher confidence → higher opacity', () => {
       const lo = buildInferredLineData([{ fromId: 'a', toId: 'b', kind: 'alternative-to', reason: 'x', confidence: 0.45 }], pos);
       const hi = buildInferredLineData([{ fromId: 'a', toId: 'b', kind: 'extension-of', reason: 'x', confidence: 0.9 }], pos);
       expect(hi[0].opacity).toBeGreaterThan(lo[0].opacity);
     });

     it('drops edges whose endpoints have no position', () => {
       const out = buildInferredLineData([{ fromId: 'a', toId: 'ghost', kind: 'integrates-with', reason: 'x', confidence: 0.8 }], pos);
       expect(out).toEqual([]);
     });
   });
   ```

2. **Run** `npm run test -- inferredLineData` → fails.

3. **Minimal impl** `inferredLineData.ts`:

   ```ts
   import type { InferredEdge } from '../../lib/relationship-intelligence.types';

   export interface InferredLine {
     edge: InferredEdge;
     start: [number, number, number];
     end: [number, number, number];
     opacity: number;
     lineWidth: number;
   }

   export function buildInferredLineData(
     edges: InferredEdge[],
     positionById: Map<string, [number, number, number]>,
   ): InferredLine[] {
     return edges.flatMap((edge) => {
       const start = positionById.get(edge.fromId);
       const end = positionById.get(edge.toId);
       if (!start || !end) return [];
       const opacity = 0.12 + edge.confidence * 0.5; // 0.12–0.62
       const lineWidth = 0.4 + edge.confidence * 1.1;
       return [{ edge, start, end, opacity, lineWidth }];
     });
   }
   ```

4. **Run** `npm run test -- inferredLineData` → passes. Then in
   `ConnectionLines.tsx`: accept an optional `inferredEdges: InferredEdge[]`
   prop, compute `buildInferredLineData(inferredEdges, positionById)` inside the
   existing `useMemo` (add `inferredEdges` to the deps array), and render those
   lines after the curated ones with `color="#c9b4ff"` (distinct from curated
   blue) so inferred edges read as "intelligence". Lines are static geometry —
   no `useFrame`, so the 60fps / no-postprocessing constraints hold.

5. **Run** `npm run test` → green.

6. **Commit**: `git add src/components/AIToolUniverse3D/inferredLineData.ts src/components/AIToolUniverse3D/inferredLineData.test.ts src/components/AIToolUniverse3D/ConnectionLines.tsx && git commit -m "P9: render inferred edges in web ConnectionLines, opacity by confidence"`.

---

## Task 6 — iOS shared engine (parity) + cross-lane fixtures

Mirror `inferRelationships` in Swift so iOS infers the same edges. Pure
Foundation only (no RealityKit) → unit-testable in `MyAIMapTests`. Assert
against a **shared fixture JSON** committed once and read by both lanes.

**Files**
- **Create** `/tmp/wt-ios/src/lib/relationship-fixtures.json` (shared expectations)
- **Create** `/tmp/wt-ios/src/lib/relationship-fixtures.test.ts` (web side asserts engine == fixtures)
- **Create** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Resources/relationship-fixtures.json` (byte-identical copy)
- **Create** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/RelationshipIntelligence.swift`
- **Create** `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/RelationshipIntelligenceTests.swift`

### Steps

1. **Author the fixture** `src/lib/relationship-fixtures.json` — a tiny universe
   plus expected edges for the three contract cases:

   ```json
   {
     "universe": [
       { "id": "google", "name": "Google", "category": "research", "stage": "research", "orbit": 1, "angle": 0, "logoDomain": "google.com", "relationIds": [] },
       { "id": "cursor", "name": "Cursor", "category": "coding", "stage": "execution", "orbit": 1, "angle": 0, "logoDomain": "cursor.com", "relationIds": [] },
       { "id": "figma", "name": "Figma", "category": "design", "stage": "planning", "orbit": 1, "angle": 0, "logoDomain": "figma.com", "relationIds": [] }
     ],
     "cases": [
       { "candidate": { "id": "g-ext", "name": "Google Translate Chrome extension", "category": "research", "stage": "research", "summary": "A Chrome extension for Google.", "orbit": 2, "angle": 0, "relationIds": [] },
         "expect": [{ "toId": "google", "kind": "extension-of" }], "forbid": ["figma"] },
       { "candidate": { "id": "windsurf", "name": "Windsurf", "category": "coding", "stage": "execution", "summary": "", "orbit": 2, "angle": 0, "relationIds": [] },
         "expect": [{ "toId": "cursor", "kind": "alternative-to" }], "forbid": ["google"] }
     ]
   }
   ```

2. **Write the failing web test** `relationship-fixtures.test.ts` — loads the
   fixture, runs `inferRelationships` per case, asserts every `expect` edge is
   present with the right kind and every `forbid` id is absent:

   ```ts
   import { describe, expect, it } from 'vitest';
   import type { AITool } from '../data/ai-tool-universe';
   import { inferRelationships } from './relationship-intelligence';
   import fixtures from './relationship-fixtures.json';

   describe('relationship fixtures (cross-lane contract)', () => {
     const universe = fixtures.universe as AITool[];
     for (const c of fixtures.cases) {
       it(`case ${c.candidate.id}`, () => {
         const edges = inferRelationships(c.candidate as AITool, universe);
         for (const e of c.expect) {
           expect(edges.find((x) => x.toId === e.toId)?.kind).toBe(e.kind);
         }
         for (const id of c.forbid ?? []) {
           expect(edges.some((x) => x.toId === id)).toBe(false);
         }
       });
     }
   });
   ```

3. **Run** `npm run test -- relationship-fixtures` → passes (engine already exists).
   Copy the fixture byte-identically into the iOS Resources dir; add the copy to
   `scripts/ios-verify.sh`'s `diff -q` parity check (same pattern as the seed /
   `knowledge.json`).

4. **Write the failing Swift test** `RelationshipIntelligenceTests.swift`:

   ```swift
   import Testing
   import Foundation
   @testable import MyAIMap

   @Suite("RelationshipIntelligence — pinpoint, explained edges")
   struct RelationshipIntelligenceTests {

       @Test func chromeExtensionLinksToGoogleNotUnrelated() {
           let universe = RelationshipFixtures.universe
           let cand = RelationshipFixtures.candidate("g-ext")
           let edges = RelationshipIntelligence.infer(candidate: cand, universe: universe)
           let toGoogle = edges.first { $0.toId == "google" }
           #expect(toGoogle?.kind == .extensionOf)
           #expect(!edges.contains { $0.toId == "figma" })
       }

       @Test func sameCategoryPeerIsAlternativeTo() {
           let edges = RelationshipIntelligence.infer(
               candidate: RelationshipFixtures.candidate("windsurf"),
               universe: RelationshipFixtures.universe)
           #expect(edges.first { $0.toId == "cursor" }?.kind == .alternativeTo)
       }

       @Test func hubDoesNotOverConnect() {
           let cand = RelationshipFixtures.tool(id: "google", name: "Google", category: .research, stage: .research)
           let many = [cand] + (0..<30).map {
               RelationshipFixtures.tool(id: "coder-\($0)", name: "Coder \($0)", category: .coding, stage: .execution)
           }
           let edges = RelationshipIntelligence.infer(candidate: cand, universe: many)
           #expect(edges.count <= 12)
           #expect(!edges.contains { $0.toId == "coder-0" })
       }
   }
   ```

   > `RelationshipFixtures` is a tiny test helper that decodes
   > `relationship-fixtures.json` via the `UniverseSeed.BundleToken` pattern.

5. **Run** `bash scripts/ios-verify.sh --test-build-only` then the suite → fails.

6. **Minimal impl** `RelationshipIntelligence.swift` — port Task 2 rule-for-rule.
   Same thresholds (`confidenceThreshold = 0.4`, `maxEdgesPerKind = 4`), same
   `RelationKind` cases (`extensionOf`, `integratesWith`, `sameVendor`,
   `dataFlowsTo`, `alternativeTo`), same scoring order, same deterministic sort:

   ```swift
   import Foundation

   enum RelationKind: String, Codable, Sendable, CaseIterable {
       case extensionOf = "extension-of"
       case integratesWith = "integrates-with"
       case sameVendor = "same-vendor"
       case dataFlowsTo = "data-flows-to"
       case alternativeTo = "alternative-to"
   }

   struct InferredEdge: Codable, Sendable, Equatable {
       let fromId: String
       let toId: String
       let kind: RelationKind
       let reason: String
       let confidence: Double
   }

   enum RelationshipIntelligence {
       static let confidenceThreshold = 0.4
       static let maxEdgesPerKind = 4
       private static let stageOrder: [WorkflowStageId] = [.research, .planning, .execution, .approval, .review]

       static func infer(candidate: Tool, universe: [Tool], knowledge: KnowledgeStore? = nil) -> [InferredEdge] {
           let text = haystack(candidate, knowledge?.knowledge(for: candidate.id))
           let scored = universe
               .filter { $0.id != candidate.id }
               .compactMap { target -> InferredEdge? in
                   guard let s = score(candidate, target, text) else { return nil }
                   guard s.confidence >= confidenceThreshold else { return nil }
                   return InferredEdge(fromId: candidate.id, toId: target.id,
                                       kind: s.kind, reason: s.reason, confidence: s.confidence)
               }
           // Cap per kind (stops hub over-connect), then deterministic sort.
           var byKind: [RelationKind: [InferredEdge]] = [:]
           for e in scored { byKind[e.kind, default: []].append(e) }
           var capped: [InferredEdge] = []
           for (_, var list) in byKind {
               list.sort { $0.confidence > $1.confidence || ($0.confidence == $1.confidence && $0.toId < $1.toId) }
               capped.append(contentsOf: list.prefix(maxEdgesPerKind))
           }
           return capped.sorted {
               if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
               if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
               return $0.toId < $1.toId
           }
       }

       // score(_:_:_:), haystack(_:_:), nameTokens(_:), registrable(_:) mirror the TS rules.
   }
   ```

7. **Run** the Swift suite via `scripts/ios-verify.sh` → passes; `diff -q` parity check green.

8. **Commit**: `git add src/lib/relationship-fixtures.json src/lib/relationship-fixtures.test.ts ios-app/Sources/MyAIMap/Resources/relationship-fixtures.json ios-app/Sources/MyAIMap/Data/RelationshipIntelligence.swift ios-app/Tests/MyAIMapTests/RelationshipIntelligenceTests.swift scripts/ios-verify.sh && git commit -m "P9: iOS inference engine at parity + shared cross-lane fixtures"`.

---

## Task 7 — iOS render + detail "Connected because …"

Surface inferred edges in `UniverseViewModel`, draw them via the existing
`UniverseView.makeLink` (confidence → material alpha), and show
"Connected because …" in `ToolDetailSection`, with `BrandHaptics` on tap and a
`PressBounce` reveal that honours Reduce Motion.

**Files**
- **Modify** `/tmp/wt-ios/ios-app/Sources/MyAIMap/State/UniverseViewModel.swift` (expose `inferredEdges(for:)`)
- **Modify** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Universe/UniverseView.swift` (draw inferred links)
- **Modify** `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift` (reason captions)
- **Create** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/RelationshipReason.swift` (pure formatter)
- **Create** `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/RelationshipReasonTests.swift`

### Steps

1. **Write the failing test** `RelationshipReasonTests.swift`:

   ```swift
   import Testing
   @testable import MyAIMap

   @Suite("RelationshipReason — Connected because copy")
   struct RelationshipReasonTests {
       @Test func formatsLabelReasonAndPercent() {
           let edge = InferredEdge(fromId: "x", toId: "google", kind: .extensionOf,
                                   reason: "It is an extension/add-on built for Google.", confidence: 0.82)
           #expect(RelationshipReason.connectedBecause(edge)
               == "Extension of · It is an extension/add-on built for Google. (82%)")
       }
   }
   ```

2. **Run** `bash scripts/ios-verify.sh --test-build-only` + suite → fails.

3. **Minimal impl** `RelationshipReason.swift`:

   ```swift
   enum RelationshipReason {
       static func label(_ kind: RelationKind) -> String {
           switch kind {
           case .extensionOf: return "Extension of"
           case .integratesWith: return "Integrates with"
           case .sameVendor: return "Same vendor"
           case .dataFlowsTo: return "Feeds into"
           case .alternativeTo: return "Alternative to"
           }
       }
       static func connectedBecause(_ edge: InferredEdge) -> String {
           "\(label(edge.kind)) · \(edge.reason) (\(Int((edge.confidence * 100).rounded()))%)"
       }
   }
   ```

4. **Run** suite → passes. Then:
   - `UniverseViewModel`: add `inferredEdges(for id: String) -> [InferredEdge]`
     computed via `RelationshipIntelligence.infer` over `UniverseSeed.tools`
     (+ user-added), memoised in a `[String: [InferredEdge]]` cache keyed by id
     so it is **not** recomputed per frame.
   - `UniverseView`: in the link-building pass (near the existing `makeLink`
     calls, lines ~78/128), add an inferred-edge loop that calls `makeLink` with
     `thickness` and material alpha derived from `edge.confidence` and a distinct
     tint (mirror the web `#c9b4ff`). Static geometry, no `useFrame`/per-frame
     work — `60fps`, no postprocessing.
   - `ToolDetailSection`: under the existing `CONNECTED TO` rail (line ~107),
     render `RelationshipReason.connectedBecause(edge)` for any chip that has an
     inferred edge; tap fires `BrandHaptics`, expands the caption with
     `PressBounce`/`BrandMotion`, gated on `accessibilityReduceMotion`.

5. **Run** `bash scripts/ios-verify.sh` (build + tests) → green.

6. **Commit**: `git add ios-app/Sources/MyAIMap/State/UniverseViewModel.swift ios-app/Sources/MyAIMap/Universe/UniverseView.swift ios-app/Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift ios-app/Sources/MyAIMap/Data/RelationshipReason.swift ios-app/Tests/MyAIMapTests/RelationshipReasonTests.swift && git commit -m "P9: iOS draws inferred edges + Connected because in detail sheet"`.

---

## Verification checklist (run before finishing the branch)

- `npm run test` → all web suites green (types, engine, store, reason, lines, fixtures).
- `bash scripts/ios-verify.sh` → builds + all Swift suites green, `diff -q` parity on `relationship-fixtures.json`.
- Contract spot-checks hold on both lanes: Chrome-extension→`google` only;
  hub capped (`≤ 12` edges); same-category peers `alternative-to`.
- Manual: add a tool in the web playground → detail window shows
  "Connected because …" with a percent; inferred lines render in violet and
  fade by confidence; no frame drops while orbiting (no per-frame relayout).
