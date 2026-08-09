# UI_MOTION_TOKENS — Semantic motion catalog

**Status:** baseline mapping, 2026-07-17.  
**Source:** `UI/Theme/BrandMotion.swift`. Values below are project decisions,
not claims about universal Apple timings. Prefer system transitions where they
already communicate the intended behavior; use project tokens only where a
custom relationship needs a documented role.

| Semantic role | Current token / style | Intended use | Interruptibility / Reduce Motion |
| --- | --- | --- | --- |
| Immediate press feedback | `BrandMotion.press` | press-down/release on a direct control | resolves to near-static; never delays action. |
| Control state change | `BrandMotion.nudge` | chips, toggles, small selected-state feedback | interruptible by the next state; resolves static. |
| Modal/content entry | `BrandMotion.entry` | existing sheet/card entry where system transition is not sufficient | do not use to fake a shared hero; resolves static. |
| Small layout/focus change | `BrandMotion.flow` | map selection/layout seating, non-hero changes | interruption follows latest state; resolves static. |
| Glass/control morph | `BrandMotion.morph` | one genuine control/container morph | requires stable identity; use native glass transition where available. |
| Shared hero | **proposed `hero` role** | source-to-destination continuity | selected only after pilot API proof; Reduce Motion simplifies geometry while preserving route. |
| Interactive progress | **proposed untimed progress role** | finger-driven dismissal | no duration while dragging; completion/cancel uses `settle`, not a delayed close. |
| Settle | **proposed `settle` role** | resolve interactive completion/cancel | short, interruptible, Reduce Motion minimal. |
| Ambient | `BrandMotion.breath`, `cursor`, `thinking` | non-essential ambient/streaming feedback | disable/reduce under Reduce Motion and UI-static harness. |
| Content reveal | `stream`, `reveal`, `composerGrow`, `pillPop` | assistant stream, cards, composer growth, arrival feedback | semantic and local; avoid coupling them to navigation. |

## Current implementation rules

- `BrandMotion.resolved` and `withBrandAnimation` are the canonical path for
  respecting Reduce Motion and `-uitestStatic`.
- Repeating animation is limited to explicitly ambient roles and must not hide
  navigation completion or affect hit testing.
- Do not scatter raw spring/duration values in new feature code. If a distinct
  role is warranted, add it here with usage, interruption, and accessibility
  policy first.
- The current `entry` comment references a web curve; it is a project choice,
  not an Apple-standard measurement.

## Pilot motion contract

The tool-detail pilot introduces no blanket new timing. It must use a
continuous progress value during a drag, a documented `settle` behavior only
after distance/velocity resolution, and a Reduce Motion variant that keeps the
same source/destination/state semantics. Record the observed result before
promoting any pilot value to a reusable token.

See Apple's [Motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion)
for the platform principles: motion must clarify relationships and respect
accessibility settings, rather than serve as decoration.

