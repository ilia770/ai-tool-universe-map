# Gameplan

## Research

Use the target app's real frontend stack before integration: React version, routing, styling system, graph/3D libraries, animation library, component conventions, modal/sheet patterns, tests, and build scripts.

## Planning

Treat this folder as the portable source of truth. Decide whether the target app wants:

- A full-screen modal overlay.
- A dedicated `/tool-universe` route.
- An embedded dashboard panel.

Keep the data model separate from rendering so categories, tools, and links can move to JSON or a database later.

## Execution

1. Copy `src/data`, `src/lib/classify-ai-tool.ts`, and `src/components/AIToolUniverse3D` into the target app.
2. Copy or adapt `AIToolUniverseMap.tsx` to the app's modal/layout system.
3. Install `three`, `@react-three/fiber`, `@react-three/drei`, `@react-three/postprocessing`, and `lucide-react` if missing.
4. Keep the 3D scene lazy-loaded so the rest of the app stays light.
5. Run lint, typecheck, tests, build, and a visual browser pass.

## Approval

Review these items before shipping:

- Does the map explain why each tool exists?
- Is the intake field obvious without extra tutorial text?
- Are mobile panels scrollable and usable?
- Are colors premium rather than generic neon?
- Can users close the map with Escape and a button?

## AI Agent Review

Ask a second agent to review:

- Classification mistakes and missing keyword rules.
- Relations that feel inaccurate.
- Performance on low-end laptops.
- Accessibility of buttons, dialog semantics, and focus behavior.
- Whether data structure is ready for backend persistence.
