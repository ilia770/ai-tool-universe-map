# DETAIL_SCREEN_SPEC

Owner domain: the tool detail card/sheet. Files:
`UI/Sheets/ToolDetailSection.swift`, `UI/Sheets/RootSheet.swift`,
`Universe/PlanetInfoCard.swift`. Do NOT edit chat/input or the rail here.

## Prime directive
A readable product card, **not an admin dashboard**. It explains: what the
tool is, its category, why it matters, what it connects to. Calm, scannable.

## Requirements
- Tool logo with a graceful fallback (SVG monogram / SF Symbol) when no logo
  domain or the image fails. No broken-image boxes.
- The card shows the tool that is currently `selectedTool` in the machine —
  never a stale/different tool than the map highlight.
- `detail` is a primary overlay, mutually exclusive with `chat`
  (see `UI_STATE_MACHINE.md`). Presented from `universeMode == .detail`, not an
  independent boolean that can disagree with the mode.
- Dismiss returns to the previous map mode (`modeBeforeDetail` semantics),
  restoring the same selection.

## State boundary
Detail READS `selectedTool` from the machine. It does not mutate selection
except via an explicit transition (e.g. "focus on map" → `toolSelected`).

## Changed files / QA done / Remaining issues
_(append per task)_
