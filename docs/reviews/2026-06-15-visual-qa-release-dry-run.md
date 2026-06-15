# Visual QA rubric run + release dry run — 2026-06-15

Backlog 48 (visual QA) + 50 (release dry run). Owner: Claude Code.
Captured live: web via dev server + Chrome DevTools at desktop/tablet/mobile
widths and an open pocket; iOS via the app launched on ClaudeGate
(`4E244EB6-…`, iPhone 16 Pro, iOS 26.5) and `simctl io screenshot`.
Screenshots are local-only under `.agent/tmp/` (not committed).

## Rubric scores (`docs/design/README.md` → Design QA Rubric)

Release target: no area below 4.

| Area | Web | iOS | Notes |
| --- | --- | --- | --- |
| Orientation | 5 | 5 | Header breadcrumb, universe lens ("Pocket world · Coding · 11 tools"), highlighted category, reset/recenter. |
| Readability | 4.5 | 4.5 | Pocket + selected labels legible; overview cluster is tight (tools read on hover/pocket). iOS category labels always-on. |
| Interaction | 4.5 | n/a | Category click opens pocket world smoothly; selection drives the detail panel. iOS gesture feel is device-only. |
| Visual Premium | 5 | 5 | Cosmic skybox, glass panels, pocket-shell glow, glossy IBL spheres — app-store-worthy both platforms. |
| Information | 5 | 4.5 | Rich detail: what it does, map position, workflow stage, connected-because + Open. |
| Mobile | 4.5 | native | Header collapses, scene fills, bottom lens/sheet pattern. |

**All areas ≥ 4 → release target met on both platforms.**

## What the screenshots confirm live

- iOS: cosmic **skybox** (#76), billboarded **category labels** (#64),
  **star field** (#69), **orbit rings + connection lines** (#68/#70),
  **founder core hero** (#70), glossy **IBL** spheres (#72), search dock +
  detail sheet. Phase C visual batch is all live and coherent.
- Web: overview depth (stars + dust), pocket-world shell + ring on category
  open, labeled pocket tools, full detail panel with Open + connected-because.

## Findings (all P3, non-blocking — filed for polish)

1. **Web overview density** — at overview the node cluster is small/centered
   and individual tools are unreadable until hover/pocket. By design, but
   borderline on Readability; consider a gentle overview spread or always-on
   category labels (iOS already does this). Lane: `AIToolUniverse3D/**`.
2. **Web tablet portrait vertical centering** — scene sits above centre,
   leaving an empty band above the lens bar at ~820×1180. Lane:
   `AIToolUniverse3D/**` (camera framing) — verify it isn't a Codex-owned
   layout concern first.
3. **iOS edge-label clipping** — category labels near the frame edge
   ("Media", "Research") clip slightly off-screen-right at overview. Lane:
   `ios-app/**` — clamp label X or pull the overview camera back a touch.

No P1/P2 visual blockers.

## Release dry run (backlog 50)

`scripts/release-check.sh` — **green**:

- `tsc -b && vite build` clean.
- Bundle-size budget: all chunks within limits
  (`three-core` 178.0 kB gz < 205, `three-r3f` 124.9 < 155,
  `AIToolUniverse3D` lazy chunk 8.6 < 12, `index` 17.9 < 25).

iOS: full `xcodebuild test` green on ClaudeGate (142 tests); iOS CI
(`ios.yml`, Xcode 16.4) green on main.

### Stop-ship check (`docs/RELEASE_REVIEW.md` spirit)

- 3D canvas blank? No — renders on web + iOS.
- Major text overlap / tool details disappear / category focus trap? No.
- Lazy-load + bundle invariants intact? Yes (3D chunk lazy, budgets OK).

**No stop-ship items.** Pending before an actual TestFlight/prod push:
the 3 P3 polish findings (optional), iOS on-device gesture pass, and the
web clearcoat parity PR (#79) visual sign-off.
