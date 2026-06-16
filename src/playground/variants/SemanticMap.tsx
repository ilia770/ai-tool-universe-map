import { useCallback, useMemo, useRef, useState } from 'react';
import {
  tools,
  categories,
  toolById,
  categoryById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

/**
 * SemanticMap — a WizMap-style embedding / semantic map.
 *
 * Research (poloclub/wizmap, ACL 2023 demo): WizMap renders large ML
 * embedding spaces as an interactive "meaning map". It projects points to
 * 2D, estimates point density with Kernel Density Estimation (Gaussian
 * kernel, Silverman bandwidth) over a 200x200 grid, and draws that as a
 * contour plot — a topographic map of meaning. A scatter layer sits on top,
 * and labels are gated by zoom (multi-resolution quadtree summaries): zoomed
 * out shows region labels, zoomed in shows individual point labels. It pans
 * and scroll-zooms like a slippy map, all in the browser via WebGL.
 *
 * We have no real embeddings, so we synthesize them: a similarity matrix
 * from shared category + relationIds drives a deterministic MDS-ish force
 * relaxation so similar tools cluster. We then emulate KDE with a coarse
 * grid of Gaussian-summed density, trace iso-contours through it via
 * marching squares, scatter the tool points on top, and gate label detail
 * by zoom. Calm, cartographic.
 */

// ----- deterministic PRNG (mulberry32) -----------------------------------
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ----- world layout (computed once at module scope) ----------------------
const WORLD = 1000; // world-space extent in both axes

interface Placed {
  tool: AITool;
  x: number;
  y: number;
}

function buildLayout(): { placed: Placed[]; byId: Map<string, Placed> } {
  const rand = mulberry32(0x5eed1234);
  const n = tools.length;

  // similarity in [0,1]: shared category is the strong signal, relations add.
  const sim: number[][] = Array.from({ length: n }, () => new Array<number>(n).fill(0));
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      let s = 0;
      if (tools[i].category === tools[j].category) s += 0.6;
      const ri = tools[i].relationIds;
      const rj = tools[j].relationIds;
      if (ri.includes(tools[j].id) || rj.includes(tools[i].id)) s += 0.55;
      const shared = ri.filter((r) => rj.includes(r)).length;
      s += Math.min(0.3, shared * 0.12);
      s = Math.min(1, s);
      sim[i][j] = s;
      sim[j][i] = s;
    }
  }

  // seed positions near each category's compass angle so clusters start apart.
  const catAngle = new Map(categories.map((c) => [c.id, (c.angle * Math.PI) / 180]));
  const px = new Float64Array(n);
  const py = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    const base = catAngle.get(tools[i].category) ?? 0;
    const a = base + (rand() - 0.5) * 0.9;
    const r = 120 + rand() * 320;
    px[i] = Math.cos(a) * r + (rand() - 0.5) * 60;
    py[i] = Math.sin(a) * r + (rand() - 0.5) * 60;
  }

  // force relaxation: attract by similarity, repel everything (MDS-ish).
  const ITER = 220;
  for (let it = 0; it < ITER; it++) {
    const cool = 1 - it / ITER;
    const fx = new Float64Array(n);
    const fy = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        let dx = px[j] - px[i];
        let dy = py[j] - py[i];
        let d2 = dx * dx + dy * dy;
        if (d2 < 1e-4) {
          dx = (rand() - 0.5) * 0.1;
          dy = (rand() - 0.5) * 0.1;
          d2 = dx * dx + dy * dy + 1e-4;
        }
        const d = Math.sqrt(d2);
        const ux = dx / d;
        const uy = dy / d;
        // desired distance shrinks with similarity.
        const want = 70 + (1 - sim[i][j]) * 520;
        const spring = (d - want) * 0.012 * (sim[i][j] * 0.85 + 0.15);
        // global repulsion keeps nodes from stacking.
        const rep = 2600 / d2;
        const f = spring - rep;
        fx[i] += ux * f;
        fy[i] += uy * f;
        fx[j] -= ux * f;
        fy[j] -= uy * f;
      }
    }
    for (let i = 0; i < n; i++) {
      // mild gravity toward origin.
      fx[i] -= px[i] * 0.0015;
      fy[i] -= py[i] * 0.0015;
      const step = 0.9 * cool + 0.1;
      px[i] += Math.max(-30, Math.min(30, fx[i])) * step;
      py[i] += Math.max(-30, Math.min(30, fy[i])) * step;
    }
  }

  // normalize into a centered square with margin.
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (let i = 0; i < n; i++) {
    if (px[i] < minX) minX = px[i];
    if (py[i] < minY) minY = py[i];
    if (px[i] > maxX) maxX = px[i];
    if (py[i] > maxY) maxY = py[i];
  }
  const span = Math.max(maxX - minX, maxY - minY) || 1;
  const usable = WORLD * (1 - 0.12 * 2);
  const placed: Placed[] = tools.map((tool, i) => {
    const cx = (px[i] - (minX + maxX) / 2) / span;
    const cy = (py[i] - (minY + maxY) / 2) / span;
    return {
      tool,
      x: WORLD / 2 + cx * usable,
      y: WORLD / 2 + cy * usable,
    };
  });
  const byId = new Map(placed.map((p) => [p.tool.id, p]));
  return { placed, byId };
}

