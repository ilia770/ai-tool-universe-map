# CHAT_INPUT_SPEC

> **Historical/mixed-state notice — 2026-07-16.** This record may describe a
> superseded dock implementation. Use `INPUT_CHAT_SPEC.md`,
> `INTERACTION_SPEC.md`, and `STATE_OWNERSHIP.md` for current behavior.

Owner domain: the bottom AI assistant **input dock** — the composer field, the
paperclip attachment menu, and the attachment preview. This is the visual +
interaction spec for the input surface and its attachment states.

File in scope: `UI/Search/SearchDock.swift` (state rules in
`UI/Search/SearchCore.swift → ComposerLogic`). Do NOT edit the universe
rendering, right rail, detail screen, or assistant answer logic here.

Cross-refs:
- `LIQUID_GLASS_VISUAL_SPEC.md` — the "input", "floating panel", and "chip"
  styles this spec applies. The composer must conform to those token rules.
- `INPUT_CHAT_SPEC.md` — the existing dock behavior spec (focus / black-screen
  rule, send-vs-add-tool button, parent-driven chat visibility, bubble sizing).
  This spec **supersedes the visual treatment** of the composer/attachment and
  the attachment-preview shape; INPUT_CHAT_SPEC's behavior rules still hold.
- `CHAT_AI_SPEC.md` — copy-action feedback (the "Copied" confirmation on
  assistant message copy) belongs there, **not** here.

---

## 1. The composer (input field)

### Current state (`SearchDock.swift → composer`, ~L184–221)

The field is a `glassSurface(in: Capsule(), tint: accent.opacity(0.5),
interactive: true)` **layered on top of** a separate
`.background(.black.opacity(0.12), in: Capsule())`, with a drop shadow. The
accent tint plus the black backing plate behind translucent glass produces a
muddy capsule with a faint colored "glowing outline" — not clean Apple glass.

### Required

A single, clean dark-translucent capsule:

- One surface only: `glassSurface(in: Capsule(), interactive: true)`.
- **Remove** the accent `tint:` argument (no colored glass).
- **Remove** the `.background(.black.opacity(0.12), in: Capsule())` backing
  plate — the glass material already provides the dark translucency. No
  double-backing.
- Keep exactly one soft float shadow: `black.opacity(~0.26)`, radius ~14,
  y ~8. No accent shadow, no second stroke (system glass owns its edge on
  iOS 26).
- Min height 44; inner padding ~5; `BrandRadius.glassControl` is the conceptual
  corner (Capsule is fine for the pill form).
- Accent appears **only** as the field's text `.tint(accent)` (caret +
  selection) — never as fill, border, or glow.
- Placeholder "Ask AI Universe" in muted white; entered text `white`.

Result: a calm dark glass capsule, no strange glowing outline, accent visible
only when the cursor blinks.

### Paperclip trigger (inside the capsule)

- Leading control inside the capsule: a `paperclip` glyph (stable — never
  flips to plus/file/photo; `ComposerLogic.attachmentTriggerIcon` already
  pins it).
- Idle glyph `white 0.74`; when an attachment exists, glyph switches to the
  accent **color only** (tiny highlight), shape unchanged.
- Sits in a neutral `white 0.08` `Circle()` (no nested glass — avoids
  double-lensing inside the glass capsule). 36×36 hit target.

### Trailing button

Out of scope visually-new here; governed by `INPUT_CHAT_SPEC.md` (Send when
focused / has text / has attachment, else Add-tool) and the "Button → primary
action" style in `LIQUID_GLASS_VISUAL_SPEC.md` (filled accent = active
affordance; this is the *allowed* accent fill).

---

## 2. Attachment menu (small Liquid Glass menu above the input)

### Current state (`attachmentMenuPopover`, ~L244–287)

A floating popover anchored to the composer top (good), but painted as a
`black.opacity(0.30)` plate **under** a `glassSurface(tint: accent.opacity(0.34))`
— an over-tinted, double-backed panel.

