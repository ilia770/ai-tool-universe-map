# Claude Code Parallel Tasks

Use this prompt when starting Claude Code in the same repository.

```text
You are Claude Code working on My AI Map in:
/Users/ilia882/Code/ai-tool-universe-map

Read these first:
1. .agent/INSTRUCTIONS.md
2. docs/PRODUCT_CTO.md
3. docs/AGENT_OPERATING_MODEL.md
4. docs/superpowers/plans/2026-06-10-product-improvement-sprint.md
5. docs/RELEASE_REVIEW.md

Important coordination:
- Codex is currently integrating active dirty work in iOS preview files, ToolNode hover/focus, classification, and logo helpers.
- Do not revert any existing dirty changes.
- Before editing, run `git status --short --branch`.
- Work on a separate branch or worktree.
- Do not run Xcode/Simulator/Playwright heavy checks in parallel with Codex unless explicitly coordinated.
- Do not commit secrets or API keys.

Current Codex-owned dirty files:
- ios-app/project.yml
- ios-app/Sources/MyAIMap/MyAIMapApp.swift
- ios-app/Sources/MyAIMap/Universe/UniverseView.swift
- src/components/AIToolUniverse3D/ToolNode.tsx
- src/lib/classify-ai-tool.ts
- src/lib/classify-ai-tool.test.ts
- src/lib/tool-logos.ts
- src/lib/tool-logos.test.ts

Pick exactly one task lane below and stay inside its file scope.

TASK LANE 1 - Visual QA and release screenshots
Owned files:
- tests/visual-smoke.spec.ts
- screenshots/**
- docs/design/**
- docs/RELEASE_REVIEW.md

Goal:
Improve the visual QA process for the web app. Add or update smoke coverage for:
- selected node clarity
- mobile selected-service panel visibility
- category pocket exit
- copy hygiene: no env-var/debug/provider copy in public UI

Constraints:
- Do not edit src/components/AIToolUniverse3D/** in this lane.
- If screenshots are generated, keep only useful ones with descriptive names.
- Run only the relevant smoke command if the Mac is idle; otherwise document the command.

TASK LANE 2 - iOS TestFlight and App Store readiness docs
Owned files:
- ios-app/TESTFLIGHT_CHECKLIST.md
- ios-app/README.md
- docs/IOS_STRATEGY.md
- docs/RELEASE_REVIEW.md

Goal:
Make the personal TestFlight path actionable for Xcode 26.5:
- Apple Developer account and team ID checklist
- bundle id `com.ilyatur.myaimap`
- simulator build/run commands
- archive/upload steps
- App Store Connect metadata draft
- privacy/support/screenshot requirements

Constraints:
- Do not edit Swift files or ios-app/project.yml.
- Do not run Xcode builds unless Codex says the machine is idle.

TASK LANE 3 - Product and UX authority docs
Owned files:
- docs/PRODUCT_CTO.md
- docs/design/UI_UX_SPECIALIST.md
- docs/APP_STRUCTURE.md
- docs/AGENT_OPERATING_MODEL.md

Goal:
Make the product direction sharper:
- what a selected tool must explain
- how category worlds should open
- how the bottom panel should behave
- what "premium cosmic liquid glass" means in implementation terms
- what must be reviewed before release

Constraints:
- Docs only.
- Do not edit app code.

TASK LANE 4 - Data QA follow-up
Start this only after Codex commits or explicitly hands off the current classification/logo patch.

Owned files:
- src/data/**
- src/lib/classify-ai-tool.ts
- src/lib/classify-ai-tool.test.ts
- src/lib/tool-logos.ts
- src/lib/tool-logos.test.ts

Goal:
Improve AI tool data quality:
- missing logo domains
- missing relations
- classification edge cases
- tests for newly added rules

Constraints:
- Do not embed Logo.dev keys.
- Keep schema stable.

Return format:
DONE / DONE_WITH_CONCERNS / BLOCKED

Changed files:
- 

Validation:
- 

Risks:
- 

Next recommended action:
- 
```

## Recommended Lane For Claude Right Now

Start with **Task Lane 2 - iOS TestFlight and App Store readiness docs** or
**Task Lane 1 - Visual QA and release screenshots**.

Avoid Lane 4 until Codex has committed the current data/classification changes.
