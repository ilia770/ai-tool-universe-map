# Performance Snapshot

Target: https://ai-tool-universe-map.vercel.app
Tool: Lighthouse 11.x (headless Chrome, mobile profile defaults).

## Baseline vs. post-F (Track F perf sprint)

| Metric | Baseline (E2, before F) | After F1–F3 | Δ |
| --- | --- | --- | --- |
| Performance score | 49 | **67** | +18 |
| Largest Contentful Paint | 3.5 s | 3.1 s | −0.4 s |
| First Contentful Paint | 3.0 s | (n/a — perf-only run) | — |
| Cumulative Layout Shift | 0 | 0 | flat |
| Total Blocking Time | 10,410 ms | **840 ms** | **−92 %** |
| Speed Index | 7.8 s | 3.6 s | −54 % |

The TBT collapse from 10.4 s to 0.84 s is the headline: F1 (lazy-mount StarField + GalaxyDust behind `requestIdleCallback`) moved the heaviest synchronous scene-construction work off the boot path. F2 (shared BufferGeometry across ToolNodes) and F3 (proximity glow cue on CategoryRing) added polish without adding more main-thread cost.

## Reading

- **CLS 0** — the new mobile sticky bottom-sheet (`[C2]`) holds layout space; no shift on hydration.
- **Best practices 100, A11y 96, SEO 92** — focus trap (`[A2]` work) + semantic dialog + Logo.dev alt text are paying off.
- **Performance 49** — dragged down by **TBT 10.4 s**: three.js + react-three-fiber boot is heavy. `[D2]` already split them into separate vendor chunks (cacheable, parallel-fetched), but the runtime cost of constructing the scene on first paint remains.

## Follow-ups (not in sprint)

- Defer scene construction behind an "Enter" CTA on slow networks (saveData / 3G).
- Replace some `useFrame` polling (e.g. `ProximityCategoryWatcher`) with event-driven hooks where possible.
- Investigate `frameloop="demand"` instead of `"always"` once camera transitions are idempotent — would let the GPU sleep when nothing is moving.
- Reuse `BufferGeometry` across ToolNode instances instead of one-per-node.

## How to reproduce

```bash
npx lighthouse https://ai-tool-universe-map.vercel.app \
  --only-categories=performance,accessibility,best-practices,seo \
  --output=json --output-path=/tmp/lh-prod.json \
  --chrome-flags="--headless --no-sandbox" --quiet
```
