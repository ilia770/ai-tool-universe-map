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
