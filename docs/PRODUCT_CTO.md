# Product CTO Brief

Last updated: 2026-06-10

This is the high-level product authority for My AI Map. When Codex, Claude Code, or a human is unsure about product direction, architecture priority, or release readiness, start here before editing code.

## Product North Star

My AI Map is a premium interactive universe for understanding an AI tool ecosystem. The app should help a founder see which tools exist, why they matter, how they connect, and what workflow step they support.

The experience should feel like a navigable cosmic operating system, not a flat directory. The user should be able to zoom from the whole ecosystem into category "worlds", inspect individual tools, and understand relationships without reading long explanations first.

## Core User

Primary user: a founder/operator building with AI tools who wants to organize their stack and understand what to use for research, planning, execution, approval, and agent review.

Secondary user: an AI agent working inside the repository who needs a clear source of truth for product, UI, architecture, testing, and release gates.

## Product Pillars

1. **Spatial Understanding**
   The map must make categories, clusters, and relationships visible. The user should know where they are, what they selected, and what is connected.

2. **Premium Cosmic UI**
   The visual language is deep-space, liquid glass, luminous nodes, readable labels, smooth motion, and clear focus states. Avoid clutter, random circles, tiny unreadable text, and abrupt hover behavior.

3. **Explainability**
   Every selected tool must answer: what is it, what category is it in, why is it useful, what workflow stage it supports, and what it connects to.

4. **Agent-Ready Structure**
   Data, layout, relationships, UI panels, 3D scene logic, and tests must be cleanly separated so Codex and Claude Code can work without stepping on each other.

5. **Release Discipline**
   No release should ship without visual smoke checks, mobile/desktop review, interaction review, and a written release note.

## Current Product Surface

Web app:
- React + Vite + TypeScript.
- React Three Fiber / Three.js 3D universe.
- AI tool data in `src/data/ai-tool-universe.seed.json`, exported through the typed facade in `src/data/ai-tool-universe.ts`.
- Classification in `src/lib/classify-ai-tool.ts`.
- Logo helpers in `src/lib/tool-logos.ts`.
- Main app shell in `src/components/AIToolUniverseMap.tsx`.
- 3D scene modules in `src/components/AIToolUniverse3D/`.

iOS prototype:
- Native SwiftUI + RealityKit scaffold in PR stack.
- Product shell and seed data exist, but simulator launch still needs environment stabilization.

## Strategic Roadmap

### Web MVP

Done enough for iteration:
- Central Founder OS node.
- Category groupings.
- Tool nodes with logos.
- Side panel / mobile sheet.
- Search and rule-based classification.
- Pocket-world style category focus.

Next:
- Stabilize hover/focus states.
- Add deterministic visual test mode.
- Define the next storage step after the JSON seed: DB/API schema, provenance, and sync path.
- Improve relation modeling: confidence, reason, workflow stage, source.
- Add better category-world transitions and camera affordances.

### iOS MVP

Goal: personal TestFlight build of My AI Map.

Next:
- Merge PR stack in order.
- Confirm Xcode simulator/device launch.
- Run on a real iPhone with Apple signing.
- Port full web data model to Swift or shared generated data.
- Add RealityKit camera/navigation interactions.
- Add bottom-sheet tool details and category world navigation.

## Decision Rules

- If a change improves clarity and orientation, prefer it over decorative visuals.
- If visual quality conflicts with readability, readability wins.
- If a feature touches both web and iOS data, define the data shape first.
- If agents disagree, open a GitHub issue or PR comment with:
  - context
  - decision needed
  - options
  - recommendation
  - files affected

## Release Quality Bar

Before release, the product must pass:
- `npm run typecheck`
- `npm run lint`
- `npm test`
- `npm run build`
- visual smoke review on desktop and mobile
- interaction review for hover, click, search, category focus, and details panel
- release checklist in `docs/RELEASE_REVIEW.md`
