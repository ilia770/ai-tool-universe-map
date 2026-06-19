# TOOL_DETAIL_SPEC

Owner: Codex. Files: `UI/Sheets/ToolDetailSection.swift`, `UI/Sheets/RootSheet.swift`,
`UI/Sheets/ToolLogoView.swift` (logo/monogram). Supersedes `DETAIL_SCREEN_SPEC.md`.
Do NOT edit chat, rail, scene, or `UniverseViewModel` selection logic here.

## Goal
A **premium tool profile**, not an admin dashboard. Strong hierarchy, one
consistent block component, pricing as a real plan table, correct logo,
unmistakable primary action.

## Information hierarchy (top → bottom)
1. **Header** — logo (or monogram fallback) · tool name (display type) ·
   category eyebrow · primary action(s) right-aligned.
2. **One-line value** — `summary`, prominent.
3. **Pricing** — structured plan table (below). High priority, currently weak.
4. **Best for / Killer features / Strengths** — grouped, scannable.
5. **Tradeoffs** — secondary tone.
6. **Connected sources** (related tools) — chips → open each.
7. **Metadata** — collapsed/last (category, stage, orbit, source domain, "why
   it belongs"). Visually quiet.

## Visual system (kill the competing colored blocks)
- **One block component** reused for every section: same corner radius, same
  surface (subtle glass fill), same internal padding, same title style.
- **Emphasis via typography, not background color.** Section title = bold,
  slightly larger, category-tinted icon; body = neutral. Accent color appears
  only in the title icon / a thin rule / the selected pricing plan — never as
  large competing fills.
- Consistent section heading style across the whole sheet (the current
  hard-to-read headings get one shared `sectionHeader` view).

## Pricing table (structured plans)
Render `ToolKnowledge.pricing` (free text today) through the **shared
`PriceTier`/plan parser** (same one used by `CHAT_AI_SPEC.md`):
- Rows: **Free / $0** · **Pro / ~$X** · **Team / ~$X** · **Enterprise / custom**.
- Each row: plan name · price · one-line "what you get" if known.
- Unknown/unverified plan → row shows **"Unknown"** (never a guessed number).
- If pricing is entirely unparseable → a single "Pricing not verified" row +
  the raw text in metadata.
- Table styling = the shared block component (aligned columns, quiet borders),
  visually consistent with the rest of the sheet.

Parser lives in a pure helper (`PricingPlans.parse(_:) -> [PricingPlan]`),
unit-tested with real `ToolKnowledge.pricing` strings from the seed.

## Logos / icons (domain 5)
- **Real logo if available:** if `logoDomain` is set, fetch a logo
  (Logo.dev-style publishable key, mirroring web `tool-logos.ts` —
  publishable key only, never a secret in the bundle). Async load, cached.
- **Fallback:** `ToolLogoView` + `ToolMonogram.initials(for:)` — high-quality
  category-tinted monogram. This is the canonical icon today and stays the
  graceful fallback (load fail / no domain).
- **Category icon:** one consistent SF Symbol (or asset) per category, reused
  in header eyebrow, chips, and the rail. Define the category→icon map once.
- **Chips** (chat + connected sources) show the same logo/monogram + name.

## Primary actions
- **Open** — in-app browser (`InAppBrowserSheet`), the clear primary CTA when a
  url exists. Already wired; keep it the visually-dominant action.
- **Remove** — destructive, with confirmation (exists); secondary styling.
- (Optional) **Ask AI about this** — seeds a chat query; nice-to-have, defer.
- Actions live in a fixed action row, not buried; on iPad they sit in the
  trailing inspector panel (`UniverseMapView` adaptive layout).

## Acceptance criteria
- Every section uses the one shared block component; no large competing color fills.
- Pricing renders as aligned plan rows (Free/Pro/Team/Enterprise/Unknown), no guessed numbers.
- Header shows real logo when `logoDomain` resolves, else category monogram.
- Section headings legible + consistent across the sheet.
- Metadata visually subordinate (quiet, grouped, last).
- Primary "Open" CTA obvious; remove confirmed.

## Manual QA
1. Open a tool with known pricing → plan table with correct tiers.
2. Open a tool with unknown pricing → "Unknown"/"not verified", no fake numbers.
3. Tool with `logoDomain` → real logo; without → clean monogram.
4. Scan the sheet → clear title→body hierarchy, metadata quiet, no rainbow of blocks.
5. Tap a connected-source chip → its detail opens.
