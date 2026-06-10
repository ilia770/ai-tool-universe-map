# UI/UX Direction

Last updated: 2026-06-10

This folder is the UI/UX specialist area. Put visual references, screenshots, critiques, interaction notes, and design acceptance criteria here.

## Visual Target

My AI Map should feel like:

- premium cosmic command center
- liquid glass controls
- readable luminous labels
- smooth spatial zoom into category worlds
- clear tool cards and explanations
- professional founder/operator product, not a toy demo

Avoid:

- random unreadable circles
- labels colliding everywhere
- abrupt hover flicker
- flat directory-like layouts
- excessive right-panel text
- decorative effects that hide the product meaning

## Required Screens

| Screen | UX Goal |
| --- | --- |
| Universe overview | User understands the AI ecosystem at a glance. |
| Category focus | User sees a mini-world with more spacing and stronger relationships. |
| Tool selected | User understands what the service is and why it connects. |
| Search/filter | User quickly narrows the universe without losing context. |
| Add tool input | User pastes a name/URL and sees classification feedback. |
| Mobile bottom sheet | User can inspect tools on iPhone without panel clutter. |

## Reference Screenshot Inventory

Current repo screenshots:

- `screenshots/ai-tool-universe-desktop.png`
- `screenshots/ai-tool-universe-hover-bubbles.png`
- `screenshots/ai-tool-universe-hover-focus.png`
- `screenshots/ai-tool-universe-relation-lens.png`
- `screenshots/ai-tool-universe-selected-tool.png`
- `screenshots/ai-tool-universe-search-scan.png`
- `screenshots/ai-tool-universe-clarity-focus.png`
- `screenshots/ai-tool-universe-design-cluster.png`
- `screenshots/vercel-camera-drag-compact-panel.png`
- `screenshots/vercel-large-logo-badges.png`

## Design QA Rubric

Score each item 1-5 before release:

| Area | 1 | 5 |
| --- | --- | --- |
| Orientation | User is lost | User always knows where they are |
| Readability | Labels collide | Labels are legible and staged |
| Interaction | Hover/click feels broken | Hover/click feels smooth and intentional |
| Visual Premium | Demo-like | App-store-worthy |
| Information | Too much or too little | Tool purpose and relationships are clear |
| Mobile | Hard to use | Natural mobile bottom-sheet experience |

Release target: no category below 4.

## How To Add References

Add files as:

```text
docs/design/references/<source>-<pattern>.md
docs/design/references/<source>-<pattern>.png
```

Each reference note should include:

```markdown
# Reference: <Name>

Why it matters:
- Specific reusable pattern.

Apply to My AI Map:
- Exact adaptation.

Do not copy:
- What to avoid.
```

