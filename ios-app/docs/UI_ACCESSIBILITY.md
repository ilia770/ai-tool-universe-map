# UI_ACCESSIBILITY — Interaction and transition accessibility contract

**Status:** baseline mapping, 2026-07-17.

## Non-negotiable requirements

- Every control has a semantic label, role, state/value where useful, and a
  usable hit target. Accessibility identifiers support testing but do not
  replace spoken labels.
- VoiceOver focus follows the user's outcome: enter a presented surface at its
  meaningful heading/control; return to the original semantic trigger after a
  completed dismissal where appropriate.
- Reduce Motion preserves route meaning. Reduce Transparency uses the opaque
  project fallback. Increase Contrast/Bold Text/Dynamic Type must preserve
  readable hierarchy and control reachability.
- Any custom drag competes explicitly with scroll. VoiceOver escape, visible
  close, system back, and gesture dismissal converge on one state transition.

## Current evidence and gaps

| Area | Existing evidence | Gap / future verification |
| --- | --- | --- |
| Constellation nodes | `ConstellationCategory.<id>` and `ConstellationStar.<toolID>` are stable UI-test IDs. | Confirm spoken labels/traits/order at larger type sizes and after modal return. |
| Motion | `BrandMotion.resolved` respects Reduce Motion and static UI-test flag. | No recording currently proves the detail reverse path under Reduce Motion. |
| Transparency | `glassSurface` provides an opaque fallback for Reduce Transparency. | Review actual contrast/material hierarchy on supported OS versions. |
| Detail | `RootSheet` and `ToolDetailSection.Title` provide test targets. | Focus restoration and interactive dismiss/cancel are not automated. |
| Search/chat | Local focus/keyboard state exists. | Test VoiceOver focus across dock collapse, root chat, attachments, and map return. |
| Dynamic Type | System semantic fonts are used. | Local maximum-size caps need per-component justification; no complete device/type matrix is fresh. |
| Dormant UI | Rail and legacy renderer are unmounted. | Do not claim their accessibility as current product coverage. |

## Pilot accessibility acceptance

For `ConstellationStar.figma` → tool detail, verify: source label/action;
focus entering the detail title; state changes announced without duplicate
content; partial drag does not strand focus; cancel leaves focus in detail;
complete dismissal returns focus to the same star; visible close and VoiceOver
escape use the same owner; and Reduce Motion preserves all actions.

Use the [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
as external reference; this document records the project-specific acceptance
contract.

