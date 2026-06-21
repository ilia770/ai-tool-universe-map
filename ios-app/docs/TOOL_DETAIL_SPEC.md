# TOOL_DETAIL_SPEC

Owner domain: tool detail sheet information architecture, pricing presentation,
headings, logos/icons, and fallback icon behavior. Files:
`UI/Sheets/ToolDetailSection.swift`, `UI/Sheets/ToolLogoView.swift`, and focused
tests. Do not edit universe rendering, right rail, chat/input, or Add Tool flow
from this spec.

## Behavior

### Header
- Shows tool logo or polished fallback icon.
- Shows tool name, category, short description, workflow stage, and primary
  action.
- Primary action opens website when a verified URL exists; otherwise the header
  clearly indicates that no website is stored.

### Logo / Fallback
- Bundled image assets are used when an asset matches the tool id or logo
  domain.
- If no bundled logo exists, detail shows a category-accent monogram with a
  subtle category symbol.
- The view never renders a broken image.

### Pricing
- Pricing is rendered as structured rows instead of a prose card.
- Known freemium/open-source notes can show Free / `$0` rows.
- Paid plans are described only at the level stored locally, such as
  subscription, usage-based, team, enterprise, or paid/cloud options.
- Exact prices are never invented.
- Unknown or incomplete pricing shows `Unknown / Verify website`.

### Sections
The detail sheet is ordered as:
- Header
- Pricing
- Best for
- Key features
- Strengths
- Tradeoffs
- Common users
- Related tools
- Metadata / technical details

Metadata is collapsed by default and visually lower priority.

### Related Tool Navigation
- Related-tool taps are routed through the owner map view when available.
- On compact width, a related-tool tap keeps the detail sheet open and updates
  the detail mode to the related tool.
- On regular width/iPad, a related-tool tap selects the related tool without
  entering `.detail`, so the trailing inspector updates without dimming the map.

### Visual Style
- Cards use a consistent neutral surface.
- Accent color is used mainly for headings, icons, and small status elements.
- Competing colored card backgrounds are reduced.
- Headings use readable subheadline weight instead of tiny all-caps labels.

## Changed files / QA done / Remaining issues

### Agent 8 — product-profile detail IA (landed)

**Changed files**
- `UI/Sheets/ToolDetailSection.swift` — rebuilt the section order, header CTA,
  pricing rows, neutral section style, related tools, and collapsed metadata.
- `UI/Sheets/ToolLogoView.swift` — added bundled-logo lookup and richer
  category-accent fallback.
- `Tests/MyAIMapTests/ToolPricingPresenterTests.swift` — covers unknown,
  freemium, and open-source pricing without invented exact prices.
- `docs/DETAIL_SCREEN_SPEC.md` — linked the implementation note for local agent
  routing compatibility.

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
- Manual visual QA should inspect Figma, PostHog, a no-URL seed tool, and a
  user-added no-website tool at small iPhone and iPad widths.

### Codex follow-up - related-tool routing (2026-06-21)

**Changed files**
- `UI/Sheets/RootSheet.swift` - optional related-tool callback.
- `UI/Sheets/ToolDetailSection.swift` - related buttons delegate navigation to
  the callback instead of mutating `UniverseViewModel.universeMode` directly.
- `Universe/UniverseMapView.swift` - compact and regular-width related-tool
  routing now matches the owning detail presentation.

**QA done**
- `git diff --check` clean.
- `npm run ios:test-build` succeeded with `TEST BUILD SUCCEEDED`.
- `xcodebuild ... -only-testing:MyAIMapTests test-without-building` passed on
  iPhone 17 Pro (`/tmp/aimap-codex-unit.xcresult`): `passedTests = 171`,
  `failedTests = 0`, `skippedTests = 0`.

**Remaining issues**
- Manual iPad QA should confirm related-tool taps update the trailing inspector
  while leaving the map undimmed.

### Codex follow-up - pricing hierarchy cleanup (2026-06-21)

**Pricing copy.** `ToolPricingPresenter` no longer invents a generic `Pro`
plan. Freemium, paid/cloud, subscription, usage, and unknown pricing are shown
with cautious labels such as `Verify website` or `Hosted options`.

**Visual hierarchy.** Header, pricing, feature sections, and metadata now use a
shared rounded neutral card background instead of broad flat gray rectangles.
This keeps metadata secondary and the detail screen closer to a product profile
than an admin/debug view.

**Tests updated**
- Freemium/open-source pricing assertions verify the cautious labels and ensure
  fabricated exact plan names are not introduced.
