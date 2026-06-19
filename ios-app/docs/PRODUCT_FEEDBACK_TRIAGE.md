# PRODUCT_FEEDBACK_TRIAGE

Master triage for the 2026-06-19 product feedback round. Splits feedback into
strict domains, assigns severity + dependency order, and points each domain at
its detailed spec. **No broad multi-domain commits** — each domain is fixed in
isolation per `IMPLEMENTATION_ROADMAP.md`.

Severity: **Critical** (broken core loop / data integrity) · **High** (premium
feel / primary UX) · **Medium** (polish) · **Low** (nice-to-have).

## Domains

| # | Domain | Spec | Owner | Severity (worst item) |
| - | --- | --- | --- | --- |
| 1 | Ask AI intelligence | `CHAT_AI_SPEC.md` | Claude (logic) → Codex (UI chips) | High |
| 2 | Chat bubbles / input / attachments | `CHAT_INPUT_SPEC.md` | Codex | High |
| 3 | Add Tool flow | `ADD_TOOL_SPEC.md` | Claude (state) → Codex (UI) | **Critical** |
| 4 | Tool Detail screen | `TOOL_DETAIL_SPEC.md` | Codex | High |
| 5 | Icons / logos | `TOOL_DETAIL_SPEC.md` (§Logos) | Codex | Medium |
| 6 | Universe visualization | `VISUALIZATION_SPEC.md` | Claude (mode arch) → Codex | High |
| 7 | Right rail | `RIGHT_RAIL_SPEC.md` | Codex | High |
| 8 | Profile / settings | `SETTINGS_PROFILE_SPEC.md` | Codex | Medium |

## Findings by domain (severity + fix-first flags)

### 3. Add Tool flow — **CRITICAL, FIX FIRST**
- **C-1 (Critical):** added tool (e.g. PostHog) still reported "does not exist" by chat/search after add. Data-integrity break of the empty-start product. Likely: `UniverseAssistantCore` / `SearchCore` read a stale or seed-only collection instead of `model.visibleAllTools`, OR id collision with the sample seed (`posthog` already exists in the bundled sample). → Source-of-truth issue, must land before chat work.
- **C-2 (High):** Auto/Manual control reads inverted (`AddToolSheet.usesAutoBranch`). Tapping "Manual" must select Manual.
- **H (High):** Auto classification should use name + website + universe context.
- Depends on nothing; everything in domains 1/4 depends on this being correct. **Fix-first.**

### 1. Ask AI intelligence — High
- AI must answer from full app data (all tools, added, history, classifications, categories, pricing, strengths/tradeoffs, related).
- Structured recommendations (have / missing / paid-free / fast-slow / simple-advanced / tradeoffs).
- Tool names → tappable chips: existing→open detail, missing→Add.
- "Open tool detail" from chat is missing/hard to find.
- Depends on **domain 3** (added tools must be in the data set) + **domain 2** (chips render in bubbles).

### 2. Chat bubbles / input / attachments — High
- User messages as auto-layout bubbles, content-fit width, correct alignment, no excess L/R space.
- Assistant messages readable/structured (markdown).
- Collapse works; **expand/reopen broken**.
- Input focus → wrong darkening (regression of the `UniverseMode.chatOpen` dim contract).
- Attachment icon/menu/state wrong; Add tool / Attach files can duplicate; send/plus unclear.
- Mostly self-contained UI; chips (domain 1) render here.

### 4. Tool Detail screen — High
- Too much ungrouped data, weak hierarchy, hard headings, weak pricing, competing colored blocks.
- Pricing → structured plan table (Free / Pro / Team / Enterprise / Unknown).
- Consistent block component, emphasize titles not random backgrounds; metadata secondary; clear primary CTA.
- Self-contained (`ToolDetailSection`, `RootSheet`).

### 5. Icons / logos — Medium (folded into domain 4)
- Tool logo missing/wrong; show real logo if available else high-quality category/initials fallback (`ToolMonogram` exists, monogram-only today — no network logo fetch on iOS yet).
- Consistent category icon; chips show icons.

### 6. Universe visualization — High
- 3D still bad: overlap, buggy rotation, square artifacts, clipping, unclear labels, rail/map conflict.
- Add **2D Graph Mode** fallback (clean animated node graph, organic connecting lines) + settings toggle.
- Readability > fake 3D; 3D must not be default while broken.
- Mode architecture = Claude; 2D renderer + 3D cleanup = Codex.

### 7. Right rail — High
- Long-press + vertical drag; inactive pinned to absolute right edge; active text right-aligned (not centered); selected stronger right offset, neighbors less; anchored-to-edge feel.
- Over-dims screen; drag/scroll buggy; selected category must sync chips/card/map.
- Builds on `UI_STATE_MACHINE` selection source-of-truth.

### 8. Profile / settings — Medium
- Visualization setting does nothing → make functional (ties to domain 6) or disable.
- Language: "System" unclear; EN/RU should actually localize if implemented.
- Haptics on/off feels identical.
- Presets (Atlas/Overlay/Kinetic/Pockets) change little → make visibly different or disable.
- "Load sample" ok. Saved/switchable universes = deferred.

## Dependency order (what unblocks what)

```
domain 3 (Add Tool source-of-truth)  ── unblocks ──▶ domain 1 (Ask AI data) , domain 4 (detail of added tools)
UI_STATE_MACHINE selection truth      ── unblocks ──▶ domain 2 , domain 7
domain 2 (bubbles + chips host)       ── unblocks ──▶ domain 1 chips UI
domain 6 mode architecture            ── unblocks ──▶ domain 8 Visualization setting
```

## Fix-first order (condensed)
1. **Domain 3 Add-Tool source-of-truth** (Critical C-1) — make added tools instantly real everywhere.
2. **Domain 2 chat input/bubbles** (self-contained, hosts chips).
3. **Domain 1 Ask AI intelligence** (needs 3 + 2).
4. **Domain 4 + 5 detail/pricing/logos**.
5. **Domain 7 right rail**.
6. **Domain 6 visualization 2D fallback + 3D cleanup**.
7. **Domain 8 settings** (Visualization setting after 6).
8. Regression QA.

Full sequencing, owners, files, acceptance, QA: `IMPLEMENTATION_ROADMAP.md`.
