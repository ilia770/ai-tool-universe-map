# CHAT_AI_SPEC

Owner domain: Ask AI Universe answer behavior and assistant action chips.
Files: `UI/Search/UniverseAssistantCore.swift`, `State/UniverseViewModel.swift`,
`State/UniverseSelection.swift`, `UI/Search/SearchDock.swift`. Do not edit the
Universe 3D/2D visualization, right rail, detail screen content, Add Tool flow,
profile/settings, or backend logic here.

## Data Sources
- Current universe tools from `UniverseViewModel.visibleAllTools`.
- User-added tools from the same visible tool list, after local persistence.
- Categories and branch labels from `UniverseSeed.category`.
- Tool details, strengths, tradeoffs, typical users, and pricing notes from
  `ToolKnowledgeBook.knowledge(for:)`.
- Tool relations from each `Tool.relationIds`, resolved only when the related
  tool exists in the visible universe.
- Recent local history from `UniverseViewModel.activityHistory` when available.

No live web lookup is performed. Exact pricing must not be invented. If a tool
does not have verified pricing in local knowledge, the assistant says
"Pricing unknown, verify website."

## Behavior

### Workflow questions
Workflow questions such as "I need to create an app. Which tools should I use?"
are handled as stack recommendations, not as missing-service searches.

The assistant returns:
- a short summary first;
- recommended existing tools from the visible universe;
- suggested missing tools to add;
- fastest, cheapest/free, easiest, and advanced/pro paths;
- caveats/tradeoffs;
- action chips.

For app creation, the deterministic local stack prefers existing tools across:
core, design, coding, infrastructure, analytics, and knowledge. Suggested
missing tools are popular gap-fillers only, not verified universe entries.

### Domain questions
Domain questions such as "Which tool should I use for app design?" first search
the visible universe branch. If matching tools exist, they are recommended and
their chips open detail. If no good existing tool exists, the assistant says so
clearly and suggests 2-3 addable tools for that branch.

Supported local domain intents include coding, design, research, analytics,
media, distribution, infrastructure, and knowledge. Russian and English query
keywords are recognized for common recommendation phrasing.

### Direct tool/service search
Direct searches still use `SearchCore` plus `ToolKnowledge.searchableText`.
When there is a match, the assistant gives a structured answer and existing
tool chips. When there is no match and the query looks like one specific
unknown service, it asks for the website URL instead of fabricating details.
Broad platforms such as "google" still require a specific product or use case.

## Action Chips
- Existing tool chip opens the tool detail sheet for that tool.
- Missing suggested tool chip opens Add Tool. It is a specific recommendation
  chip ("Add Framer"), not a duplicate generic Add Tool control.
- Missing suggested tool chips pass their suggestion into Add Tool, so the sheet
  opens with the suggested name and branch prefilled.
- Missing suggestions carry category, reason, and the pricing note
  "Pricing unknown, verify website."

## User-Added Tools
Added tools become visible to future answers because the assistant reads
`visibleAllTools`, not only seed data. User-added tools use cautious language
until enriched with verified website-backed details.

## Changed files / QA done / Remaining issues

### Agent 6 — context-aware Ask AI Universe behavior (landed)

**Changed files**
- `State/UniverseSelection.swift` — added `MissingToolSuggestion` and attached
  suggestions to `AssistantMessage`.
- `UI/Search/UniverseAssistantCore.swift` — added workflow/domain intent
  handling, structured recommendation responses, missing-tool suggestions,
  relation mentions, cautious pricing, and recent-history caveats.
- `State/UniverseViewModel.swift` — passes visible tools and recent activity to
  the assistant, stores missing suggestions on assistant messages.
- `UI/Search/SearchDock.swift` — renders existing and missing action chips;
  existing tool chips open detail, missing chips open Add Tool.
- `Universe/UniverseOverlayView.swift`, `Universe/UniverseMapView.swift` —
  narrow callback wiring so assistant chips can open a selected tool detail.
- `Tests/MyAIMapTests/UniverseAssistantCoreTests.swift` — covers app workflow,
  design domain, empty-domain fallback, user-added visibility, and unknown
  pricing notes.

**QA done**
- `git diff --check` clean.
- `npm run ios:verify` passed: `TEST BUILD SUCCEEDED`.
- `xcodebuild -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/aimap-ai-dd -resultBundlePath /tmp/aimap-ai-unit.xcresult -only-testing:MyAIMapTests test` passed.
- `xcrun xcresulttool get test-results summary --path /tmp/aimap-ai-unit.xcresult`: `passedTests = 149`, `failedTests = 0`, `result = Passed`.

**Remaining issues**
- Manual simulator QA should verify chip tap behavior: existing chip opens the
  correct detail sheet; missing chip opens Add Tool; chat transcript remains
  stable after returning.

### Codex follow-up - missing-chip prefill (2026-06-21)

**Changed files**
- `UI/Search/SearchDock.swift` - missing suggestion chips now call a
  suggestion-specific add callback.
- `Universe/UniverseOverlayView.swift`, `Universe/UniverseMapView.swift` -
  carry missing-tool drafts into the Add Tool sheet and clear drafts on dismiss.
- `UI/Settings/AddToolSheet.swift` - applies the suggested name and category
  draft once on appear.

**QA done**
- `git diff --check` clean.
- `npm run ios:test-build` succeeded with `TEST BUILD SUCCEEDED`.
- `xcodebuild ... -only-testing:MyAIMapTests test-without-building` passed on
  iPhone 17 Pro (`/tmp/aimap-codex-unit.xcresult`): `passedTests = 171`,
  `failedTests = 0`, `skippedTests = 0`.

**Remaining issues**
- Manual simulator QA should verify "Add Framer" style chips show the matching
  name in the Add Tool sheet and keep the suggested branch selected.
