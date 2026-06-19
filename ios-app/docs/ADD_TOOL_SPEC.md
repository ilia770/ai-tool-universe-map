# ADD_TOOL_SPEC

Owner: Claude (state/source-of-truth in `State/UniverseViewModel.swift`) →
Codex (UI in `UI/Settings/AddToolSheet.swift`). **CRITICAL domain — fix first**
(`PRODUCT_FEEDBACK_TRIAGE.md` C-1). Do NOT edit chat, detail, rail here.

## C-1 — added tool must be real everywhere (Critical, root bug)
After Add, the tool MUST be present in: universe map, search, Ask AI, and tool
detail — in the same session, no relaunch. The "PostHog still says does not
exist" bug means a consumer reads a stale or seed-only set.

Root-cause checklist (verify all read the SAME source):
- `model.allTools == customTools`; `visibleAllTools == allTools − hidden`. ✅ exists.
- `addCustomTool` appends to `customTools` + `persist()` + `focusTool(id)`. ✅ exists.
- **Search** (`SearchCore` via `model.searchResults`) must rank over `visibleAllTools` — confirm, not `UniverseSeed.tools`.
- **Ask AI** (`UniverseAssistantCore`) must receive `visibleAllTools` — confirm (`CHAT_AI_SPEC.md`).
- **Map** rebuilds on `visibleAllTools.count` change (`UniverseMapView.onChange`). ✅ exists; confirm a NEW category lights its planet (`PlanetData.makePlanets` skips empty categories).
- **Detail** resolves the selected tool from `visibleAllTools`. ✅.
- **ID collision:** if the user adds a name whose slug equals a sampled tool id
  (e.g. "PostHog" → `posthog` already in the loaded sample), `uniqueID(base:)`
  must produce a distinct id (`posthog-2`) AND the UI must not then claim "does
  not exist" because it searched the typed name against the sample's id. Adding
  a duplicate-name tool should either merge-or-warn (preferred: focus the
  existing one) rather than create a confusing ghost. **Decide + document the
  duplicate-name policy here before implementing.**

Policy (chosen): on Add, if a visible tool already matches by normalized name,
focus the existing tool and skip creating a duplicate (toast: "Already in your
universe"). Otherwise create with a unique id.

## Auto / Manual control (C-2, inverted)
`AddToolSheet.usesAutoBranch` drives a toggle labeled Auto/Manual. The bug:
control reads inverted. Required behavior:
- The control shows the CURRENT mode and a clear way to switch.
- **Tapping "Manual" selects Manual; tapping "Auto" selects Auto** — the tapped
  option becomes the active one (use a 2-segment control, not a single toggle
  whose label is ambiguous). Active segment = highlighted; `usesAutoBranch`
  true ⇔ Auto segment active.
- **Auto:** category derived by classification (below); the category field is
  read-only/hidden.
- **Manual:** user picks the category explicitly (`category` picker shown).

Recommendation: replace the single toggle with an explicit
`Picker(selection:)`/segmented control over `{auto, manual}` so the mapping
can't invert again.

## Classification (Auto)
Auto category uses **name + website + universe context**, not name alone:
- name keywords + website host/path keywords → category vote.
- universe context: bias toward categories that relate to the user's existing
  tools (`relationIds`/co-occurrence) when ambiguous.
- output a `Tool.Classification(confidence, matchedKeywords, reason)` so detail
  can show "Why it belongs". Low confidence (<~0.5) → still file it but flag for
  review (the detail "Why it belongs" reason states it's unverified).
- mirror the web rule engine intent (`src/lib/classify-ai-tool.ts`) — keep a
  pure `ToolClassifier` helper, unit-tested, no view dependency.

## Website handling
- Website optional. If provided, normalize to https (existing `normalizedURL`).
- `logoDomain` = url host → drives the real logo fetch in `TOOL_DETAIL_SPEC.md`.
- Auto classification may fetch nothing network-side for v1 (host-string
  heuristics only); document if/when a metadata fetch is added.

## Post-add behavior
- Persist (`persist()`), record activity (`.added`), and `focusTool(newID)` so
  the map flies to it and detail/selection reflect it immediately.
- The Add sheet dismisses; the new tool's satellite is the selected node.
- If Add was launched from a chat `.add` chip (`CHAT_AI_SPEC.md`), the chip
  flips to `.existing` on success.

## Acceptance criteria
- Add "PostHog" (new) → appears in map, search ("posthog"), Ask AI inventory, and its detail — same session.
- Adding a name matching an existing visible tool focuses the existing one (no ghost).
- Auto/Manual: tapping a segment selects THAT segment; Auto hides category picker, Manual shows it.
- Auto classification reason is shown in detail; low-confidence flagged.
- `ToolClassifier` has unit tests (name-only, name+host, ambiguous→context).

## Manual QA
1. Empty universe → Add a tool → map shows its planet, search finds it, Ask AI counts it.
2. Add a tool with the same name as a sampled one → focuses existing, no duplicate.
3. Toggle Manual → category picker appears and is respected. Toggle Auto → category auto-derived from name+site.
4. Add from a chat "Add" chip → chip becomes "open detail".
