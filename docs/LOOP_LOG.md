# Loop Log

Append-only. One entry per task attempt. Newest at bottom.

Schema:

```
## [ID] Title
- status: pending | in_progress | done | skipped | reverted
- started: ISO-8601 (added when in_progress)
- finished: ISO-8601 (added when done/skipped/reverted)
- commit: short-sha (added when done)
- notes: free text, especially for skip/revert reasons
```

---

## [A1] Camera over-zoom
- status: done
- commit: add70d5
- notes: cameraY/Z offsets pushed (node 3.5/11.2 → 5.0/15.5; pocket 5.25/16.4 → 6.8/19.0). minDistance 5.5 → 7.5, maxDistance 42 → 46.

## [A2] Right-panel empty
- status: done
- commit: 2ef900f
- notes: removed `key={selectedTool.id}` from tool-detail `<article>`. Animation now plays once on initial mount, content swaps in place. No more interrupted-mid-fade empty state.

## [A3] DOM overlay overlap
- status: done
- commit: 69dc2c4
- notes: section now flex-col on mobile; canvas wrapped in flex-1 div (min-h 440); lens flows below it (relative). On lg reverts to absolute pinned at bottom. Eliminates lens covering canvas / overlapping right panel on small viewports.

## [B1] Zoom-distance trigger for pocket
- status: done
- commit: 5311eae
- notes: new ProximityCategoryWatcher polls camera distance ~6Hz; when nearest non-core category anchor is within 11 units AND activeCategory='all', auto-calls onSelectCategory. 1.4s cooldown prevents flicker. Auto-exit deferred to B3.

## [B2] Pocket breathing room layout
- status: done
- commit: fe48935
- notes: POCKET_ORBIT_RADII [2.05/3.36/4.82] → [2.9/4.6/6.4], POCKET_WORLD_RADIUS 5.32 → 7.0. pocketToolPosition switched from fan/lane layout to Fibonacci-sphere (golden-angle) distribution blended 22% with tool's own angle. ConnectionLines: bothInPocket opacity 0.18→0.32 (0.5 in lens), lineWidth 0.92→1.18 (1.6 in lens); selected-pocket line opacity 0.76→0.86 lineWidth 2.2→2.6. Intra-pocket relations now read clearly.

## [B3] Pocket exit affordance
- status: done
- notes: layered Escape (pocket first, dialog second). ProximityCategoryWatcher extended w/ onExit + exitDistance=22; once activeCategory open and camera distance to its anchor > 22, auto-exits via onSelectCategory('all'). Enter 11 < exit 22 gives hysteresis.

## [C1] Connection-line clarity
- status: pending

## [C2] Mobile right panel bottom sheet
- status: pending

## [C3] Search camera focus
- status: pending

## [D1] Tool data to JSON
- status: pending

## [D2] Vite manualChunks split
- status: pending

## [D3] Relation confidence field
- status: pending

## [E1] Playwright responsive snapshots
- status: pending

## [E2] Lighthouse Core Web Vitals
- status: pending
