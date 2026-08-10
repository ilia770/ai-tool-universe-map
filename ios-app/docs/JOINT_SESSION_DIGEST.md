# Joint Session Digest — `polish/day-sprint`

Closes LOOP_QUEUE slice 8.2. One-page brief so the next in-person session with
the user is efficient: what landed, what's blocked and why, and every decision
waiting on the user. Source of truth for detail: Linear (slice states; `LOOP_QUEUE.md` was
retired 2026-08-09, its open items were filed into Linear on 2026-08-10 and
the holding file deleted) + `LOOP_LOG.md` (per-cycle history).

_Generated 2026-07-05. Branch is 60 commits ahead of `origin/main`, not pushed,
no PR._

## 1. What shipped (10 productive commits, all compile-gate green)

**Bloom 2D renderer** (variant K — progressive-reveal force graph) wired in as the
default `graph2D` renderer, replacing `ConstellationView`, then hardened:

| Commit | What |
| --- | --- |
| `b60f8a9` | BloomEngine expand/collapse stack-invariant tests (+8) |
| `2fe78c1` | os_signpost intervals `bloom.tick` / `bloom.layout` |
| `7a3f74b` | memoize graph model off the per-frame draw path (killed a real per-frame `BloomAdjacency.build` rebuild) |
| `104daed` | engine guard tests: tap-focus, collapseTo clamp, reset, collapsing edges (+4) |
| `9e0ba90` | settle-cap — skip force integration when the graph is at rest (+5 tests incl. resume-on-mutation guards) |
| `4cb55cd` | `edges(from:)` overload — build adjacency once per tool-set change, not twice |
| `f8bba44` | **fix:** distinct-named tools sharing a URL host now coexist (was silently dropping the new one) |
| `98c86b8` | tokenize 39 exact-match paddings across 13 views → `BrandSpacing` (value-preserving) |
| `78d6ba9` | copy: unify tool-detail label `Category` → `Branch` (lone outlier vs 10+ canonical) |
| `ed4ac57` | doc: VISUALIZATION_SPEC notes graph2D now renders via BloomGraphView |

`BloomEngineTests` now 22 cases; 45 test files total. Perf work removed a
per-frame hot-loop and stops the sim burning CPU when idle.

## 2. Decisions waiting on the user

- **1.6 — retire `ConstellationView`?** Bloom is the live default. If Bloom is the
  permanent keeper, `ConstellationView` (+ its tests) is dead code to delete —
  one more green slice. Needs the user to confirm Bloom stays.
- **7.2 — 4 subjective copy calls** (subagent correctly refused to guess):
  1. "Load sample universe" vs "Load **a** sample universe" (1-vs-1, no winner)
  2. pricing slash spacing — "Paid/cloud" vs "Subscription / usage" (typographic taste)
  3. "map" vs "universe" for the user's collection (brand voice)
  4. "Add Tool" (title-case title) vs "Add tool" (sentence-case a11y label) — may be intended
- **Publish the branch?** 60 commits are local-only with no PR. Recommend push +
  open PR so the work isn't stranded and can get full-sim CI validation.

## 3. Blocked, not forgotten — needs a free simulator + the user's eye (16 slices)

The full-sim gate and all visual/device work are blocked by a **3-sim RAM wall**:
the MultTracker loop on this same Mac keeps both iOS-26.5 sims booted, so a
dedicated AIMapGate sim won't boot (hangs at BackBoard), and its builds keep disk
oscillating 3–6 GiB. **Freeing the two `Mult-*` sims unblocks ~80% of the remaining
backlog at once.**

- **Bloom visual:** 1.1 screenshot baseline, 1.3 tier hierarchy/legibility,
  1.4 auto-fit/no-clip camera bounds, 1.5 frame-rate-independent motion
  (real bug found: view passes fixed `dt: 1/60`, engine ignores dt → animations
  run ~2× on 120 Hz ProMotion; fix needs integrator-stability visual confirmation),
  6.7 idle TimelineView redraw.
- **3D:** 2.1 default camera 3/4 orbit, 2.2 top-chrome declutter, 2.3 depth cues.
- **Sheets:** 3.2 Add Tool keyboard/​"New branch" reach, 3.3 tool-detail density +
  Account segmented control.
- **A11y runtime:** 4.1 VoiceOver labels/traits, 4.2 Dynamic Type at XXL,
  4.3 reduce-motion/-transparency matrix.
- **Mechanics:** 5.1 nav-trap audit, 5.2 gesture-bounds hardening.
- **QA:** 8.1 screenshot gallery.

## 4. First actions when the machine is free

1. Shut the two `Mult-*` sims (or let MultTracker finish).
2. Full `--run-tests` on a dedicated AIMapGate 26.5 sim → validate the 10 commits
   with real assertions (so far only compile-gated).
3. Capture Bloom screenshots (1.1) → then work the visual slices with the user.
4. Push branch + open PR.

## 5. Notes / lessons (from LOOP_LOG)

- Each compile gate nets ~-1.1 GiB unrecoverable disk while MultTracker runs
  (shared DerivedData is off-limits) — gate only when free disk > ~6 GiB.
- Never touch `Mult-*` sims, MultTracker files, or the shared
  `~/Library/Developer/Xcode/DerivedData`.
- Adversarial verification paid off: cycle-7 audit "slug bug" (9.1) was REFUTED
  before shipping — `.folding(.caseInsensitive)` already lowercases.
