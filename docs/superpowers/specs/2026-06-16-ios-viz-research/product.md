# iOS "My AI Map" — Product / Core-Loop Review

Lens: product lead. Date: 2026-06-16. Read-only audit of the SwiftUI/RealityKit app at `/tmp/wt-ios/ios-app/`.

## The job-to-be-done

Per `docs/PRODUCT_CTO.md`, the North Star is "a premium interactive universe for understanding an AI tool ecosystem… help a founder see which tools exist, why they matter, how they connect." That is two distinct jobs fighting for the home screen:

1. **Browse/understand** the ecosystem (the cosmic map is great at this — exploratory, spatial, "what exists").
2. **Find the right tool FAST** (a directory job — query in, answer out).

Today the app bets the entire home screen on job #1 (the 3D universe is the hero) and bolts job #2 on as floating chrome over it. With **49 tools across 9 categories** (`src/data/ai-tool-universe.seed.json`), the dataset is small enough that "find fast" should be trivially solved — yet it is the weakest, most buried part of the surface.

## Verdict (opinionated)

**The 3D map should NOT be the hero of the default screen. It should be a deliberate, secondary "explore" mode behind an instant search/list-first home.** The map is a beautiful brand/marketing artifact and a genuinely nice "wander the ecosystem" mode, but it is a slow, imprecise, GPU-heavy way to answer "which tool do I use to X?" — which is the only job with real recurring utility for a 49-item set. Right now every core action (search, chat, history, category nav, detail sheet) is stacked as translucent glass layers ON TOP of a 3D scene the user must mentally see around. That is the root of "looks terrible / buttons don't work / cluttered": six surfaces competing for one screen.

Lead with find. Keep the universe as the signature "Explore" tab. This also fixes 80% of the visual complaints for free, because the find surface stops being a HUD floating over a crooked starfield.

## Current surfaces and where the loop breaks

Source map for the home screen (`Universe/UniverseScreen.swift`): header (sparkles + tool count + account) → `SearchDock` → `HistoryStrip` ("Recently added") → `PocketReadout` → `ChatDock` (conditionally) → `CategoryRail`, all `ZStack`-ed over `UniverseView` (RealityKit). The tool detail is a permanent bottom sheet (`RootSheet` → `ToolDetailSection`).

There are **two separate find mechanisms** doing nearly the same job:

- **SearchDock** (`UI/Search/SearchDock.swift` + `SearchCore.swift`) — literal substring search, capped at 6, name-prefix > name > summary > category. Collapsed capsule, grows a results card. Solid, fast, on-device.
- **ChatDock** (`UI/Chat/ChatDock.swift` + `QueryEngine.swift`) — "ask the map" NL ranker (tokenize → stopwords → category hints → score), returns a one-line answer + match cards.

This is **redundant and confusing** — two text fields that both take a query and both surface tool cards. It's a direct port of the web's `FindBar` + search, but on a phone, two stacked composers is friction, not power.

### Friction inventory (prioritized)

| # | Problem | Where | Impact |
|---|---------|-------|--------|
| P0 | **Two competing query inputs** (SearchDock + ChatDock) on one screen. User can't tell which to use; they do the same thing. | `SearchDock.swift`, `ChatDock.swift` | High — splits the core loop, doubles clutter |
| P0 | **Find is a HUD over 3D**, not the primary surface. Results cards render as glass over a moving starfield → low contrast, "messy." | `UniverseScreen.canvas` ZStack | High — this is most of the "looks terrible" complaint |
| P0 | **No add-tool flow exists on iOS at all.** Copy promises it ("Try the **+** button to add one — the classifier will place it" in `QueryEngine.swift:91`) and haptics ship a `classifySuccess` pattern, but there is **no + button anywhere** (`grep` confirms). The web has a full `AddToolModal` with classifier + logo paste. **Dead-end promise = broken button.** | `QueryEngine.swift`, missing `AddToolModal` | High — promised feature absent; likely a "button doesn't work" report |
| P1 | **ChatDock is gated off whenever the detail sheet is expanded** (`isPanelActive = sheetDetent != .height(118)`). Since the detail sheet is *always presented* on iPhone, the chat composer vanishes the moment a user opens any tool. The "ask" surface is only available on a pristine, untouched canvas. | `UniverseScreen.swift:17-19,122` | High — explains "chat doesn't work / disappears" |
| P1 | **Chat scroll-to-bottom is fragile.** `scrollTo(last, anchor: .bottom)` fires `onChange(of: turns.map(\.id))`, but the thread is height-capped to 1/3 screen, lives inside a `GeometryReader`+`Spacer`, and the new answer + N match cards can exceed the viewport before layout settles → last card off-screen. | `ChatDock.swift:76-81` | High — matches the reported "chat does not scroll to bottom" bug |
| P1 | **Detail sheet peek detent (118pt) double-duties as a UI mode flag.** Using a presentation detent as the "is a panel active" signal couples unrelated concerns and is why chat appears/disappears unexpectedly. | `UniverseScreen.swift` | Med — fragile, surprising |
| P2 | **Category nav is triple-bound**: `CategoryRail` chips + proximity enter/exit from the 3D camera + tool focus all mutate `activeCategory`. Flying near an orb silently changes your category/selection. Spatial autopilot fights deliberate taps. | `UniverseScreen.focusToolFromMap`, `ProximityCategorySystem` | Med — "I didn't tap that" disorientation |
| P2 | **History strip is mislabeled "Recently added"** but on iOS nothing can be added (no add flow), and it also surfaces *deleted* events with a restore affordance. So a brand-new user sees an empty or confusing strip referencing a capability that doesn't exist. | `HistoryStrip.swift`, `ToolHistory` | Med — confusing empty/again-broken-promise |
| P2 | **Detail sheet is a long scroll of optional sections** (what/killer features/strengths/who-uses/pricing/visible-tools rail/connected rail/open+delete). For a "find fast" loop the most-wanted action — **Open the tool** (its website) — is at the very bottom. | `ToolDetailSection.swift:237` | Med — primary CTA buried |
| P3 | `PocketReadout`, `ClarityMenu` (intentionally hidden), inferred-edge "Connected because…" long-press captions — explainability depth that adds surface area without serving the fast-find loop. | various | Low — YAGNI candidates |

