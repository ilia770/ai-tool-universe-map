# Intake Relation UI Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Render the explainable intake relation suggestions from PR #18 in the Liquid Glass intake preview and selected-tool side panel.

**Scope:** UI-only follow-up stacked on `codex/intake-relation-intelligence`. Do not change the 3D scene, camera behavior, or iOS app in this PR.

## Tasks

- [x] Extend the `AITool.classification` metadata shape so custom tools can persist relation suggestions.
- [x] Show suggested relation anchors in the Liquid Glass preview with label, reason, source, and confidence.
- [x] Persist filtered relation suggestions when a custom tool is added.
- [x] Show a compact selected-tool intake readout with signals and suggested relations.
- [x] Keep existing `relationIds` behavior backward-compatible.
- [x] Fix visual-check bug where plain-text tool names with spaces were displayed with `%20`.
- [x] Run `npm run typecheck`, `npm run lint`, `npm test`, `npm run build`, and `git diff --check`.
- [x] Commit and open a stacked PR.
