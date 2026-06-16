# Overnight Review — Performance & Weight (playground)

Scope: `src/playground/**` (React 19 + R3F + Tailwind 4). Audited bundle
size, per-frame work, particle/instance budgets, image/icon loading, and
mobile (iOS) heaviness. Reviewer dimension: **performance & weight**.

Measured against the built `dist/` (raw + gzip via `gzip -9`).

---

## Bundle reality (built artifacts)

| chunk | raw | gzip | notes |
| --- | --- | --- | --- |
| `playground-*.js` | 302 KB | 92 KB | **all 15 variants + knowledge data, eagerly bundled** |
| `three-core-*.js` | 723 KB | 182 KB | `three` |
| `three-r3f-*.js` | 626 KB | 196 KB | fiber + drei + postprocessing + camera-controls |
| `playground-*.css` | 0.5 KB | — | tiny (Tailwind JIT) |

Playground first-load JS to interactive = `playground + three-core +
three-r3f` ≈ **1.65 MB raw / ~470 KB gzip**, all parsed/compiled before
a single frame. That is the dominant weight problem for a "top-tier iOS
app" target. (`src-*.js`/`main-*.js`/`AIToolUniverse3D-*.js` belong to
the production `index.html` app, not the playground.)

The good news: the heavy R3F work is genuinely well-engineered at the
scene level (see "What's already good"). The weight problems are
**structural** (what gets shipped/parsed up front), not hot-loop CPU.

---

## Findings (ranked)

### P1 — All 15 viz variants are statically imported → one 302 KB chunk
**File:** `src/playground/PlaygroundApp.tsx:7-21` (imports), `:30-46`
(VARIANTS table holds direct component refs).

Every variant (`BrainGraph … NeuralUniverse`, 544–1629 LOC each) is
`import`ed eagerly and referenced in the `VARIANTS` array, so Rollup
cannot tree-shake any of them. Only one renders at a time (`<Active />`,
line 80), yet a phone downloads, parses, and JIT-compiles all 15 —
plus `knowledge.data.ts` (64 KB source) — on first paint.

This also means every variant's **module-level work runs at import for
all 15**, even the 14 that never mount: e.g.
`NeuralUniverse.tsx:60-71` reads `window.innerWidth` / `matchMedia` and
`:226` builds the `AMBIENT_NODES` array (~340 nodes) in a module IIFE;
`Firefly.tsx`, `Force3D.tsx`, `BloomGraph.tsx` similarly compute layout
constants at import.

**Fix:** lazy-load variants and code-split per variant.
```tsx
import { lazy, Suspense, type ComponentType } from 'react';
const BrainGraph = lazy(() =>
  import('./variants/BrainGraph').then(m => ({ default: m.BrainGraph })));
// …one per variant…
// VARIANTS holds the lazy refs; render inside:
<Suspense fallback={<SceneSkeleton />}><Active /></Suspense>
```
Rollup will emit one chunk per variant. First load drops from "all 15"
to "the active one" — roughly a **10–15× cut** in playground-chunk JS
actually executed at boot (302 KB → ~20–40 KB for one scene + shared
data). Module-level layout IIFEs then run only for the mounted variant.
If the lab must keep instant tab-switching, add `rel="prefetch"` /
idle-prefetch of the *neighbouring* variants after first paint rather
than eager-bundling all.

