# Agent Product Ops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a durable collaboration and release operating system for Codex, Claude Code, product direction, UI/UX review, and release safety.

**Architecture:** Add documentation-first governance files without changing runtime product code. The system makes `docs/PRODUCT_CTO.md` the product authority, `docs/APP_STRUCTURE.md` the technical map, `docs/AGENT_OPERATING_MODEL.md` the agent collaboration contract, and `docs/RELEASE_REVIEW.md` the release gate.

**Tech Stack:** Markdown, GitHub PR template, existing Vite/React/Three.js project, Superpowers planning workflow.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `.agent/INSTRUCTIONS.md` | Shared rules for Codex and Claude Code, with links to product/agent docs. |
| `docs/PRODUCT_CTO.md` | CTO-level product truth: north star, pillars, roadmap, decision rules. |
| `docs/APP_STRUCTURE.md` | High-level app file map and ownership model. |
| `docs/AGENT_OPERATING_MODEL.md` | How agents coordinate, split files, communicate, and hand off work. |
| `docs/AGENT_STATUS.md` | Short dashboard for done items, blockers, and next edit targets. |
| `docs/RELEASE_REVIEW.md` | Release checklist for web, iOS, visual QA, data QA, stop-ship conditions. |
| `docs/design/README.md` | UI/UX direction, screenshot inventory, design QA rubric. |
| `docs/design/UI_UX_SPECIALIST.md` | Role definition and review output format for a UI/UX reviewer. |
| `.github/PULL_REQUEST_TEMPLATE.md` | GitHub PR checklist enforcing validation, screenshots, risks, release gates. |

### Task 1: Establish Product CTO Source Of Truth

**Files:**
- Create: `docs/PRODUCT_CTO.md`
- Modify: `.agent/INSTRUCTIONS.md`

- [ ] **Step 1: Create CTO brief**

Create `docs/PRODUCT_CTO.md` with these sections:

```markdown
# Product CTO Brief

Last updated: 2026-06-10

This is the high-level product authority for My AI Map.

## Product North Star
My AI Map is a premium interactive universe for understanding an AI tool ecosystem.

## Product Pillars
1. Spatial Understanding
2. Premium Cosmic UI
3. Explainability
4. Agent-Ready Structure
5. Release Discipline

## Release Quality Bar
Before release, run typecheck, lint, tests, build, visual smoke review, and release checklist.
```

- [ ] **Step 2: Link CTO brief from shared agent instructions**

Add a project context section to `.agent/INSTRUCTIONS.md`:

```markdown
## Project Context

- Product authority: `docs/PRODUCT_CTO.md`
- App structure: `docs/APP_STRUCTURE.md`
- Agent collaboration: `docs/AGENT_OPERATING_MODEL.md`
- Release checklist: `docs/RELEASE_REVIEW.md`
- UI/UX direction: `docs/design/README.md`
```

- [ ] **Step 3: Verify links exist**

Run:

```bash
test -f docs/PRODUCT_CTO.md
test -f .agent/INSTRUCTIONS.md
```

Expected: both commands exit 0.

### Task 2: Define Agent Collaboration Model

**Files:**
- Create: `docs/AGENT_OPERATING_MODEL.md`
- Modify: `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] **Step 1: Create agent operating model**

Create `docs/AGENT_OPERATING_MODEL.md` with:

```markdown
# Agent Operating Model

## Shared Rule
Both agents must read `.agent/INSTRUCTIONS.md`, `docs/PRODUCT_CTO.md`, `docs/APP_STRUCTURE.md`, this file, and the specific plan/issue.

## File Ownership Matrix
| Area | Primary Agent | Backup Agent | Files |
| Web 3D scene | Claude Code | Codex | `src/components/AIToolUniverse3D/**` |
| Web shell/panels | Codex | Claude Code | `src/components/AIToolUniverseMap.tsx`, `src/index.css` |
| iOS app | Claude Code | Codex | `ios-app/**` |
```

- [ ] **Step 2: Create PR template**

Create `.github/PULL_REQUEST_TEMPLATE.md` with sections:

```markdown
## Summary
## Agent Handoff
## Validation
## Screenshots / Visual Review
## Risks
## Release Checklist
```

- [ ] **Step 3: Verify ownership docs**

Run:

```bash
rg "File Ownership Matrix|Agent Handoff" docs/AGENT_OPERATING_MODEL.md .github/PULL_REQUEST_TEMPLATE.md
```

Expected: matching lines from both files.

### Task 3: Document App Structure

**Files:**
- Create: `docs/APP_STRUCTURE.md`

- [ ] **Step 1: Create structure map**

Create `docs/APP_STRUCTURE.md` with a table mapping:

```markdown
| Path | Owner | Purpose |
| `src/data/ai-tool-universe.ts` | Data/Product | Categories, tools, relation data. |
| `src/components/AIToolUniverseMap.tsx` | App Shell | Main UI controls and panels. |
| `src/components/AIToolUniverse3D/Scene.tsx` | 3D Lead | Scene orchestration. |
| `ios-app/` | iOS Lead | Native SwiftUI/RealityKit prototype. |
```

- [ ] **Step 2: Verify key paths are covered**

Run:

```bash
rg "AIToolUniverseMap|Scene.tsx|ios-app|ai-tool-universe.ts" docs/APP_STRUCTURE.md
```

Expected: all four terms appear.

### Task 4: Add UI/UX Specialist Area

**Files:**
- Create: `docs/design/README.md`
- Create: `docs/design/UI_UX_SPECIALIST.md`

- [ ] **Step 1: Create UI direction**

Create `docs/design/README.md` with:

```markdown
# UI/UX Direction

