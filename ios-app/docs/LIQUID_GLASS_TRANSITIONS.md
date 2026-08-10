# LIQUID_GLASS_TRANSITIONS — Implemented identity and transition inventory

This document records code-backed transitions only. A similar visual direction
is not evidence that a morph exists.

| Surface pair | Evidence | Implementation | Status / caveat |
| --- | --- | --- | --- |
| Map ↔ Ask AI root surfaces | `RootShell.surface`, `surfaceNamespace`, `diveTransition` | asymmetric scale/fade/blur; plain opacity under Reduce Motion; root switch uses shared glass cluster behavior | **CONFIRMED.** Root route transition, not `UniverseMode.chatOpen`. |
| Profile → Account sheet | `ChromeMorphID.account`, `morphSource`, `navigationTransition(.zoom)` | source control pairs with sheet namespace where host owns both | **CONFIRMED** availability/system behavior; runtime quality unverified. |
| Add Tool trigger → sheet | `ChromeMorphID.addTool`, `morphSource`, `navigationTransition(.zoom)` | source varies by root/map host; optional namespace avoids duplicate source | **CONFIRMED** where same presentation context supplies namespace. |
| Collapse Chat ↔ Show chat | `SearchDock.chatChromeNamespace`, `navigationGlassMorphID("SearchDock.chatCollapse")` | glass identity travels between dock affordances; composer has separate static ID | **CONFIRMED** source pairing; only within map dock. |
| Segment selection | `GlassMorphCluster` | selected option uses native `glassEffectID` on iOS 26; `matchedGeometryEffect` fallback on iOS 18–25 | **CONFIRMED.** |
| Card → Map pill | Root geometry preferences and `CardLandRequest` | ghost capsule flights only when source/destination frames exist and motion is enabled | **CONFIRMED** decorative flight, not navigation ownership. |
| Tool chip → map tool | Root tool-flight preference/ghost state | source chip flight waits for matching selected-tool anchor | **CONFIRMED** decorative handoff; current 2D selected node publishes target. |
| Map layout update | `UniverseConstellationView` / `BrandMotion.morph` | deterministic node positions animate with mode signature | **CONFIRMED in uncommitted current renderer.** |
| 3D map ↔ close/back | legacy spatial files only | camera and RealityKit transitions exist in retained code | **NOT CURRENTLY MOUNTED.** Do not call this an active morph. |

## API and fallback rules

- `glassSurface` owns platform fallback: opaque fallback for Reduce
  Transparency, native `glassEffect` on iOS 26+, material/hairline otherwise.
- `navigationGlassMorphID` maps to `glassEffectID` on iOS 26 and
  `matchedGeometryEffect` below it.
- `.navigationTransition(.zoom(sourceID:in:))` is used for account/add sheets;
  it is not evidence of a custom glass transition on every OS.
- Every source/destination pair needs one stable ID within the same namespace.
  Do not reuse the composer’s identity for collapse/show affordances.
- `BrandMotion.isMotionDisabled` combines accessibility Reduce Motion and the
  static UI-test flag. New ambient or press animation must use it.

## Runtime verification needed

Confirm native glass continuity, Reduce Motion fallback, transition
interruption/cancellation, source-frame races, and sheet morph behavior on iOS
26 hardware/simulator. Current code alone cannot establish whether a visually
smooth morph occurs on every device/OS configuration.
