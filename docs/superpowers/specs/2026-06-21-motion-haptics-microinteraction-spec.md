# Motion, Haptics & Micro-interaction Spec

Date: 2026-06-21 · Branch `feat/redesign-chatgpt-liquid-glass` · iOS 26 / SwiftUI / Core Haptics
Companion to `2026-06-21-chatgpt-liquid-glass-design-direction.md`. Builds on the
existing infra — `BrandMotion`, `BrandHaptics`, `CoreHapticsEngine`,
`Effects/{PressBounce,ParallaxTilt,ShimmerLoader,ScrollEffects}` — do NOT reinvent.

## Existing infra (reuse)
- Curves: `entry` `.spring(0.42,0.85)` · `nudge` `.spring(0.28,0.72)` · `flow`
  `.smooth(0.36)` (the mandated morph curve) · `breath` repeating. Reduce-motion via
  `BrandMotion.resolved(_:reduceMotion:)` + `.brandAnimation(_:value:)`.
- Effects: `PressableButtonStyle` (scale .96, `.light`, RM-aware), `BouncyIconButtonStyle`,
  `shimmer()`, `ProgressOrb`, `scrollDepth/scrollLift/scrollHeaderFade`, `parallaxTilt`.
- Haptics: `BrandHaptic{.light .medium .heavy .success .warning .error}`, `fire/prepare`,
  `CoreHapticsEngine` rich patterns `{pocketOpen,pocketClose,classifySuccess}` + `fireRich`
  with graceful fallback (the contract for all new patterns).

## New `BrandMotion` tokens (add these 7)
| Token | Value | Used by |
|---|---|---|
| `stream` | `.easeOut(0.18)` | per-token text fade |
| `cursor` | `.easeInOut(0.62).repeatForever(autoreverses:)` | blinking caret |
| `thinking` | `.easeInOut(1.1).repeatForever(autoreverses:)` | pre-token dots/glow |
| `reveal` | `.spring(0.5,0.86)` | tool-card group fade+rise (softer than `entry`) |
| `morph` | alias of `flow` | hero card→orbit, chat⇄universe (semantic) |
| `pillPop` | `.spring(0.34,0.55)` (under-damped overshoot) | Map badge / node arrival pop |
| `composerGrow` | `.spring(0.30,0.88)` (high damp, no wobble) | composer 1→6 lines |

