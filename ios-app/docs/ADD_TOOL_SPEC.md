# ADD_TOOL_SPEC

Owner domain: the Add Tool sheet and local add-tool classification / persistence.

**Affected files**
- `UI/Settings/AddToolSheet.swift` — sheet UI + `AddToolBranchMode` +
  `AddToolLogic` (pure, testable classification).
- `State/UniverseViewModel.swift` — `addCustomTool`, `existingToolMatching`,
  `suggestedRelations`, URL/host normalization, persistence + focus.
- `Data/UniverseSeed.swift` + `Resources/ai-tool-universe.seed.json` — branch
  catalog and labels.
- Tests: `Tests/MyAIMapTests/AddToolLogicTests.swift`,
  `Tests/MyAIMapTests/UniverseViewModelTests.swift`.

Do not edit universe rendering, chat layout, right rail, or detail visual
design here.

## Required behavior
1. **Name is primary.** A tool can be added by name only — Website is optional
   and visually lower-priority.
2. **Auto classification is the DEFAULT and clearly active** — not inverted. The
   segmented control opens on `Auto`; the resolved branch is shown with a
   wand affordance.
3. **AI classifies branch from the name** (and the website when given). Branch
   selection must be deterministic, never random.
4. **Base branches come FIRST**, and the AI/user create a new branch only when
   none fit. Base branch order: Coding, Design, Research, Analytics, Media,
   Runtime, Social, Skills. (Core is reserved for Founder OS and is never an
   auto target.)
5. **After a successful add** the tool appears in the map, Ask AI context,
   detail screen, and search. There must be no "tool does not exist" answer for
   a tool that was just added.

## Branch model (current)
`ToolCategoryId` (Data/ToolCategory.swift) → seed `shortName`:

| id | shortName | full name |
| --- | --- | --- |
| coding | Coding | Coding & Agentic Dev |
| design | Design | Design & Product UI |
| research | Research | Research & Data Intake |
| analytics | Analytics | Analytics & Growth Intelligence |
| media | Media | Media & Creative Production |
| infrastructure | Runtime | Infrastructure & Runtime |
| distribution | Social | Distribution & Social Ops |
| knowledge | Skills | Knowledge & Skills |
| core | Core | AI Operating Core (reserved) |

These are the base branches. The Manual picker offers all of them except Core.
*(Gap vs. brief: the sheet does not yet support creating a brand-new branch on
the fly — Auto/Manual only choose among existing branches. "Create a new branch
only when needed" is the target; today an unmatched tool falls back to the
active branch or Analytics. Document as the next extension.)*

## Branch Mode (`AddToolBranchMode`)
- `Auto` and `Manual` are explicit segmented capsule buttons; selected state is
  tinted with the resolved branch color. Default selection is `Auto`.
- Tapping `Auto` selects auto; tapping `Manual` selects manual. State is direct
  (no inverted toggle).
- Auto resolves the branch from name + website + active universe context.
- Manual respects the chosen branch; auto suggestions never override it.

## Auto classification (`AddToolLogic`)
- `suggestedCategory(name:website:activeCategory:)` folds `"name website"`,
  scores each non-core branch by keyword hits (`autoKeywords`, weighted ×10)
  plus a +1 active-branch context boost; highest score wins.
- If no keyword matches: fall back to the active branch, or `analytics` when the
  active branch is `core`.
- `resolvedCategory(mode:manualCategory:suggestedCategory:)` returns the
  suggested branch in Auto, the manual branch in Manual.
- `autoReason(...)` explains the choice (keyword match vs. active context vs.
  awaiting signal) and is shown under the resolved branch label.
- Example: `PostHog` / `posthog.com` resolves to **Analytics** even when the
  active branch differs.

## Validation
- Name required (`AddToolLogic.canAdd`); Add disabled until name is non-empty.
- Website optional. Normalized to `https://` (`http://` upgraded; unsupported
  schemes ignored). Source domain (leading `www.` stripped) stored on
  `Tool.logoDomain`.
- No website → summary + classification reason mark claims as unverified, and
  classifier confidence drops to 0.48 (vs. 0.74 with a website).

## Add action (`addCustomTool`)
- Duplicate detection by name slug OR normalized source host
  (`existingToolMatching`): instead of creating a suffixed copy, Add focuses the
  existing tool. If that tool was hidden, it is restored + persisted first.
- New tool is appended to the visible universe, persisted, focused, searchable,
  and available to Ask AI via `visibleAllTools`.
- `suggestedRelations` keeps relations local to the chosen branch (broad brands
  are not wired to everything).
- The sheet may open with a draft from an Ask AI missing-tool suggestion: it
  pre-fills the suggested name + category and switches to Manual for that branch.

## Acceptance (QA)
- Add with name only (no website) succeeds; tool shows on its branch.
- `Auto` is selected by default and visibly active (not inverted).
- Add-by-name classifies a clear name to the right base branch (PostHog →
  Analytics) without a website.
- Manual selection is honored and not overridden by auto.
- Base branches appear and are chosen before any new-branch creation.
- After add, the tool is visible in map, detail, search, and Ask AI answers; no
  "tool does not exist" for it.
- Adding a duplicate focuses the existing tool (and un-hides it if hidden)
  rather than creating a copy.
- `http://` website upgrades to `https://`; source domain stored without `www.`.

## History (prior landed work)
Agent 8 replaced the inverted single toggle with explicit Auto/Manual buttons
and extracted `AddToolLogic`. Codex follow-ups added duplicate/hidden-restore
detection, `http→https` normalization, missing-tool draft prefill, and keyboard
/ form reachability (field focus, `ScrollViewReader`, keyboard toolbar). Tests:
`AddToolLogicTests` (Auto/Manual, PostHog→Analytics, active-branch fallback,
name validation) and `UniverseViewModelTests` (source-domain storage, unverified
no-website claims, duplicate/hidden restore, HTTP upgrade, post-add visibility).