## What to cut (YAGNI)

For the find-fast loop, these are not pulling their weight on a phone:

- **One of the two query inputs.** Merge SearchDock + ChatDock into a single "Find" field (see below). This is the single highest-leverage cut.
- **The "Connected because…" inferred-edge explainer** (`RelationshipReason`, long-press reveal in `ToolDetailSection`). Clever, but it is third-order detail the fast-find user never needs. Demote to "Explore" mode only.
- **PocketReadout / ClarityMenu** as home-screen chrome. ClarityMenu is already disabled (a visible control that does nothing was correctly removed); PocketReadout follows.
- **Proximity-driven category selection** as the *primary* nav. Keep it as map-mode flavor; do not let it mutate selection that the find/list surface reads.
- **Stage badges (Research/Plan/Build/Approve/Review)** front-and-center — useful taxonomy, but not what a user filters by when "finding fast." Secondary.

## What to fix / build (prioritized)

**Now (fixes the reported breakage + the core loop):**

1. **Make Find the home surface.** Default screen = a clean search field + (when empty) a browsable list/grid of tools grouped by category, with recents on top. The 3D universe becomes an explicit **"Explore" tab/mode** (a deliberate destination, not the backdrop). This single move resolves most "looks terrible," "labels gigantic," "lines messy" complaints because the find loop no longer renders over the scene.
2. **Unify search + chat into ONE field.** One composer that does instant substring matches as you type (current `SearchCore`) AND, on submit, runs the NL ranker (`QueryEngine`) for a one-line "use X because Y" answer. Same input, two depths. Kill the second composer.
3. **Fix chat availability + scroll.** Decouple chat visibility from the detail sheet detent; the find/answer surface must persist regardless of what's open. For scroll, anchor the thread to bottom and scroll *after* layout (e.g. scroll on content-size change, not just id change) so the latest answer+cards are always visible.
4. **Either ship Add-Tool or remove its promise.** The classifier + logo flow exists on web (`src/playground/AddToolModal.tsx`) and the iOS haptics/copy already assume it. Add the **+** button + intake sheet (paste a name/URL → classifier places it → it appears in find + history), OR delete the "+ button" copy and the `classifySuccess` dead code until it's real. Today it's a guaranteed broken-button report.

**Next (sharpen the loop):**

5. **Promote "Open <tool>" to the top of detail** (it's the terminal action of find-fast) and make detail a tight card: name, one-line what, pricing one-liner, Open. Push killer-features/strengths/connections below the fold or behind a "More."
6. **Add filters that match real intent**: by category and by pricing (free / freemium / paid) — pricing is already in `knowledge.json` and is a top decision axis for "which tool should I use." Stage filter is lower value.
7. **Fix the history strip story**: relabel to "Recent" (covers opens, not just adds), and only show it once there's genuine recent activity.

**Later (explore mode polish):**

8. Keep the universe gorgeous but scope it to Explore: this is where the 3D-quality work (labels, orbs, lines) pays off without blocking the daily loop. The viz-quality fixes belong there, not on the find path.

## Bottom line

The product has over-invested in spatial *understanding* (a job done a handful of times) and under-invested in *finding* (the job done every session). For 49 tools, find-fast is a solved problem the moment you stop rendering it as a HUD over a 3D scene and stop splitting it across two composers. Recommendation: **search/list-first home, single unified Find field, fix the chat visibility+scroll bugs, ship-or-remove Add-Tool, demote the universe to a first-class "Explore" mode.** That alone converts this from an impressive-but-frustrating demo into a tool a founder actually reaches for.

## Key files
- `/tmp/wt-ios/ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift` — home composition; `isPanelActive` chat gate (L17-19,122)
- `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Search/SearchDock.swift` + `SearchCore.swift` — literal search
- `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Chat/ChatDock.swift` + `UI/Search/QueryEngine.swift` — NL find (redundant w/ search); scroll at L76-81; "+ button" promise at QueryEngine.swift:91
- `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift` — detail; "Open" CTA buried at L237
- `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Search/HistoryStrip.swift` — "Recently added" with no add flow
- `/tmp/wt-ios/ios-app/Sources/MyAIMap/State/UniverseViewModel.swift` — selection/search/history state
- `/tmp/wt-ios/src/playground/AddToolModal.tsx` — the add-tool flow that exists on web but NOT iOS
- `/tmp/wt-ios/src/data/ai-tool-universe.seed.json` — 49 tools, 9 categories, 7 links