## Visual Target
- premium cosmic command center
- liquid glass controls
- readable luminous labels
- smooth spatial zoom into category worlds

## Design QA Rubric
Score orientation, readability, interaction, visual premium, information, and mobile from 1-5.
```

- [ ] **Step 2: Create specialist role**

Create `docs/design/UI_UX_SPECIALIST.md` with:

```markdown
# UI/UX Specialist Role

## Responsibilities
- Review every UI PR before release.
- Check desktop and mobile screenshots.
- Watch for unreadable labels, overlapping panels, unclear hover target, missing logos.
```

- [ ] **Step 3: Verify design docs**

Run:

```bash
rg "Visual Target|UI/UX Specialist Role|Design QA Rubric" docs/design
```

Expected: matching lines from both design files.

### Task 5: Add Release Review Gate

**Files:**
- Create: `docs/RELEASE_REVIEW.md`
- Modify: `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] **Step 1: Create release checklist**

Create `docs/RELEASE_REVIEW.md` with required web commands:

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

Include visual review, interaction review, data review, iOS checks, and stop-ship conditions.

- [ ] **Step 2: Add PR release checklist link**

Add to `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Release Checklist
- [ ] I checked `docs/RELEASE_REVIEW.md`.
- [ ] No stop-ship condition applies.
```

- [ ] **Step 3: Verify release gate**

Run:

```bash
rg "Stop-Ship|npm run typecheck|docs/RELEASE_REVIEW.md" docs/RELEASE_REVIEW.md .github/PULL_REQUEST_TEMPLATE.md
```

Expected: release commands and stop-ship references appear.

### Task 6: Add Current Agent Status Dashboard

**Files:**
- Create: `docs/AGENT_STATUS.md`
- Modify: `.agent/INSTRUCTIONS.md`
- Modify: `docs/APP_STRUCTURE.md`

- [ ] **Step 1: Create status dashboard**

Create `docs/AGENT_STATUS.md` with:

```markdown
# Agent Status Dashboard

## Current Product State
- Web app production URL.
- iOS app build/test-build status.

## Current Blockers
| Area | Blocker | Evidence | Next Action |

## Where To Fix Next
| Goal | Primary Files |
```

- [ ] **Step 2: Link dashboard**

Add `docs/AGENT_STATUS.md` to `.agent/INSTRUCTIONS.md` and `docs/APP_STRUCTURE.md`.

- [ ] **Step 3: Verify dashboard**

Run:

```bash
rg "Current Blockers|Where To Fix Next|docs/AGENT_STATUS.md" docs/AGENT_STATUS.md .agent/INSTRUCTIONS.md docs/APP_STRUCTURE.md
```

Expected: all terms appear.

### Task 7: Validate Documentation-Only Change

**Files:**
- Validate all files above.

- [ ] **Step 1: Check git diff**

Run:

```bash
git diff --stat
git diff --check
```

Expected:
- only docs, `.agent/INSTRUCTIONS.md`, and `.github/PULL_REQUEST_TEMPLATE.md` changed
- no whitespace errors

- [ ] **Step 2: Run lightweight project verification**

Run:

```bash
npm run typecheck
```

Expected: command exits 0.

- [ ] **Step 3: Commit**

Run:

```bash
git add .agent/INSTRUCTIONS.md docs/PRODUCT_CTO.md docs/APP_STRUCTURE.md docs/AGENT_OPERATING_MODEL.md docs/AGENT_STATUS.md docs/RELEASE_REVIEW.md docs/design/README.md docs/design/UI_UX_SPECIALIST.md docs/superpowers/plans/2026-06-10-agent-product-ops.md .github/PULL_REQUEST_TEMPLATE.md
git commit -m "docs: add agent product operating system"
```

Expected: one commit containing documentation-only governance changes.

## Self-Review

Spec coverage:
- Codex/Claude shared instructions: covered by `.agent/INSTRUCTIONS.md` and `docs/AGENT_OPERATING_MODEL.md`.
- File split between agents: covered by File Ownership Matrix.
- Done/errors/next fixes dashboard: covered by `docs/AGENT_STATUS.md`.
- CTO product source of truth: covered by `docs/PRODUCT_CTO.md`.
- Full application structure: covered by `docs/APP_STRUCTURE.md`.
- UI/UX specialist and examples folder: covered by `docs/design/`.
- Release screen/review rules: covered by `docs/RELEASE_REVIEW.md` and PR template.

Placeholder scan:
- No TBD/TODO placeholders are used.
- Every task has exact files and commands.

Type consistency:
- Paths match repository paths observed before writing this plan.