const LAYOUT = buildLayout();

// ----- KDE density grid + iso-contour paths (computed once) --------------
const GRID = 64; // density grid resolution (WizMap uses 200; 64 is plenty here)

interface ContourBand {
  category: ToolCategory;
  paths: string[]; // multiple iso-levels, outer (faint) -> inner (dense)
}

function densityContours(): ContourBand[] {
  const cell = WORLD / GRID;
  const bandwidth = 95; // Gaussian KDE bandwidth in world units
  const inv2h2 = 1 / (2 * bandwidth * bandwidth);

  return categories
    .map((category): ContourBand | null => {
      const pts = LAYOUT.placed.filter((p) => p.tool.category === category.id);
      if (pts.length === 0) return null;

      // KDE: sum of Gaussian kernels on the grid.
      const field = new Float64Array((GRID + 1) * (GRID + 1));
      let peak = 0;
      for (let gy = 0; gy <= GRID; gy++) {
        for (let gx = 0; gx <= GRID; gx++) {
          const wx = gx * cell;
          const wy = gy * cell;
          let v = 0;
          for (const p of pts) {
            const dx = wx - p.x;
            const dy = wy - p.y;
            v += Math.exp(-(dx * dx + dy * dy) * inv2h2);
          }
          field[gy * (GRID + 1) + gx] = v;
          if (v > peak) peak = v;
        }
      }
      if (peak <= 0) return null;

      const levels = [0.16, 0.34, 0.58, 0.82];
      const paths = levels.map((lv) => isoPath(field, GRID, cell, lv * peak));
      return { category, paths };
    })
    .filter((b): b is ContourBand => b !== null);
}

/**
 * Marching squares: emit iso-line segments for one level as a single SVG
 * path string. Segments aren't stitched into closed rings, but at this
 * resolution the dense set of short strokes reads as a soft contour band.
 */
function isoPath(field: Float64Array, grid: number, cell: number, level: number): string {
  const w = grid + 1;
  const segs: string[] = [];
  const lerp = (a: number, b: number) => (level - a) / (b - a || 1e-9);
  const edges: Record<number, [[number, number], [number, number]] | undefined> = {};
  for (let gy = 0; gy < grid; gy++) {
    for (let gx = 0; gx < grid; gx++) {
      const tl = field[gy * w + gx];
      const tr = field[gy * w + gx + 1];
      const br = field[(gy + 1) * w + gx + 1];
      const bl = field[(gy + 1) * w + gx];
      let code = 0;
      if (tl > level) code |= 8;
      if (tr > level) code |= 4;
      if (br > level) code |= 2;
      if (bl > level) code |= 1;
      if (code === 0 || code === 15) continue;
      const x0 = gx * cell;
      const y0 = gy * cell;
      const top: [number, number] = [x0 + cell * lerp(tl, tr), y0];
      const right: [number, number] = [x0 + cell, y0 + cell * lerp(tr, br)];
      const bottom: [number, number] = [x0 + cell * lerp(bl, br), y0 + cell];
      const left: [number, number] = [x0, y0 + cell * lerp(tl, bl)];
      edges[1] = [left, bottom];
      edges[2] = [bottom, right];
      edges[3] = [left, right];
      edges[4] = [top, right];
      edges[5] = [top, left];
      edges[6] = [top, bottom];
      edges[7] = [top, left];
      edges[8] = [top, left];
      edges[9] = [top, bottom];
      edges[10] = [top, right];
      edges[11] = [top, right];
      edges[12] = [left, right];
      edges[13] = [bottom, right];
      edges[14] = [left, bottom];
      const pair = edges[code];
      if (!pair) continue;
      const [a, b] = pair;
      segs.push(`M${a[0].toFixed(1)} ${a[1].toFixed(1)}L${b[0].toFixed(1)} ${b[1].toFixed(1)}`);
    }
  }
  return segs.join('');
}

