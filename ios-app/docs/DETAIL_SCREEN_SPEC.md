# DETAIL_SCREEN_SPEC

Owner domain: the tool detail card/sheet. Files:
`UI/Sheets/ToolDetailSection.swift`, `UI/Sheets/RootSheet.swift`,
`Universe/PlanetInfoCard.swift`. Do NOT edit chat/input or the rail here.

## Prime directive
A readable product card, **not an admin dashboard**. It explains: what the
tool is, its category, why it matters, what it connects to. Calm, scannable.

## Requirements
- Tool logo with a graceful fallback (SVG monogram / SF Symbol) when no logo
  domain or the image fails. No broken-image boxes.
- The card shows the tool that is currently `selectedTool` in the machine —
  never a stale/different tool than the map highlight.
- `detail` is a primary overlay, mutually exclusive with `chat`
  (see `UI_STATE_MACHINE.md`). Presented from `universeMode == .detail`, not an
  independent boolean that can disagree with the mode.
- Dismiss returns to the previous map mode (`modeBeforeDetail` semantics),
  restoring the same selection.

## State boundary
Detail READS `selectedTool` from the machine. It does not mutate selection
except via an explicit transition (e.g. "focus on map" → `toolSelected`).

## Changed files / QA done / Remaining issues

### Agent 5 — logo fallback + calmer card (landed)

**Changed files**
- `UI/Sheets/ToolLogoView.swift` (new) — `ToolMonogram` pure logic
  (`initials(for:)`, ports web `getToolInitials`) + `ToolLogoView`, a
  category-tinted rounded-rect monogram. The app is fully local (no network),
  so the monogram is the canonical icon and the always-on graceful fallback —
  it can never render a broken-image box.
- `UI/Sheets/ToolDetailSection.swift` — `headerBlock` now leads with
  `ToolLogoView(tool: selectedTool, accent: category color)`. Trimmed the
  admin-dashboard noise from `metadataSection`: removed the "Match confidence"
  gauge and the "Matched terms" keyword chip grid; kept the human-readable
  "Why it belongs" reason (serves the "why it matters" directive). No brand
  colors changed.
- `Tests/MyAIMapTests/ToolMonogramTests.swift` (new) — 7 tests pinning the
  fallback-initials decision to web parity (all-caps token wins, word
  initials, separator normalisation, boundary-dot stripping, empty → "?",
  uppercasing).

**Selection correctness (no new state).** The card reads `model.selectedTool`,
which resolves from `model.selection.selectedToolID` → derived from
`model.universeMode` (the single source of truth). It renders the same tool the
map highlights; no navigation/selection state was added.

**QA done**
- `xcodegen generate` clean; `xcodebuild test` on iPhone 17 sim → BUILD/TEST
  SUCCEEDED. xcresult: `passedTests` 99 (was 92, +7 monogram), `failedTests` 0.

**Remaining issues**
- Visual/device-matrix QA (iPhone SE-class, iPad, Dynamic Type, dark mode) per
  `QA_REGRESSION_CHECKLIST.md` not yet run on simulator/device.
- No remote logo fetch by design (local-only invariant); if bundled per-tool
  logo assets are ever added, `ToolLogoView` would need an asset lookup branch
  ahead of the monogram.

### Agent 8 — detail IA / pricing / fallback polish (landed)

Canonical behavior for this pass is captured in `TOOL_DETAIL_SPEC.md`.

**Changed files**
- `UI/Sheets/ToolDetailSection.swift` — product-profile IA, header CTA,
  structured pricing rows, neutral section surfaces, related tools, and
  collapsed metadata.
- `UI/Sheets/ToolLogoView.swift` — bundled-logo lookup plus richer category
  fallback icon.
- `Tests/MyAIMapTests/ToolPricingPresenterTests.swift` — pricing presenter
  coverage without invented exact prices.

**QA done**
- `git diff --check` clean.
- XcodeBuildMCP `build_sim` on `iPhone 17 Pro` succeeded with
  `ENABLE_DEBUG_DYLIB=NO`.
- `npm run ios:verify` succeeded, including build-for-testing.
- XcodeBuildMCP `test_sim` reached the MCP timeout, but the underlying
  `xcodebuild ... test-without-building` process completed and produced
  `.xcresult`: `result` Passed, `passedTests` 162, `failedTests` 0,
  `skippedTests` 0.

**Remaining issues**
- Manual visual QA remains required for compactness, Dynamic Type, iPad width,
  and no-URL/user-added fallback states.