## Microanimation map (interaction → mechanism → token)
- **Thinking** (pre-first-token): `PhaseAnimator` dots + glow / reuse `ProgressOrb` → `thinking`.
- **Token reveal**: tokenized `ForEach` + `.transition(.opacity+.move)` on arrival — let stream cadence (~20–50ms) be the clock, NOT a per-frame `TimelineView` → `stream`. (If backend sends whole reply at once, simulate via `phaseAnimator` over tokens.)
- **Cursor**: 2×20pt `Capsule(core)` toggled opacity → `cursor`.
- **Tool-card group**: `.transition(.opacity+.offset(y:14))`, stagger `index*0.06` (cap 3) → `reveal`; + `BrandHaptic.medium` on land.
- **Carousel**: `LazyHStack` + reuse `.scrollDepth()`.
- **HERO morph (signature #1)**: `glassEffectID`/`matchedGeometryEffect` + shared `@Namespace`; card→node handoff on `morph`(=flow, glass MUST be one-shot smooth, never repeating); node arrival pop on `pillPop`; reverse runs backward.
- **Chat⇄Universe**: `.navigationTransition(.zoom(sourceID:in:))` + `.matchedTransitionSource` on Map pill; composer lives in a parent `ZStack` (persists across), collapses via `matchedGeometryEffect`; transcript scale 1→1.06 + blur 0→4 as it recedes.
- **Composer**: mic↔send via `.contentTransition(.symbolEffect(.replace))` + glass→glassProminent on `nudge`; grow via `TextField(axis:.vertical).lineLimit(1...6)` on `composerGrow`; attach chip `.transition(.scale+.opacity)`; streaming top-edge `.shimmer()` (reuse); stop via symbol replace.
- **Empty→first-msg**: brandmark `matchedGeometryEffect` shrink into top bar on `flow`; chips exit staggered on `nudge`.
- **Scroll**: send → `ScrollViewReader.scrollTo(userMsgID, anchor:.top)` on `flow`; jump-to-latest glass pill; `.scrollEdgeEffectStyle(.soft, for:.bottom)`; cards `.scrollLift()`, header `.parallaxTilt(≤4)`.
- **Loading/success/GAP**: `.shimmer()` skeleton → `reveal`; success = node pop + badge; GAP card dashed border draws via `trim` `phaseAnimator` (inviting, not error).

## Haptic vocabulary (keep this tight — feel = meaning)
| Feel | API | Reserved for |
|---|---|---|
| `.selection` | `.sensoryFeedback(.selection,)` | select among peers: category/nav/chrome buttons, node tap, segment, carousel page |
| light impact 0.3–0.55 | `.impact(.light,)` | open a surface (attach, sheet-present), starter chip, first-token tick |
| soft impact 0.25–0.5 | `.impact(.soft,)` | gentle settles: stream-complete, **no-match GAP card**, invalid-drop, overscroll peak |
| medium 0.7 | `.impact(.medium,)` | committal: send, valid drop |
| rigid 0.45–0.6 | `.impact(.rigid,)` | mechanical detents: mode switch, drag pickup, detent snap, dismiss threshold |
| `.increase` | `.sensoryFeedback(.increase,)` | Map badge single +1 |
| success/warning/error | existing notification cases | success→data import only · warning→recoverable · error→unrecoverable. NEVER routine UI |
| `pocketOpen/Close` | `fireRich` | mode-switch world materialize/dematerialize (reuse) |
| `toolLand` (NEW) | `fireRich` | add-to-universe ONLY |
| `ticker(count:)` (NEW) | `fireRich` | multi-add badge tick ONLY |

Loudness ladder: `.selection` < soft < light < medium < rigid < heavy < toolLand/notification. Two surfaces must never share a feel for different meaning.

**Rule: `.sensoryFeedback` for state-driven** (auto-respects system setting, manages lifecycle) — tickers, selection, send/receive phases. **`BrandHaptics.fire`** for press-down inside ButtonStyles. **`fireRich`** only for the 2–3 signature patterns. Glass controls: use `.glassEffect(.interactive())` for the visual (do NOT stack `.scaleEffect`), add haptic only.

## Sensory tickers — Map count badge (signature #3)
- Number roll: `.contentTransition(.numericText(value:))` on `flow`.
- Pulse: scale 1→1.18→1 on `pillPop` + accent ring flash (0→0.6→0, 0.4s).
- Single +1: `.sensoryFeedback(.increase, trigger: toolCount)`.
- **Anti-machine-gun graduated `ticker(count:)`** when delta>1: N=1 single transient (I0.45 S0.65); N=2–4 ascending arpeggio 40ms apart (I0.40→0.70); N≥5 one continuous swell (I0.3→0.6) + single capping transient (I0.8) — number rolls once for the whole delta, pulse fires once (scaled by N).
- Other counters (search results, etc.): **no haptic** — only the Map badge ticks.

## Signature add-flow sequencing (the screenshot moment)
```
0.00 press            → press haptic (interactive / PressableButtonStyle)
0.08 card lift        → silent
0.10 morph+flight     → toolLand "whoosh" (continuous ramp I0.25→0.55)
0.54 node seats       → toolLand "land" transient I0.95 S0.55
0.62 node locks       → toolLand "settle" transient I0.45
0.60 badge rolls+pulse→ .increase (or ticker(count:) if delta>1)
```
Three felt beats — whoosh · thunk · +1 — tracing ask→add→grow. `toolLand` IS the success; do not also fire `.success`.

## Send/receive rhythm
send `.impact(.medium,0.7)` → first-token `.impact(.light,0.3)` (once per message, hard-gated) → complete `.impact(.soft,0.5)` (suppressed if a tool card was produced — let the next Add earn the big haptic).

## Policy — accessibility & performance
- **Reduce-motion ≠ reduce-haptics:** under RM drop flight/pulse visuals, KEEP haptics (they're an aid when motion is gone). `toolLand` collapses to land+settle; badge pulse → static cross-fade; text reveal → instant append; `.zoom` auto-degrades to cross-dissolve.
- **System haptics setting:** `.sensoryFeedback` auto-honors it; `fire/fireRich` gate on `BrandHaptics.isEnabled` (wire to a Settings toggle).
- **Reduce-transparency:** glass→`glassSolid` opaque (per design direction); haptics unaffected.
- **Perf/lifecycle:** prefer `.sensoryFeedback` (auto-managed); `prepare(.medium,.light)` on ChatScreen appear, `prepare(.heavy)` before a likely add; CH engine lazy-restart if niled by `stoppedHandler`, consider `isAutoShutdownEnabled` (rich events are rare). **Throttle:** first-token once/message; search count never; multi-add one `ticker`; drag/scroll on threshold crossings only with hysteresis (mirror universe `enter<exit`); guard against firing while backgrounded.
- VoiceOver: badge `.accessibilityValue("\(n) tools")` so the tick has a non-haptic equivalent.

## Proposed additions (minimal)
- `CoreHapticsEngine.Pattern`: `toolLand` (fallback `.heavy`), `ticker(count:)` (fallback `.light` once), optional `streamComplete` (or just `.sensoryFeedback(.soft)`).
- `BrandHaptics`: Settings-backed `isEnabled` setter; no new enum cases (new feels come via `.sensoryFeedback` at call sites).
- `PressBounce.swift`: optional `glassPressFeedback(_:)` one-liner for haptic-only on glass controls.
- `BrandMotion`: the 7 tokens above. No new effect files needed.
