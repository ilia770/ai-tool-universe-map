# Glass redesign — device-QA findings + fix plan (handoff)

Date: 2026-06-25. Owner handoff for Codex / next session.

## Context
The Liquid Glass morph redesign (foundation #122 + surfaces #129) is **merged to `main`** (`5a04b1a`). A device walkthrough by the user (5min16s screen-recording **with voiceover**) revealed the redesign is **broadly buggy** — visual + functional + UX, far beyond spacing. This doc is the evidence + the fix plan.

**Evidence sources:** user voiceover transcript (RU, whisper) + 8 parallel frame-analysis agents over 633 frames (2fps). Full raw inventory: was at `scratchpad/glass-bug-inventory.md` (session-local).

**Process lesson (do NOT repeat):** the redesign was squash-merged to `main` WITHOUT the per-surface device-test the spec required (spec step 7 = "user device-tests morph feel → merge"). Device-test then surfaced everything below. **Rule going forward: every fix lands on a branch, user device-tests, THEN merge. Never merge glass/visual work to main unverified on a real device.** (Simulator glass lensing is unreliable — see env gotchas in memory.)

---

## BUG INVENTORY (confirmed by frames + voiceover)

### A. GLASS RENDERING — "залито" (core)
- **A1. Content/HUD surfaces are flat opaque fills, no back-blur.** User: "все области как будто залиты, должны быть поверх с задним блюром лёгким." Root: surfaces used solid color fills (`BrandColor.glassSolid` opaque, `BrandColor.card` = `white.opacity(0.06)`, `muted` = `0.035`) with NO blur material. The redesign deliberately made content solid (`glassSurface` doc: "glass = floating controls only; content stays solid"). User wants the opposite. **← BEING FIXED THIS SESSION (see below).**
- **A2. Top buttons (X close / +Add) look like "two borders / double stroke"; morph highlight overshoots & clips at screen edge.** Frames: travelling glass highlight lands off-edge on +Add / X. Root: `GlassMorphCluster` / `navigationGlassMorphID` highlight + `glassSurface` stroke. Files: `GlassMorphCluster.swift`, `LiquidGlass.swift` (`navigationGlassMorphID`).

### B. TRANSITIONS — crossfade double-render (systemic, HIGH)
- **B1. Surface/morph transitions render BOTH old+new states at once → text-on-text.** Account Settings↔History full overlap (t≈4:10); branch card "Founder OS" over "Одло" (t≈3:14); chat-insert ghosting; launch overlap. Root: crossfade/morph removes the old layer too late (opacity-only). Likely `BrandMotion`/`.brandAnimation` + the section `switch` swapping subviews without a clean transition.
- **B2. `GlassMorphCluster` shows EMPTY pills (labels vanish) mid-switch** (Settings/History blank t≈4:08; Ask AI|Map blank t≈4:26). Root: cluster's travelling-glass morph drops label content during the transition. File: `GlassMorphCluster.swift`.
- **B3. "Mini-window opens at top, should open all at once"** (voiceover) — some surface reveals partially/staged instead of atomically.

### C. COMPOSER / SearchDock (HIGH)
- **C1. Composer input area is GIGANTIC with ~50-60% dead empty space**, content bottom-anchored, height does not track content. User: "огромная область, почему-то гигантская." File: `SearchDock.swift`.
- **C2. Composer does NOT clear after send** — sent text stays in the field. User confirmed. File: `SearchDock.swift` (send handler / binding reset).
- **C3. Oversized composer occludes/clips the chat transcript** (covers last messages).
- **C4. Paperclip/attach icon renders tiny & rotated in the corner** during scroll/send.
- **C5. Scroll-to-bottom / "down" button behaves oddly** ("съезжает вверх" / "перематывает вниз").

### D. CHROME / CLUSTERS (layout)
- **D1. Top chrome pills overlap map node labels** — "Research" clipped under the "2D Graph|3D Spatial" pill (persistent). Root: chrome floats over content with no safe-area inset for node labels. File: `UniverseOverlayView.swift` (`topChrome`).
- **D2. "3D Spatial" cluster pill is CRAMPED** — title wraps to "3D"/"Spatial", "Experimental" badge breaks "Experimen/tal". Root: `GlassMorphCluster` doesn't size to long labels / no min width. Files: `GlassMorphCluster.swift`, render-mode cluster in `UniverseOverlayView.swift`.
- **D3. Settings|History cluster "too close to each other"** (voiceover) — cluster/options spacing too tight.
- **D4. AddTool floating "Next"/"Add" button overlaps content** — clips the "Manual" pill, covers "Relation logic" text. Also "Next перешагивает очень быстро" (steps too fast). File: `AddToolSheet.swift` (keyboard-accessory action button z-order).

### E. CONTENT / DENSITY / TEXT
- **E1. Too much text, "suffocating", unreadable; detail-sheet content "doesn't fit us."** Reduce copy / density across cards & detail.
- **E2. Copy text unreadable.**
- **E3. Pluralization: "1 tools" / "1 satellites"** → singular. Grep node/branch label builders.
- **E4. Language label truncated** "Follow device l..." — `AccountSettingsSheet` Language picker segment.
- **E5. Upgrade popover unclear / tail anchors to wrong spot** — `AccountSettingsSheet` planGroup.

### F. FUNCTIONAL (likely PRE-EXISTING, NOT glass — SEPARATE TRACK, do AFTER visual)
- **F1. "Ask AI" does nothing** (onboarding/chat action no-op).
- **F2. Cannot navigate back from 3D to the map** ("непонятно как вернуться").
- **F3. Deleted GitHub REAPPEARS in 3D** — stale data / 3D not synced to tool removal.
- **F4. Send is broken in 3D** ("посылаю текст — не посылается").
- **F5. GitHub tool icons not displaying correctly.**

### G. 3D / Track A (experimental, separate)
- **G1. Empty 3D scene on return** (no planet, stray flat orbit lines, orphan label). HIGH for 3D.
- **G2. 3D orbit rings z-fight / clip through the planet.**

---

## Root-cause clusters (few roots → many symptoms)
1. **Flat solid fills, no blur material** → A1.
2. **`GlassMorphCluster` morph + `glassSurface` stroke** → A2, B2, D2, D3.
3. **Crossfade transition removes old layer too late** → B1, B3, launch/card/tab ghosting.
4. **`SearchDock` composer layout + send-clear** → C1–C5.
5. **Chrome z-order / no safe-inset over the map** → D1.
6. **Content density / copy** → E1, E2.
7. **Pre-existing functional** → F1–F5 (separate debugging track).

---

## DECISION (user, 2026-06-25)
1. **Fix A1 first only** → user re-tests on device ("maybe half the problems fall away") → then decide the rest.
2. **Functional bugs (F) = separate track AFTER visual.**

## WHAT THIS SESSION DID — A1 fix (branch `fix/glass-a1-translucent`, base `main` `5a04b1a`)
Swapped flat opaque fills → translucent frosted material so the universe shows through (light back-blur):
- `SearchDock.swift` composer transcript: `BrandColor.glassSolid` → `.ultraThinMaterial`.
- `PlanetInfoCard.swift` (the OVERVIEW / branch HUD card over the map): `BrandColor.glassSolid` → `.ultraThinMaterial`.
- `AccountSettingsSheet.swift`: sheet root `BrandColor.void` → `BrandColor.glass` (0.76 dark translucent tint) + added `.presentationBackground(.ultraThinMaterial)` so the backdrop frosts through.
- `AddToolSheet.swift`: same sheet treatment as Account.
Status: compiles + unit suite green (verify on QA265). **NOT merged — awaiting user DEVICE test.** Tuning knobs for the re-test: the `BrandColor.glass` tint opacity (0.76 → lower = more blur-through, higher = more legible), and whether to also frost the inner cards (`BrandColor.card` sites at `AccountSettingsSheet:359`, `AddToolSheet:272/439/479` — left solid for legibility this pass).

## REMAINING PLAN (for Codex, in priority order — each on its own branch + device-test before merge)
1. **A2 + D2 + D3 + B2 (GlassMorphCluster polish)** — fix the travelling-highlight edge-clip/double-stroke, size pills to content (min width, no wrap for "3D Spatial"/"Experimental"), label-stable morph (no empty pills mid-switch), looser option spacing. File: `GlassMorphCluster.swift` (+ callers). **In progress on `fix/glass-a2-morph-cluster-polish`: active glass lens moved behind the selected option only, labels stay outside the morph, spacing loosened, `3D Spatial`/`Experimental` forced one-line. Build + targeted cluster UI tests + full unit verify green; awaiting device-test.**
2. **C (composer)** — `SearchDock.swift`: height tracks content (kill the giant dead space), clear field after send, don't occlude transcript, fix paperclip glyph, fix scroll-down button. HIGH user impact. **In progress on `fix/glass-c-composer-polish`: local Ask AI now clears `assistantQuery` after sending, regression test added, composer field no longer requests its max height up front. Targeted `UniverseViewModelTests` + `ComposerLogicTests` green; full verify green. Awaiting device-test for live keyboard/composer feel.**
3. **B1/B3 (transition crossfade)** — stop double-render; use a clean transition (remove old layer before/with new), atomic reveals.
4. **D1 + D4 (chrome/sheet overlap)** — safe-area inset so chrome doesn't cover node labels; dock the AddTool action button clear of scroll content.
5. **E (content/density + pluralization + truncation)** — reduce copy, fix "1 tool(s)"/"1 satellite(s)", Language label width, Upgrade popover anchor.
6. **F (functional, SEPARATE track, systematic-debugging each)** — Ask AI no-op, 3D→map back nav, deleted-tool reappears in 3D, 3D send broken, tool icons. Likely pre-existing; not glass.
7. **G (3D/Track A)** — empty-scene-on-return, orbit z-fighting. Separate, experimental.

Use `superpowers:systematic-debugging` per item; reproduce on device/video first. Re-extract frames from the user's recording with `ffmpeg` if needed (whisper-cli + ggml-small model are installed for voiceover transcription).
