# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
loosely tracks the semver spirit (no public API yet, so minor bumps reflect
behavioural milestones).

## [Unreleased]

### Added
- `CHANGELOG.md` introduced.
- `.agent/INSTRUCTIONS.md` Project Context filled with stack, commands,
  architecture map, invariants, keyboard shortcuts, and Lighthouse budget.
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) running
  typecheck, lint, unit tests, and production build on PRs and pushes
  to `main`.

### Removed
- Obsolete root docs (`CLAUDE_CODE_CONTINUE.md`, `GAMEPLAN.md`,
  `POLISH_PLAN.md`). Their content is superseded by
  `.agent/INSTRUCTIONS.md` + `docs/LOOP_PLAN.md` + `docs/LOOP_LOG.md`.

## [0.4.0] — 2026-06-02

Polish-and-perf sprint plus lens slim down + hover stability.

### Added
- **Auto-pocket reveal (B1).** Camera dolly within ~11 world units of a
  category anchor opens its pocket world; pulling past ~22 units closes
  it (hysteresis). Powered by a non-rendering `useFrame` watcher.
- **Layered Escape (B3).** Esc first exits a pocket; only when already
  in the all-groups view does it close the full dialog.
- **Map-clarity hotkeys.** `F` focus, `C` context, `A` atlas (skipped
  while typing or with modifiers held).
- **Search → focus.** Enter in the search input focuses the first match.
- **Relation confidence field.** Optional `confidence` on
  `UniverseLink`. Right-panel pills show a fuchsia badge when set.
- **Universe lens hint.** Cyan one-liner that swaps copy in/out of a
  pocket world to teach the new gesture.
- **CategoryRing proximity glow (F3).** Ring core brightens as the
  camera approaches its anchor, peaking just under the auto-enter
  threshold.
- **Lighthouse snapshot** in `docs/perf.md`.

### Changed
- **Fibonacci-sphere pocket layout (B2).** `POCKET_ORBIT_RADII`
  2.05 / 3.36 / 4.82 → 2.9 / 4.6 / 6.4. `POCKET_WORLD_RADIUS` 5.32 →
  7.0. Tools spread across a sphere via the golden-angle spiral
  instead of stacking on three Y-lanes.
- **Universe lens slimmed.** Dropped the relation-lens 2 × 4 and
  clarity 1 × 3 grids (duplicates); tightened category chips and stage
  cards. Bar is ~45 % shorter on mobile.
- **Hover stability.** `hoveredToolId` lives in `Scene` only;
  `ToolNode` receives `hovered` as a prop. Eliminates flicker when
  the cursor crosses pixel-close nodes. Hover-out debounce
  180 ms → 320 ms.
- **Camera offsets.** Node-view 3.5 / 11.2 → 5.0 / 15.5; pocket-view
  5.25 / 16.4 → 6.8 / 19.0. `minDistance` 5.5 → 7.5, `maxDistance`
  42 → 46.
- **Mobile layout.** Universe lens stacks below the canvas on mobile
  instead of overlaying it; right tool-detail panel becomes a sticky
  bottom sheet (`max-h-[60vh]`).
- **Tool detail card** no longer remounts on every selection.
- **Bundle split.** `manualChunks` carves out `three-core` (723 kB)
  and `three-r3f` (425 kB) as vendor chunks; initial `index` chunk
  shrinks ~246 kB → 57 kB.
- **Shared geometries.** Three `SphereGeometry` constants reused
  across every `ToolNode` instead of allocating ~3 × N per mount.
- **Ambient layers lazy-mount.** `StarField` + `GalaxyDust` deferred
  to `requestIdleCallback`. **Lighthouse TBT collapsed
  10.4 s → 0.84 s.**

### Fixed
- Right-panel could flash empty during rapid selection (CSS animation
  + `key={selectedTool.id}` remount race).
- DOM overlay overlap on mobile when the floating Universe lens
  covered the canvas.

## [0.3.0] — Cluster inspector + Logo.dev + classifier confidence

### Added
- Cluster inspector + lens-aware panels in the right column.
- Live classification preview, focus trap, JSON import/export
  validation, `localStorage` persistence for custom tools.
- `ToolLogo` + `src/lib/tool-logos.ts`: Logo.dev publishable-key URL
  generation with SVG monogram fallback, plus unit tests.
- 3D scene legibility pass — cosmic field depth, `PocketWorldShell`,
  selective labels, multi-mode relation lens (direct / adjacent /
  stage / category).
- `vercel.json` and `.env.example` for the Logo.dev key.

## [0.1.0] — Initial release

- Cosmic galaxy visualisation with `Founder OS` core node, category
  rings, rule-based classifier intake, and the data-first structure
  under `src/data/ai-tool-universe.ts`.

[Unreleased]: https://github.com/ilia770/ai-tool-universe-map/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/ilia770/ai-tool-universe-map/releases/tag/v0.4.0
[0.3.0]: https://github.com/ilia770/ai-tool-universe-map/releases/tag/v0.3.0
[0.1.0]: https://github.com/ilia770/ai-tool-universe-map/releases/tag/v0.1.0
