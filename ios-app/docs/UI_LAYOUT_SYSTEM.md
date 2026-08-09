# UI_LAYOUT_SYSTEM — Semantic layout and safe-area contract

**Status:** baseline mapping and gap register, 2026-07-17.  
**Principle:** use adaptive relationships and documented semantic spacing; do
not elevate a number to an “Apple standard” merely because it appears in code.

## Existing project spacing roles

`UI/Theme/BrandSpacing.swift` supplies current project tokens. They are
project visual-system decisions, not a mandate to replace contextual geometry.

| Role | Current token | Typical use |
| --- | --- | --- |
| Hairline / micro | `hair` / `xs` | dense rows, chip internals |
| Inline | `s` / `sm` | symbol-label and compact control rhythm |
| Control internal | `m` | card/control internal padding |
| Standard / screen-relative | `l` / `xl` | sheet padding, section-adjacent spacing |
| Screen / section | `xxl` / `section` | top-level sheet and major content sections |

## Layout contracts

| Area | Current contract | Required rule / known gap |
| --- | --- | --- |
| Root surfaces | `RootShell` owns full-screen Map/Chat composition and top safe-area chrome. | Avoid manual status-bar/Dynamic Island offsets; test root switch after keyboard and orientation changes. |
| Map canvas | `UniverseConstellationView` lays out from its container `GeometryReader`; background can extend full bleed. | Map nodes must remain tappable/readable with overlay controls. Current layout has fixed geometry bands that need a future `MapLayoutContext`. |
| Map chrome and dock | `UniverseOverlayView` layers functional chrome over map. | Controls respect safe areas and keyboard; content may remain beneath floating chrome only when readable/hittable. |
| Compact detail | Current `UniverseMapView` uses bespoke `.fraction(0.72), .large` detents. | Diverges from `AdaptiveLayout.sheetDetents`; record as SC-007. Do not silently normalize during unrelated work. |
| Regular detail | A trailing `RootSheet` inspector is used on regular width. | Preserve readable width and avoid treating iPad as a stretched iPhone sheet. |
| Reading content | `AdaptiveLayout.readableContentMaxWidth` documents a max reading width. | Use adaptive stacks/grids/`ViewThatFits`/container-relative layout before fixed device dimensions. |
| Typography expansion | Components have local line limits and some Dynamic Type caps. | Test localization, Bold Text, and accessibility sizes; future fixes must be component-specific, not a global clamp. |

## Safe-area, keyboard, and orientation policy

- Use system containers, `safeAreaInset`, system presentations, and content
  margins where they match the interface. Backgrounds may ignore safe areas;
  primary controls and readable content may not.
- Keyboard appearance must preserve the composer's visibility without adding
  magic status-bar or device-height offsets. A scroll/dismiss gesture must not
  fight a transition-dismiss gesture.
- Treat compact/regular width, orientation, and external-window changes as
  environment changes. Do not choose layout by a named iPhone model.
- Absolute position is appropriate for the deterministic constellation's
  visual geometry, but not as a general form/list/navigation layout strategy.

Apple's [Layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout)
is the external reference for respecting safe areas and adapting to system
geometry. The source of record for any project measurement remains the cited
component or a documented product decision.

## Before adding a layout value

State its semantic role, scope, adaptive behavior, Dynamic Type behavior, and
verification device matrix. Add a project token only when the relationship is
actually reused; retain local contextual geometry when it is intrinsic to the
map or a system component.