### Required

A small **Liquid Glass floating panel** (style 4 in the visual spec) that opens
**above** the input:

- Single `glassSurface(in: RoundedRectangle(cornerRadius: BrandRadius.nested or
  20, .continuous), interactive: true)`. **Remove** the `black.opacity(0.30)`
  backing plate. Tint dropped (or ≤ 0.12 neutral).
- One soft shadow (`black ~0.30`, radius ~16, y ~8) to lift it.
- Anchored to the composer's top with an ~8pt gap (keep the existing
  `.overlay(alignment: .bottomLeading)` + alignment-guide float; it must not
  push the composer down or cover the keyboard).
- Two items only, neutral rows that highlight on press (chip style):
  - **Photo** (`photo` glyph)
  - **Files** (`doc` glyph)
- Dismisses on outside tap, on select, on send, and when the transcript is
  tapped (existing behavior — keep). It must **not** stay open after a pick or
  a remove.
- Width ~164, internal padding ~7, item radius via `Capsule()`.

(The "Remove attachment" row currently inside this menu is replaced by the
remove button on the floating preview — see §3. Keep a remove path reachable;
preferred home is the preview's remove control.)

---

## 3. Attachment preview (floating Liquid Glass, above the input)

### Current state (`attachmentPill`, ~L347–372)

When an attachment is selected it shows a tiny `accent.opacity(0.28)` capsule
pill **inside** the composer capsule (icon + short title). It is over-tinted
and cramped against the text field; there is no real preview (no thumbnail, no
type, no distinct remove affordance).

### Required

Replace the in-capsule pill with a **floating Liquid Glass attachment preview**
that sits **above the input** (same float lane as the attachment menu, mutually
exclusive with it), so it never covers the chat awkwardly:

- A single `glassSurface(in: RoundedRectangle(cornerRadius: BrandRadius.nested,
  .continuous), interactive: true)` card (floating-panel style), one soft
  shadow, no accent backing.
- Contents, left → right:
  - **Thumbnail / type glyph** — a small rounded square (~36×36) showing the
    photo thumbnail when a Photo is attached, or the file-type glyph (`doc`)
    on a neutral `white 0.08` square for a File.
  - **Name + type** — two lines: file/photo name (or "Photo" / "File"
    placeholder) in `textPrimary`, secondary type/size line in `textMuted`.
    Truncate the name with tail ellipsis; never wrap to many lines.
  - **Remove button** — a trailing `xmark` in a neutral `white 0.08`
    `Circle()` (style: glass icon button), `accessibilityLabel("Remove
    attachment")`. This is the primary remove affordance.
- Anchored above the composer with an ~8pt gap; floats (no layout footprint on
  the composer row, same overlay pattern as the menu). Width follows the dock,
  not full-bleed.
- Accent only as a tiny highlight if needed (e.g. type glyph tint) — never as
  the card fill.
- Dismisses cleanly: tapping remove animates it out (`BrandMotion.nudge`) and
  returns the paperclip glyph to its idle `white 0.74`.

The composer capsule itself stays clean and text-only while an attachment is
staged — the staged item lives in the floating preview, not inside the field.

---

## 4. The four explicit states

The input dock has exactly these visual states. Transitions use
`BrandMotion.nudge`; all respect Reduce Motion / Reduce Transparency via the
existing Brand helpers.

| State | Composer | Paperclip glyph | Floating layer above input | Trailing button |
|---|---|---|---|---|
| **A — No attachment** | Clean glass capsule, no tint, no backing, accent only as caret tint when focused | `paperclip`, `white 0.74` | none | Send if focused/has text, else Add-tool |
| **B — Menu open** | unchanged (capsule stays put) | `paperclip`, `white 0.74` | Attachment **menu** panel (Photo / Files), glass, floating, 8pt above | unchanged |
| **C — Attached** | unchanged clean capsule, text-only | `paperclip` in **accent color** (tiny highlight) | Floating **preview** card (thumbnail + name/type + remove), glass, 8pt above; menu closed | Send (enabled — has attachment) |
| **D — Removed** | clean capsule | back to `paperclip` `white 0.74` | none (preview animated out) | Send if focused/has text, else Add-tool |

Rules across states:
- Menu (B) and preview (C) are **mutually exclusive** — opening one closes the
  other; both occupy the same float lane above the composer.
- Selecting Photo/Files in B transitions B → C (menu out, preview in).
- Remove in C transitions C → D → A; the paperclip never sticks in the accent
  color after removal.
- Send while attached (C) clears the attachment and returns to A
  (`clearComposer` already nils `selectedAttachment`).
- State enablement is owned by `ComposerLogic` (`canSend`, `showsSendButton`,
  `showsRemoveAttachment`) — do not duplicate the rules in the view.

---

## 5. Affected files

- `UI/Search/SearchDock.swift`
  - `composer` — remove tint + black backing; keep single glass capsule + one
    shadow; accent only as text tint (§1, fixes `LIQUID_GLASS_VISUAL_SPEC.md`
    correction C1).
  - `attachmentMenu` (paperclip) — accent-color glyph only when attached (§1).
  - `attachmentMenuPopover` — drop black plate + heavy tint; single glass panel
    (§2, correction C3).
  - `attachmentPill` → **replace** with the floating preview card `attachment
    Preview(kind:)` above the composer (§3, correction C4).
  - `composerWithAttachmentOverlay` — host the mutually-exclusive menu/preview
    in the existing overlay lane above the composer (§3, §4).
- `UI/Search/SearchCore.swift → ComposerLogic` — no new logic required; reuse
  `showsSendButton`, `canSend`, `showsRemoveAttachment`,
  `attachmentTriggerIcon`. If a preview-vs-menu mutual-exclusion helper is
  added, put it here (testable, Foundation-only) rather than in the view.

No other files change for this spec.

---

## 6. Acceptance criteria

1. The composer is a single clean dark-translucent glass capsule: **no** accent
   tint, **no** `black.opacity` backing plate, **no** strange glowing outline.
   Accent is visible only as the focused caret/selection tint.
2. Tapping the paperclip opens a small Liquid Glass menu **above** the input
   listing **Photo** and **Files**; it floats (composer does not move), does
   not cover the keyboard, and dismisses on outside tap / select / send.
3. Selecting a Photo or File shows a **floating Liquid Glass attachment
   preview** above the input with a thumbnail/type glyph, name/type, and a
   remove button — it does not cover the chat awkwardly and does not crowd the
   text field.
4. Remove dismisses the preview cleanly and returns the paperclip to its idle
   state; the menu and preview are never both visible at once.
5. All four states (no attachment / menu open / attached / removed) render and
   transition exactly as the table in §4; Send enablement matches
   `ComposerLogic`.
6. Reduce Transparency yields a legible opaque composer/menu/preview via
   `glassSurface`; Reduce Motion respected.
7. Copy-action feedback is **not** implemented here — it lives in
   `CHAT_AI_SPEC.md`.

---

## 7. Manual QA steps

1. Tap input → keyboard rises; composer is a calm dark glass capsule with no
   colored glow; caret tint is the category accent.
2. Tap paperclip → glass menu (Photo / Files) floats above input over nothing
   important; composer stays put.
3. Pick Photo → menu closes, a floating preview card appears above the input
   with thumbnail + name/type + remove; paperclip glyph turns accent-colored.
4. Tap remove on the preview → preview animates out, paperclip returns to
   neutral; no stuck menu/preview.
5. Pick Files → preview shows the file-type glyph + name; Send is enabled.
6. Send while attached → attachment clears, returns to clean empty composer
   (state A).
7. Confirm menu and preview are never visible simultaneously.