const CONTOURS = densityContours();

interface Region {
  category: ToolCategory;
  x: number;
  y: number;
  count: number;
}

// per-category centroid (for region labels + heat blobs)
const CENTROIDS: Region[] = categories
  .map((category): Region | null => {
    const pts = LAYOUT.placed.filter((p) => p.tool.category === category.id);
    if (pts.length === 0) return null;
    const cx = pts.reduce((s, p) => s + p.x, 0) / pts.length;
    const cy = pts.reduce((s, p) => s + p.y, 0) / pts.length;
    return { category, x: cx, y: cy, count: pts.length };
  })
  .filter((c): c is Region => c !== null);

// ----- component ---------------------------------------------------------
interface View {
  cx: number; // center of view in world coords
  cy: number;
  scale: number; // px per world unit
}

const MIN_SCALE = 0.45;
const MAX_SCALE = 6;

export function SemanticMap() {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [size, setSize] = useState({ w: 1200, h: 800 });
  const [view, setView] = useState<View>({ cx: WORLD / 2, cy: WORLD / 2, scale: 0.6 });
  const [hover, setHover] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [grabbing, setGrabbing] = useState(false);
  const drag = useRef<{ x: number; y: number; cx: number; cy: number } | null>(null);

  const measure = useCallback((node: HTMLDivElement | null) => {
    containerRef.current = node;
    if (node) {
      const r = node.getBoundingClientRect();
      setSize({ w: r.width, h: r.height });
    }
  }, []);

  const toScreen = useCallback(
    (x: number, y: number): [number, number] => [
      size.w / 2 + (x - view.cx) * view.scale,
      size.h / 2 + (y - view.cy) * view.scale,
    ],
    [size.w, size.h, view],
  );

  const onWheel = useCallback((e: React.WheelEvent) => {
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return;
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    setView((v) => {
      const factor = Math.exp(-e.deltaY * 0.0015);
      const next = Math.max(MIN_SCALE, Math.min(MAX_SCALE, v.scale * factor));
      // keep the point under the cursor stationary
      const wx = v.cx + (mx - rect.width / 2) / v.scale;
      const wy = v.cy + (my - rect.height / 2) / v.scale;
      const ncx = wx - (mx - rect.width / 2) / next;
      const ncy = wy - (my - rect.height / 2) / next;
      return { cx: ncx, cy: ncy, scale: next };
    });
  }, []);

  const onPointerDown = useCallback(
    (e: React.PointerEvent) => {
      (e.target as Element).setPointerCapture?.(e.pointerId);
      drag.current = { x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy };
      setGrabbing(true);
    },
    [view.cx, view.cy],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent) => {
      const d = drag.current;
      if (!d) return;
      const dx = (e.clientX - d.x) / view.scale;
      const dy = (e.clientY - d.y) / view.scale;
      setView((v) => ({ ...v, cx: d.cx - dx, cy: d.cy - dy }));
    },
    [view.scale],
  );

  const onPointerUp = useCallback((e: React.PointerEvent) => {
    (e.target as Element).releasePointerCapture?.(e.pointerId);
    drag.current = null;
    setGrabbing(false);
  }, []);

  // zoom-gated label visibility (WizMap multi-resolution behaviour)
  const showToolLabels = view.scale > 1.35;
  const showRegionLabels = view.scale < 2.4;
  const pointR = Math.max(2.4, 3.6 * Math.min(1.4, view.scale));

  const activeId = hover ?? selected;
  const activeTool = activeId ? toolById.get(activeId) : undefined;
  const activePlaced = activeId ? LAYOUT.byId.get(activeId) : undefined;

  // relations for the active tool, resolved to placed points
  const activeLinks = useMemo(() => {
    const out: Array<{ a: Placed; b: Placed }> = [];
    if (!activeTool) return out;
    const a = LAYOUT.byId.get(activeTool.id);
    if (!a) return out;
    for (const rid of activeTool.relationIds) {
      const b = LAYOUT.byId.get(rid);
      if (b) out.push({ a, b });
    }
    for (const p of LAYOUT.placed) {
      if (p.tool.relationIds.includes(activeTool.id)) out.push({ a, b: p });
    }
    return out;
  }, [activeTool]);

  return (
    <div
      ref={measure}
      className="absolute inset-0 overflow-hidden"
      style={{
        background:
          'radial-gradient(120% 120% at 50% 0%, #0b1220 0%, #070a14 55%, #04060c 100%)',
        cursor: grabbing ? 'grabbing' : 'grab',
        touchAction: 'none',
      }}
      onWheel={onWheel}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerLeave={onPointerUp}
    >
      <svg width={size.w} height={size.h} viewBox={`0 0 ${size.w} ${size.h}`} style={{ display: 'block' }}>
        <defs>
          <filter id="sm-soft" x="-30%" y="-30%" width="160%" height="160%">
            <feGaussianBlur stdDeviation="6" />
          </filter>
          {categories.map((c) => (
            <radialGradient key={c.id} id={`sm-grad-${c.id}`} cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor={c.color} stopOpacity="0.55" />
              <stop offset="60%" stopColor={c.color} stopOpacity="0.16" />
              <stop offset="100%" stopColor={c.color} stopOpacity="0" />
            </radialGradient>
          ))}
        </defs>

        {/* world -> screen transform group */}
        <g
          transform={`translate(${size.w / 2} ${size.h / 2}) scale(${view.scale}) translate(${-view.cx} ${-view.cy})`}
        >
          {/* soft heat blobs (filled cartographic base) */}
          <g style={{ mixBlendMode: 'screen' }} opacity={0.55}>
            {CENTROIDS.map(({ category, x, y, count }) => (
              <circle
                key={`blob-${category.id}`}
                cx={x}
                cy={y}
                r={90 + count * 12}
                fill={`url(#sm-grad-${category.id})`}
              />
            ))}
          </g>

          {/* density contour bands (KDE emulation) */}
          <g style={{ mixBlendMode: 'screen' }}>
            {CONTOURS.map(({ category, paths }) =>
              paths.map((d, li) => (
                <path
                  key={`${category.id}-${li}`}
                  d={d}
                  fill="none"
                  stroke={category.color}
                  strokeOpacity={0.1 + li * 0.13}
                  strokeWidth={(2.2 - li * 0.35) / view.scale}
                  strokeLinecap="round"
                  filter={li === 0 ? 'url(#sm-soft)' : undefined}
                />
              )),
            )}
          </g>

          {/* active relation links */}
          {activeLinks.map(({ a, b }, i) => (
            <line
              key={`lnk-${i}`}
              x1={a.x}
              y1={a.y}
              x2={b.x}
              y2={b.y}
              stroke={categoryById.get(a.tool.category)?.color ?? '#fff'}
              strokeOpacity={0.5}
              strokeWidth={1.4 / view.scale}
            />
          ))}

          {/* scatter points */}
          {LAYOUT.placed.map((p) => {
            const cat = categoryById.get(p.tool.category);
            const isActive = p.tool.id === activeId;
            const dim = !!activeId && !isActive && !activeTool?.relationIds.includes(p.tool.id);
            return (
              <g key={p.tool.id}>
                {isActive && (
                  <circle
                    cx={p.x}
                    cy={p.y}
                    r={pointR * 3.4}
                    fill="none"
                    stroke={cat?.color ?? '#fff'}
                    strokeOpacity={0.6}
                    strokeWidth={1 / view.scale}
                  />
                )}
                <circle
                  cx={p.x}
                  cy={p.y}
                  r={isActive ? pointR * 1.9 : pointR}
                  fill={cat?.color ?? '#9bb'}
                  fillOpacity={dim ? 0.35 : 1}
                  stroke="#04060c"
                  strokeWidth={(isActive ? 1.4 : 0.8) / view.scale}
                  style={{ cursor: 'pointer' }}
                  onPointerEnter={() => setHover(p.tool.id)}
                  onPointerLeave={() => setHover((h) => (h === p.tool.id ? null : h))}
                  onPointerDown={(e) => {
                    e.stopPropagation();
                    setSelected((s) => (s === p.tool.id ? null : p.tool.id));
                  }}
                />
              </g>
            );
          })}

          {/* tool labels (zoomed in) */}
          {showToolLabels &&
            LAYOUT.placed.map((p) => (
              <text
                key={`tl-${p.tool.id}`}
                x={p.x}
                y={p.y - pointR - 3 / view.scale}
                textAnchor="middle"
                fontSize={9 / view.scale}
                fill="#dce6f5"
                style={{ pointerEvents: 'none', fontWeight: 500 }}
                opacity={p.tool.id === activeId ? 1 : 0.78}
              >
                {p.tool.name}
              </text>
            ))}

          {/* region labels (zoomed out) */}
          {showRegionLabels &&
            CENTROIDS.map(({ category, x, y }) => (
              <text
                key={`rl-${category.id}`}
                x={x}
                y={y}
                textAnchor="middle"
                fontSize={Math.min(34, 17 / view.scale)}
                fill={category.color}
                fillOpacity={0.92}
                style={{
                  pointerEvents: 'none',
                  fontWeight: 700,
                  letterSpacing: '0.12em',
                  textTransform: 'uppercase',
                }}
              >
                {category.shortName}
              </text>
            ))}
        </g>
      </svg>

      {/* top chrome clearance + title */}
      <div className="pointer-events-none absolute left-6 right-6 top-16 flex items-start justify-between">
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.28em] text-sky-200/70">
            Semantic Map
          </div>
          <div className="mt-1 text-sm text-slate-300/80">
            KDE meaning-map of {tools.length} AI tools across {categories.length} regions
          </div>
        </div>
        <div className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-medium text-slate-200/80 backdrop-blur">
          {view.scale < 1.35 ? 'Regions' : 'Tools'} · {view.scale.toFixed(1)}×
        </div>
      </div>

      {/* category legend */}
      <div className="pointer-events-none absolute bottom-5 left-6 flex flex-wrap gap-x-4 gap-y-1.5">
        {categories.map((c) => (
          <div key={c.id} className="flex items-center gap-1.5">
            <span
              className="inline-block h-2 w-2 rounded-full"
              style={{ background: c.color, boxShadow: `0 0 8px ${c.glow}` }}
            />
            <span className="text-[11px] text-slate-300/80">{c.shortName}</span>
          </div>
        ))}
      </div>

      {/* hint */}
      <div className="pointer-events-none absolute bottom-5 right-6 text-[11px] text-slate-400/60">
        scroll to zoom · drag to pan · click a point
      </div>

      {/* detail card for selected / hovered tool */}
      {activeTool && activePlaced && (
        <div
          className="pointer-events-none absolute max-w-xs rounded-2xl border border-white/10 bg-slate-900/85 p-4 shadow-2xl backdrop-blur-md"
          style={{
            left: Math.min(size.w - 280, Math.max(12, toScreen(activePlaced.x, activePlaced.y)[0] + 14)),
            top: Math.min(size.h - 150, Math.max(72, toScreen(activePlaced.x, activePlaced.y)[1] + 14)),
          }}
        >
          <div className="flex items-center gap-2">
            <span
              className="inline-block h-2.5 w-2.5 rounded-full"
              style={{
                background: categoryById.get(activeTool.category)?.color,
                boxShadow: `0 0 10px ${categoryById.get(activeTool.category)?.glow}`,
              }}
            />
            <span className="text-sm font-semibold text-white">{activeTool.name}</span>
          </div>
          <div className="mt-1 text-[11px] uppercase tracking-wider text-slate-400">
            {categoryById.get(activeTool.category)?.name} · {activeTool.stage}
          </div>
          <p className="mt-2 text-[12px] leading-relaxed text-slate-300">{activeTool.summary}</p>
          {activeTool.relationIds.length > 0 && (
            <div className="mt-2 text-[11px] text-slate-400">
              Connects to{' '}
              <span className="text-slate-200">
                {activeTool.relationIds
                  .map((r) => toolById.get(r)?.name)
                  .filter(Boolean)
                  .slice(0, 4)
                  .join(', ')}
              </span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
