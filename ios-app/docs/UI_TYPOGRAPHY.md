# UI_TYPOGRAPHY — Semantic type contract

**Status:** baseline mapping, 2026-07-17.  
**Source:** `UI/Theme/BrandTypography.swift`. The app uses system fonts through
SwiftUI; no Apple font files are bundled or redistributed.

| Semantic role | Current SwiftUI style | Weight / behavior | Use and verification |
| --- | --- | --- | --- |
| Large sheet title | `.largeTitle` | semibold | major modal title; wraps rather than relying on fixed width. |
| Sheet/display title | `.title` | semibold | detail/settings headings; current detail allows two lines. |
| Empty-state invitation | `.title` rounded | semibold | intentionally limited friendly variant. |
| Section title | `.title3` | semibold | content hierarchy, not navigation replacement. |
| Primary reading text | `.body` | regular | descriptions and paragraphs; Dynamic Type. |
| Secondary reading text | `.callout` | regular | summaries and supporting copy; Dynamic Type. |
| Control/chip label | `.subheadline` / `.footnote` | semibold | controls must retain adequate hit targets independently of visible glyph size. |
| Constellation label | `.caption`, `.footnote`, `.caption2` | medium/semibold/regular | compact map labels; test overlap/truncation at accessibility sizes. |
| Eyebrow | `.caption2` | semibold, uppercase/kerning | concise section kicker only; avoid for essential long text. |
| Data/counter | `.callout` monospaced | regular | compact numerical/readout content. |

## Rules

- Prefer these semantic styles to fixed `system(size:)` values. If a custom
  size is necessary, document its role, relative scaling policy, line behavior,
  localization risk, and accessibility test.
- State line limit, truncation strategy, alignment, and expansion behavior for
  every text-bearing reusable component. Do not use a shrinking scale factor
  as the sole accessibility strategy.
- Test English expansion, future localization expansion, Bold Text, and
  Dynamic Type in compact and regular layouts.
- Current component-local caps (`xxxLarge` in constellation, `accessibility1`
  in `PlanetInfoCard`, `accessibility2` in detail) are baseline facts, not an
  approved global accessibility policy. Each requires a future evidence-based
  review.

Apple's [Typography guidance](https://developer.apple.com/design/human-interface-guidelines/typography)
is the external reference for semantic hierarchy and system text behavior.

