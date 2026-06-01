# Performance Snapshot

Date: 2026-06-02
Target: https://ai-tool-universe-map.vercel.app
Tool: Lighthouse 11.x (headless Chrome, mobile profile defaults).

## Category scores

| Category | Score |
| --- | --- |
| Performance | 49 |
| Accessibility | 96 |
| Best practices | 100 |
| SEO | 92 |

## Core Web Vitals

| Metric | Value |
| --- | --- |
| Largest Contentful Paint (LCP) | 3.5 s |
| First Contentful Paint (FCP) | 3.0 s |
| Cumulative Layout Shift (CLS) | 0 |
| Total Blocking Time (TBT) | 10,410 ms |
| Speed Index | 7.8 s |

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
