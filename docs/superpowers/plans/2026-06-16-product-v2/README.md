# Product v2 — iOS + Web Parity (2026-06-16)

> **For agentic workers:** each `pN-*.md` is a standalone bite-sized implementation plan
> (use `superpowers:subagent-driven-development` or `superpowers:executing-plans`).
> Steps use `- [ ]` checkboxes for tracking.

**Goal:** Turn "My AI Map" into a top-tier Apple-grade tool that *structures* great AI tools
and lets the user *find* the right one fast — via a smart, honest hyperbrain (chat + rich
per-tool knowledge), precise relationship inference, and a clean liquid-glass shell — at
parity across the iOS app and the web playground.

**Scope decided with user:** iOS **and** web parity. Account/Settings = visualization picker,
language (RU/EN), History, data reset/export, About.

## Parts

| Part | Title | Lane | Depends on |
|------|-------|------|------------|
| **P0** | Knowledge foundation (canonical `knowledge.json`, Swift model, 49-tool parity) | shared | — |
| **P1** | iOS top bar → Account/Settings (strip title+stages, circle → settings; RU/EN L10n) | iOS | — |
| **P2** | iOS tool delete (soft-delete + scene prune + confirm) | iOS | P1 |
| **P3** | iOS chat/find (Swift QueryEngine + bottom glass ChatDock ≤⅓ screen) | iOS | P0 |
| **P4** | iOS history (added/deleted log → tap brand window) | iOS | P1, P2 |
| **P5** | iOS rich tool detail (killer features/pricing/pros-cons/who-uses/connections/Open) | iOS | P0 |
| **P6** | Web parity (account/settings, language, delete, reset/export) | web | — |
| **P7** | Apple interactions polish (liquid glass + tap/long-press/swipe/micro-anim/haptics) | both | P1–P6 |
| **P8** | Intake intelligence (accurate classify, anti-hallucination, confirm giants, dynamic category) | shared | P0 |
| **P9** | Relationship intelligence (pinpoint typed edges + "connected because", no hub over-connect) | shared | P0, P8 |

## Recommended execution order

1. **P0** — foundation; everything reads the knowledge.
2. **P8** — fixes the live misclassification bug (posthog → analytics, not Social) + intake state machine; needed before relations.
3. **P9** — precise relationship inference on top of P0+P8.
4. **P1** — iOS shell (account/settings/L10n) — the most visible change the user asked for.
5. **P2, P4** — delete + history (P4 consumes P2 deletions).
6. **P3, P5** — chat + rich detail (both read P0 knowledge).
7. **P6** — web parity for the new shell features.
8. **P7** — final cross-lane interaction/liquid-glass polish pass.

## Key grounded findings baked into the plans

- **posthog bug root cause** (P8): the `post` keyword in `src/lib/classify-ai-tool.ts` routes to
  `distribution` (shortName "Social"); no `analytics` category exists. P8 adds a permanent
  `analytics` category (seed count 8→9; `SeedIntegrityTests` updated) + a regression test pinning
  posthog/mixpanel/amplitude/sentry/datadog/grafana to it.
- **Anti-hallucination** (P8): low-confidence/unknown → `IntakeOutcome.unsure` returns the RU prompt
  "Не нашёл такой сервис — скинь ссылку на сайт, определю что это и добавлю" and classifies from the
  URL/domain instead of guessing. Giant/ambiguous (instagram/google) → `ambiguous` "Ты уверен?" guard.
  No-fit → `newCategory` creates `dyn-<slug>` and renders a new branch on both lanes.
- **Pinpoint relations** (P9): `inferRelationships` emits typed, capped, thresholded edges
  (extension-of / integrates-with / same-vendor / data-flows-to / alternative-to) with a reason +
  confidence; tests assert a Chrome-extension links to `google` **only**, a hub does not over-connect,
  and same-category tools link `alternative-to`. Reasons surface as "Connected because …" in P5.
- **Cross-lane parity**: P0/P8/P9 emit canonical JSON (`knowledge.json`, `classifier-taxonomy.json`,
  `relationship-fixtures.json`) verified byte-identical web↔iOS via `scripts/ios-verify.sh` `diff -q`.

## Constraints (every part)

Pure liquid glass; tap / long-press / swipe / press-feedback (scale 0.96) / micro-animations /
tactile haptics; honor reduce-motion / Reduce Motion; 60fps, lightweight; no full-screen
postprocessing on R3F; TDD with real test code; follow existing patterns; frequent commits.

## Coordination note

Codex has WIP worktrees `codex-intake-relation-intelligence` / `codex-intake-relation-ui` touching
the same intake/relations area — reconcile P8/P9 against any landed codex work before executing those.
