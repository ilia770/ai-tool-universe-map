# ADD_TOOL_SPEC

Owner domain: Add Tool sheet and local add-tool behavior. Files:
`UI/Settings/AddToolSheet.swift`, `State/UniverseViewModel.swift`, and focused
tests. Do not edit universe rendering, chat layout, right rail, or detail
visual design here.

## Behavior

### Branch Mode
- `Auto` and `Manual` are explicit segmented buttons.
- Tapping `Auto` selects auto mode.
- Tapping `Manual` selects manual mode.
- Auto mode resolves the branch from tool name, website, and active universe
  context.
- Manual mode respects the selected branch and auto suggestions never override
  it.

### Auto Branch
- Name and website keyword matches dominate active-branch context.
- Active universe branch is used as fallback when no strong keyword exists.
- If the active branch is `core` and there is no signal, fallback is
  `analytics`.
- Example: `PostHog` / `posthog.com` resolves to `Analytics` even when the
  active branch is different.

### Validation
- Name is required.
- Website is optional.
- Website input is normalized by adding `https://` when needed. `http://`
  entries are upgraded to `https://`; unsupported schemes are ignored.
- If website exists, the normalized source domain is stored on `Tool.logoDomain`
  with leading `www.` removed.
- If website is missing, the tool summary and classification reason explicitly
  mark claims as unverified.

### Add Action
- Add is enabled when name is non-empty.
- If the name slug or normalized source domain already exists, Add focuses the
  existing tool instead of creating a suffixed copy.
- If the matching existing tool is hidden, Add restores it, persists the
  unhidden state, then focuses it.
- After add, the tool is appended to the visible universe, persisted, focused,
  searchable, and available to Ask AI Universe via `visibleAllTools`.
- Added tools can be selected and opened through the existing detail flow.
- Add Tool may open with a draft from an Ask AI missing-tool suggestion. In
  that case the sheet pre-fills the suggested name and uses Manual branch mode
  for the suggested category.

## Changed files / QA done / Remaining issues

### Agent 8 — Add Tool mode and post-add availability (landed)

**Changed files**
- `UI/Settings/AddToolSheet.swift` — replaced inverted single toggle with
  explicit Auto / Manual buttons; added testable `AddToolLogic`.
- `State/UniverseViewModel.swift` — stores normalized source domain, marks
  no-website tools as unverified, and keeps existing focus/persistence behavior.
- `Tests/MyAIMapTests/AddToolLogicTests.swift` — covers Auto/Manual resolution,
  PostHog→Analytics, active-branch fallback, and name validation.
- `Tests/MyAIMapTests/UniverseViewModelTests.swift` — covers source-domain
  storage, no-website unverified claims, and assistant visibility after add.

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
- Manual simulator QA should confirm the segmented buttons feel correct and
  that a newly added tool is visible on the selected branch immediately after
  the sheet dismisses.

### Codex follow-up - duplicate and suggestion bugs (2026-06-21)

**Changed files**
- `State/UniverseViewModel.swift` - duplicate detection by name slug/domain,
  hidden-tool restore on duplicate add, and `http://` -> `https://` URL
  normalization.
- `UI/Settings/AddToolSheet.swift` - optional missing-tool draft prefill.
- `Tests/MyAIMapTests/UniverseViewModelTests.swift` - duplicate visible,
  duplicate hidden restore, and HTTP upgrade coverage.

**QA done**
- `git diff --check` clean.
- `npm run ios:test-build` succeeded with `TEST BUILD SUCCEEDED`.
- `xcodebuild ... -only-testing:MyAIMapTests test-without-building` passed on
  iPhone 17 Pro (`/tmp/aimap-codex-unit.xcresult`): `passedTests = 171`,
  `failedTests = 0`, `skippedTests = 0`.

**Remaining issues**
- Manual simulator QA should verify duplicate-focus and hidden-restore behavior
  from the real Add Tool sheet, not only the model tests.
