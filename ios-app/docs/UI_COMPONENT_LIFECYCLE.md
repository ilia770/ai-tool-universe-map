# UI_COMPONENT_LIFECYCLE — Transition lifecycle contracts

**Status:** baseline lifecycle map, 2026-07-17.  
**Rule:** conditionals may remove a component only when there is no promised
continuity. For a shared object, define how it remains addressable through
open, cancel, completion, restoration, and accessibility focus.

| Component / transition participant | Creation and owner | Source → destination / stable identity | Interruption, removal, restoration, focus |
| --- | --- | --- | --- |
| Root Map/Ask AI surface | `RootShell` creates one selected `surface`. | Map ↔ Chat; route identity, not a shared visual object. | Current custom dive can be interrupted only as SwiftUI permits; Map reset behavior is product-defined. Focus lands in destination route; needs explicit future route tests. |
| Constellation category node | `UniverseConstellationView` renders from model mode/layout. | overview/context/focus for `ToolCategoryId.rawValue`. | Mode changes recompute layout. Returning to overview restores semantic category IDs, not a saved geometry contract. |
| Constellation tool node | Map renderer renders `Tool.id` when layout includes it. | selected node → detail is intended continuity; current transition identity missing. | Current `.detail` layout suppresses selected tool visual state, so source is not reserved. The pilot must keep it mounted or use a persistent hero representation, return to the exact `Tool.id`, and focus the source after final dismissal. |
| Compact tool detail | Current source: `UniverseMapView` sheet + model mode. | map tool → `RootSheet` / `ToolDetailSection`; proposed `ToolDetailTransitionID.tool(id)`. | Current state is split among `universeMode`, `detailPresented`, `modeBeforeDetail`, and pending request. Pilot: one typed transition owner, continuous drag progress, cancel returns to selected source, finish settles to `.toolSelected`. |
| Regular tool inspector | `UniverseMapView.inspectorPanel` derives from selected tool. | map selection → inline inspector for same `Tool.id`. | Separate environment from compact pilot; no sheet/drag assertion. Keep out of the pilot acceptance scope. |
| Account/Add control | Root or map chrome owns local presentation flag. | `ChromeMorphID.account`/`.addTool` trigger → matching sheet zoom identity. | System dismissal closes host flag; two presentation hosts are an architecture concern. Accessibility focus should enter sheet title then return to trigger. |
| In-map SearchDock | Overlay creates dock; local focus/collapse/attachments combine with model transcript. | collapsed ↔ active composer has semantic session identity but no formal transition ID. | Current two-way loop can reapply local state on global mode change. Cancel must restore map interactivity and focus appropriately; formalize before a new hero treatment. |
| Chat tool chip flight | Chat/root owns transient flight request and geometry snapshot. | chip `Tool.id` → map target; currently temporary `UUID` request token. | One-way decorative flight with timer; no stable return, source reservation, or interactive cancellation. Do not use as continuity evidence. |
| Onboarding overlay | Model persisted `hasSeenOnboarding`. | first-run overlay → map; no shared object requirement. | Skip/scrim/actions complete the same persisted state; focus returns to map primary action. |
| Copy toast | Local component state creates an event. | local action → transient message; event token is intentionally short-lived. | Replacing/coalescing events is allowed; VoiceOver announcement must remain meaningful. |

## Pilot lifecycle target — compact map tool to detail

1. **Idle:** `UniverseViewModel` exposes no detail route; the source
   `ConstellationStar.<toolID>` is selected or selectable.
2. **Opening:** one typed route/transition state records `toolID`; the map host
   owns the namespace and reserves the source's visual identity.
3. **Presented:** destination content reads the same `Tool.id`; source remains
   visually accounted for rather than being silently replaced.
4. **Interactive dismiss:** a single owner receives continuous drag progress;
   map depth/source/destination respond to that value.
5. **Cancel:** progress returns to zero; detail remains presented and the
   same source/destination identities remain valid.
6. **Finish:** route resolves to `.toolSelected(category, toolID)`; source
   returns to its exact semantic place and receives accessibility focus when
   appropriate. Custom close, system gesture, and VoiceOver escape use this
   same reducer path.

No production lifecycle is changed by this document. The current compact
sheet remains baseline behavior until the pilot is approved.