> Note: the production `index.html` app already lazy-loads its 3D scene
> (CLAUDE.md invariant #4). The playground simply never adopted the same
> pattern — this is the single biggest weight win available here.

### P1 — `three` + drei shipped whole; no scene actually needs all of it
**File:** `vite.config.ts:16-30` (manualChunks), `package.json`
dependencies.

`three-core` (723 KB) + `three-r3f` (626 KB) dominate. drei is pulled
in for a small surface: `Html`, `OrbitControls`, `Billboard`, a couple
of helpers. `@react-three/postprocessing` + `postprocessing` are listed
as chunk inputs (and a dependency) but **no variant uses
EffectComposer/Bloom/DoF** — confirmed by grep: every "bloom" reference
is either a comment, an SVG `filter`, or a shader trick, never the
`postprocessing` package.

**Fixes (in priority order):**
1. **Drop the `@react-three/postprocessing` + `postprocessing` runtime
   dependency** if nothing imports it. Removing it from the dependency
   tree (and the `three-r3f` manualChunks branch) trims the vendor chunk
   and avoids parsing an unused effects pipeline. Verify with
   `grep -rE "postprocessing|EffectComposer" src/` → currently no
   *import* hits, only prose.
2. Import drei helpers by **subpath** where possible (drei is largely
   side-effect-tagged, but confirm `Html`/`OrbitControls`/`Billboard`
   tree-shake; if not, the postprocessing removal is the bigger lever).
3. The `three` core itself is mostly irreducible, but it is the single
   biggest asset — ensure it is served with long-term immutable caching
   and `Cache-Control: immutable` (Vercel does this for hashed assets;
   confirm `vercel.json`). On iOS Safari first-visit this is ~182 KB
   gzip to download + a large parse — a loading state before the Canvas
   mounts will mask it.

### P2 — Brand-logo `<img>` tags have no `loading`/`decoding`/`fetchpriority`
**Files:** `ToolDetail.tsx:277` and `:533`, `AddToolModal.tsx:358`,
`BrainGraph.tsx:453`, `Force3D.tsx:619` (all `<img src={iconUrl}…>`),
fed by `lib/tool-logos.ts` → logo.dev URLs (49 tools).

None of the logo `<img>` elements set `loading="lazy"`,
`decoding="async"`, or `fetchpriority="low"`. In `ToolDetail` the
related-tools list (`cardRelations.map` / `:533`) can render many logos
at once; each is a network round-trip to logo.dev + a main-thread sync
decode. On a phone over cellular this stalls interaction.

**Fix:** add `loading="lazy" decoding="async"` to every brand-logo
`<img>`. For the primary hero logo in `ToolDetail` keep it eager but add
`decoding="async"`. Also request the **smallest sufficient size** — the
hero passes `96` to `getToolLogoUrl` but the in-scene badges
(`BrainGraph` 30 px diameter, `Force3D` similar) should request `~48`,
not 96, to halve bytes and decode cost. Confirm `getToolLogoUrl(tool,
size)` actually forwards `size` to the logo.dev `?size=` param.

### P2 — `dpr={[1, 2]}` caps at 2× on every Canvas (good), but no low-power floor
**Files:** all 12 Canvas mounts (`*.tsx` lines listed below) use
`dpr={[1, 2]}`: `CityMap:687`, `Firefly:1086`, `BrainHub:645`,
`GlobeSwitch:506`, `GalaxyMap:672`, `Organism:1015`, `ForceCloud:587`,
`BrainGraph:1071`, `ObjectSpace:466`, `NeuralNet:734`,
`NeuralUniverse:1117`, `Force3D:1052`.

Capping at 2 is correct (a 3× iPhone would otherwise render ~2.25×
the pixels). But on a thermally-throttled phone even 2× of a
full-screen `100dvh` Canvas with additive-blended particles is heavy.
`NeuralUniverse:1112` already drops `antialias` on `IS_SMALL` — good;
the others don't.

**Fix:** for the **finalists** (A/K/N/O), consider `dpr={[1, IS_SMALL ?
1.5 : 2]}` and `antialias: !IS_SMALL` in `gl`, matching what
NeuralUniverse already does. This is a cheap, large fill-rate win on
phones with no visible quality loss at 1.5× on a Retina panel.

### P3 — `frameloop="always"` on every Canvas; no demand/visibility gating
**Files:** explicit `frameloop="always"` at `BrainHub:647`,
`Firefly:1087`, `BrainGraph:1073`, `GlobeSwitch:505`, `Force3D:1051`,
`GalaxyMap:673`, `NeuralNet:736` (others default to `"always"`).

All scenes run a continuous rAF render even when nothing is interacting
and even when a modal (`AddToolModal`) or `ToolDetail` window fully
covers the scene. `frameloop="always"` is *required* by the ambient
animations (drift/twinkle/pulse), so switching to `"demand"` wholesale
would freeze them (same caveat as production invariant #5). But:

**Fix:** pause the active scene's render loop when it is **occluded** —
when `ToolDetail` (`PlaygroundApp.tsx:96`, full-screen window) or
`AddToolModal` is open the user can't see the Canvas, so keep mounting
it but set `frameloop="never"` (or unmount) while `detailId` /
`addOpen` is truthy. That reclaims 100% of GPU/CPU frame cost during
the most common "reading a tool" state. Also gate on
`document.visibilitychange` (tab backgrounded) — R3F does some of this,
but an explicit pause is safer on iOS Safari.

### P3 — `prefers-reduced-motion` honoured unevenly
**Files:** honoured in `NeuralUniverse.tsx:64`, `Firefly.tsx:1043`,
`BloomGraph.tsx:272`, `Force3D.tsx:28`, `ObjectSpace.tsx:446`,
`Organism` (extend). Several others (`BrainHub`, `GlobeSwitch`,
`GalaxyMap`, `CityMap`, `MetroMap`, `NeuralNet`) do **not** check it.

Reduced-motion isn't only an a11y nicety — on iOS it's a strong "this
device/user wants less work" signal and a free path to drop
autorotate + particle pulsing. **Fix:** in non-finalists this is
optional, but the **finalists (A/K/N/O)** should all respect it (A
`BrainGraph` and K `BloomGraph` already do; verify N `Force3D` and O
`NeuralUniverse` calm autorotate + pulse — both read the flag, good).

---

## What's already good (don't regress these)

- **No real postprocessing pipeline** — bloom/glow are shader/SVG
  tricks, not the `postprocessing` EffectComposer. Avoids the single
  most common R3F mobile killer. (Just remove the now-unused dep.)
- **drei `<Html>` is distance/selection-gated, not per-node-always.**
  - `BrainGraph.tsx:812-825` — labels+badges only for
    selected/neighbour/match/hover (not 49× always).
  - `Force3D.tsx:596` badge gated behind `showIcon` (near/highlighted
    only) with an explicit comment "never instantiate 49+ DOM nodes."
  - `Firefly.tsx:413` maps only `near` nodes (a useFrame distance cull
    builds `near`), not all 49.
  This is the correct pattern; keep it.
- **Force-graph physics (O(n²)) runs once in `useMemo`, not in
  `useFrame`.** `ForceCloud.tsx:146-209` and `Force3D.tsx:239-315` solve
  the layout at build time; the per-frame loops only update geometry
  attributes and are O(n), and the hover recolour is gated behind a
  `lastApplied` ref (`ForceCloud.tsx:405`) so it runs only on hover
  change.
- **Particle budgets are bounded and viewport-scaled.**
  `Firefly.tsx:53-58` caps ambient motes (2.6k phone → 12k desktop
  ceiling) in one shared `THREE.Points` cloud with a shader LOD;
  `NeuralUniverse.tsx:68-71` halves cluster/haze/pulse counts on
  `IS_SMALL`. Instanced meshes used for ambient nodes + edge pulses.
- **No per-frame allocation in the hot loops** — geometry/Float32Arrays
  built in `useMemo`, uniforms/refs mutated in place (Firefly header
  comment is accurate; spot-checked NeuralUniverse, ForceCloud, Force3D).
- **On-device query engine is trivially cheap** — `query.ts` is a token
  ranker over 49 tools; no embeddings/model weight.
- **Bundle guardrail exists** — `scripts/check-bundle-size.mjs` + budgets
  in `vite.config.ts manualChunks`. (Note: its BUDGETS table has no
  `playground-` row, so the 302 KB all-variants chunk is currently
  **unbudgeted** — add a `{ prefix: 'playground-', … }` row so the P1
  regression can't silently re-bloat.)

---

## Recommended order of work

1. **P1 lazy-load variants** (`PlaygroundApp.tsx`) — biggest weight win,
   isolated change, no scene-internal risk.
2. **P1 drop unused `postprocessing` dep** + prune the manualChunks
   branch — trims the vendor chunk, verify with grep first.
3. **P2 `loading="lazy" decoding="async"`** on all logo `<img>` + smaller
   logo.dev size for in-scene badges.
4. **P3 pause `frameloop` when `ToolDetail`/`AddToolModal` occludes the
   Canvas** — large idle-state CPU/GPU win.
5. **P2 lower dpr/antialias floor on phones** for finalists A/K/N/O.
6. Add a `playground-` budget row to `check-bundle-size.mjs`.
