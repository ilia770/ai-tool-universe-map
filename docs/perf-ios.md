# iOS Performance Baseline

Backlog task 35 deliverable. Establishes an `OSSignposter` baseline for the
RealityKit universe scene **before** Phase C adds IBL / skybox / particles —
so any added cost has a comparison point. Sibling doc: `docs/perf.md` (web
Lighthouse baseline).

## Signposts

All intervals are emitted via `UniversePerf.signposter`
(`ios-app/Sources/MyAIMap/Universe/UniversePerf.swift`).

- **Subsystem:** `com.iliaturilia.myaimap`
- **Category:** `universe`

Filter Instruments by that subsystem + category to isolate these intervals.

| Interval | Where | Measures |
| --- | --- | --- |
| `scene.build` | `RealityView` make closure (`UniverseView`) | One-time cost of building the whole scene: core node, per-category anchors + labels + tool nodes, lights. Fires once on cold launch / first render. |
| `layout.apply` | `UniverseView.applyLayout` | Per-transition restyle + move loop. Iterates **all** tool nodes and reallocates a `PhysicallyBasedMaterial` per node per transition (flagged in the 2026-06-12 review). Fires on every category / tool change. |

`OSSignposter` intervals are near-zero-cost when no Instruments tool is
attached, so they ship un-gated (no `#if DEBUG`).

## How to capture

1. Build the app onto the `ClaudeGate` simulator (or a real device — device
   numbers are the ones that matter for a budget).
2. Instruments → **os_signpost** template (or **Time Profiler** + the
   **Logging / os_signpost** instrument).
3. Filter the os_signpost track by subsystem `com.iliaturilia.myaimap`,
   category `universe`.
4. Exercise the two paths:
   - **`scene.build`** — cold launch the app (kill it first). The interval
     fires once as the RealityView first render completes.
   - **`layout.apply`** — tap a category anchor (or a tool node). Each
     selection change emits one interval. Tap several to get a spread.
5. Read the interval durations from the os_signpost detail / summary.

## Budget

Current baseline is the only known data point (RealityView first render
~8–12 s on the M1 Air simulator, per the 2026-06-12 full-project review).
Targets are **TBD** — fill the columns from the first real Instruments run.

| Interval | Current baseline | Target | Notes |
| --- | --- | --- | --- |
| `scene.build` | ~8–12 s (M1 Air sim, review estimate) | TBD — fill from first Instruments run | Pre-Phase-C. Sim numbers run hot; capture device numbers too. |
| `layout.apply` | TBD — fill from first Instruments run | TBD — fill from first Instruments run | Per-transition; review flagged the all-nodes + per-node PBR realloc. |

## Regression rule

Any change that regresses `scene.build` or `layout.apply` by **more than
10 %** must be flagged in its PR description, with the before/after interval
numbers from a fresh Instruments run. (Mirrors the web `docs/perf.md` >10 %
rule.)
