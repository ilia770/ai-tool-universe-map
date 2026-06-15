import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  tools,
  categories,
  toolById,
  categoryById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

/**
 * BloomGraph — a Neo4j Bloom–style progressive graph exploration scene.
 *
 * Research (Neo4j Bloom user guide, "Scene interactions" + "Legend panel"):
 * Bloom is NOT a 2D-projection of a 3D space — it is the classic "circles and
 * lines" graph scene rendered in 2D, containing only the parts of the graph
 * you have found through search or *expansion*. The core UX loop is:
 *   1. Start from a seed node (here, Founder OS) and its immediate neighbours.
 *   2. Select a node and "expand" to reveal its not-yet-shown neighbours,
 *      which animate into existence around it; already-shown nodes stay put.
 *   3. Keep expanding outward to walk local regions of the graph.
 * Tech-wise Bloom runs a continuously-relaxing force-directed layout
 * (repulsion between nodes + spring attraction along relationships), captioned
 * category-coloured node circles, and curved relationship lines with type
 * labels. We emulate that faithfully: a deterministic Verlet-ish force
 * simulation in a requestAnimationFrame loop relaxes only the *visible*
 * subgraph, new nodes are seeded in a ring around their expander, the camera
 * eases-to-centre on the focused node, and edges are drawn as quadratic
 * Béziers with mid-point relationship captions. No real embeddings or DB —
 * adjacency is derived from `relationIds` (made bidirectional).
 *
 * Stack note: Bloom is inherently a 2D scene, so this variant is a full-screen
 * SVG + div overlay rather than an R3F Canvas — the faithful emulation.
 */

// ---- deterministic PRNG (no Math.random during render/module init) ---------
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

// ---- bidirectional adjacency (relationIds are stored on the source) --------
const adjacency: Map<string, string[]> = (() => {
  const map = new Map<string, Set<string>>();
  const ensure = (id: string) => {
    let s = map.get(id);
    if (!s) {
      s = new Set();
      map.set(id, s);
    }
    return s;
  };
  for (const t of tools) {
    const a = ensure(t.id);
    for (const r of t.relationIds) {
      if (!toolById.has(r)) continue;
      a.add(r);
      ensure(r).add(t.id);
    }
  }
  const out = new Map<string, string[]>();
  for (const [k, v] of map) out.set(k, [...v]);
  return out;
})();

const SEED_ID = 'founder-os';

// ---- simulation node model -------------------------------------------------
interface SimNode {
  id: string;
  tool: AITool;
  cat: ToolCategory;
  x: number;
  y: number;
  vx: number;
  vy: number;
  // appear animation 0 -> 1
  appear: number;
}

interface Edge {
  a: string;
  b: string;
  label: string;
}

// immutable per-frame render snapshot published from the simulation loop.
interface RenderNode {
  id: string;
  x: number;
  y: number;
  appear: number;
  catColor: string;
  catGlow: string;
  name: string;
}
interface Snapshot {
  nodes: RenderNode[];
  camX: number;
  camY: number;
}

// relationship caption: derived from the two tools' stages / category bond.
function edgeLabel(a: AITool, b: AITool): string {
  if (a.category === b.category) return 'PEER';
  if (a.id === SEED_ID || b.id === SEED_ID) return 'ORCHESTRATES';
  if (a.stage === b.stage) return `${a.stage.toUpperCase()}`;
  return 'CONNECTS';
}

const NODE_R = 30;
const APPEAR_SPEED = 0.045;

export function BloomGraph() {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const [size, setSize] = useState({ w: 1200, h: 800 });

  // track which tools are revealed and which have been expanded
  const [revealed, setRevealed] = useState<Set<string>>(
    () => new Set([SEED_ID, ...(adjacency.get(SEED_ID) ?? [])]),
  );
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set([SEED_ID]));
  const [focusId, setFocusId] = useState<string>(SEED_ID);
  const [hoverId, setHoverId] = useState<string | null>(null);

  // mutable simulation state lives in refs (no per-frame React allocation)
  const nodesRef = useRef<Map<string, SimNode>>(new Map());
  const camRef = useRef({ x: 0, y: 0, tx: 0, ty: 0 });
  const rafRef = useRef<number>(0);
  const focusIdRef = useRef<string>(SEED_ID);
  const edgesRef = useRef<Edge[]>([]);
  // the simulation loop publishes a frozen snapshot here; render reads only
  // from this state + props/state — never from the mutable refs (purity).
  const [snapshot, setSnapshot] = useState<Snapshot>({
    nodes: [],
    camX: 0,
    camY: 0,
  });

  // ---- responsive sizing ----
  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver((entries) => {
      const r = entries[0].contentRect;
      setSize({ w: Math.max(320, r.width), h: Math.max(320, r.height) });
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // ---- seed / sync simulation nodes when `revealed` changes ----
  useEffect(() => {
    const map = nodesRef.current;
    const rng = mulberry32(0x9e3779b9 ^ revealed.size);
    // ensure a node exists for every revealed id
    for (const id of revealed) {
      if (map.has(id)) continue;
      const tool = toolById.get(id);
      if (!tool) continue;
      const cat = categoryById.get(tool.category);
      if (!cat) continue;
      // seed position: in a ring around an already-placed neighbour (its
      // expander), so new nodes "bloom" outward from where you clicked.
      let ox = 0;
      let oy = 0;
      const neighbours = adjacency.get(id) ?? [];
      const anchor = neighbours.map((n) => map.get(n)).find((n) => n);
      if (anchor) {
        const ang = rng() * Math.PI * 2;
        const rad = NODE_R * 4 + rng() * 60;
        ox = anchor.x + Math.cos(ang) * rad;
        oy = anchor.y + Math.sin(ang) * rad;
      } else if (id === SEED_ID) {
        ox = 0;
        oy = 0;
      } else {
        const ang = rng() * Math.PI * 2;
        ox = Math.cos(ang) * 180;
        oy = Math.sin(ang) * 180;
      }
      map.set(id, {
        id,
        tool,
        cat,
        x: ox,
        y: oy,
        vx: 0,
        vy: 0,
        appear: id === SEED_ID ? 1 : 0,
      });
    }
    // remove nodes no longer revealed (collapse)
    for (const id of [...map.keys()]) {
      if (!revealed.has(id)) map.delete(id);
    }
  }, [revealed]);

  // ---- visible edges (both endpoints revealed) ----
  const edges = useMemo<Edge[]>(() => {
    const seen = new Set<string>();
    const out: Edge[] = [];
    for (const id of revealed) {
      const a = toolById.get(id);
      if (!a) continue;
      for (const nb of adjacency.get(id) ?? []) {
        if (!revealed.has(nb)) continue;
        const key = id < nb ? `${id}|${nb}` : `${nb}|${id}`;
        if (seen.has(key)) continue;
        seen.add(key);
        const b = toolById.get(nb);
        if (!b) continue;
        out.push({ a: id, b: nb, label: edgeLabel(a, b) });
      }
    }
    return out;
  }, [revealed]);

  // keep loop-facing refs in sync (the loop must not depend on render scope)
  useEffect(() => {
    focusIdRef.current = focusId;
  }, [focusId]);
  useEffect(() => {
    edgesRef.current = edges;
  }, [edges]);

  // ---- focus camera on selected node ----
  useEffect(() => {
    const n = nodesRef.current.get(focusId);
    if (n) {
      camRef.current.tx = n.x;
      camRef.current.ty = n.y;
    }
  }, [focusId, revealed]);

  // ---- force simulation loop (runs once; reads dynamic data via refs) ----
  useEffect(() => {
    const step = () => {
      const edges = edgesRef.current;
      const focusId = focusIdRef.current;
      const map = nodesRef.current;
      const arr = [...map.values()];
      const n = arr.length;

      // repulsion (O(n^2) — fine for <=49 nodes)
      for (let i = 0; i < n; i++) {
        const a = arr[i];
        for (let j = i + 1; j < n; j++) {
          const b = arr[j];
          let dx = a.x - b.x;
          let dy = a.y - b.y;
          let d2 = dx * dx + dy * dy;
          if (d2 < 0.01) {
            dx = (i - j) * 0.5 + 0.1;
            dy = 0.1;
            d2 = dx * dx + dy * dy;
          }
          const d = Math.sqrt(d2);
          const force = 16000 / d2;
          const fx = (dx / d) * force;
          const fy = (dy / d) * force;
          a.vx += fx;
          a.vy += fy;
          b.vx -= fx;
          b.vy -= fy;
        }
      }

      // spring attraction along visible edges
      const REST = NODE_R * 4.4;
      for (const e of edges) {
        const a = map.get(e.a);
        const b = map.get(e.b);
        if (!a || !b) continue;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const d = Math.sqrt(dx * dx + dy * dy) || 0.001;
        const k = (d - REST) * 0.012;
        const fx = (dx / d) * k;
        const fy = (dy / d) * k;
        a.vx += fx;
        a.vy += fy;
        b.vx -= fx;
        b.vy -= fy;
      }

      // gentle gravity toward origin keeps the cluster on-screen
      for (const a of arr) {
        a.vx += -a.x * 0.0009;
        a.vy += -a.y * 0.0009;
        // integrate + damp
        a.vx *= 0.86;
        a.vy *= 0.86;
        a.x += a.vx;
        a.y += a.vy;
        if (a.appear < 1) a.appear = Math.min(1, a.appear + APPEAR_SPEED);
      }

      // ease camera toward target
      const cam = camRef.current;
      cam.x += (cam.tx - cam.x) * 0.08;
      cam.y += (cam.ty - cam.y) * 0.08;
      // keep the camera target locked to the (moving) focus node
      const f = map.get(focusId);
      if (f) {
        cam.tx = f.x;
        cam.ty = f.y;
      }

      // publish an immutable render snapshot (fresh objects each frame)
      const renderNodes: RenderNode[] = arr.map((nd) => ({
        id: nd.id,
        x: nd.x,
        y: nd.y,
        appear: nd.appear,
        catColor: nd.cat.color,
        catGlow: nd.cat.glow,
        name: nd.tool.name,
      }));
      setSnapshot({ nodes: renderNodes, camX: cam.x, camY: cam.y });
      rafRef.current = requestAnimationFrame(step);
    };
    rafRef.current = requestAnimationFrame(step);
    return () => cancelAnimationFrame(rafRef.current);
  }, []);

  // ---- expand a node: reveal its hidden neighbours ----
  const expand = useCallback((id: string) => {
    setFocusId(id);
    setExpanded((prev) => {
      if (prev.has(id)) return prev;
      const next = new Set(prev);
      next.add(id);
      return next;
    });
    setRevealed((prev) => {
      const nbs = adjacency.get(id) ?? [];
      const allShown = nbs.every((n) => prev.has(n));
      if (allShown) return prev; // nothing new — just refocus
      const next = new Set(prev);
      for (const nb of nbs) if (toolById.has(nb)) next.add(nb);
      return next;
    });
  }, []);

  const reset = useCallback(() => {
    setRevealed(new Set([SEED_ID, ...(adjacency.get(SEED_ID) ?? [])]));
    setExpanded(new Set([SEED_ID]));
    setFocusId(SEED_ID);
    camRef.current.x = 0;
    camRef.current.y = 0;
    camRef.current.tx = 0;
    camRef.current.ty = 0;
  }, []);

  // keyboard: escape to collapse
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') reset();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [reset]);

  // ---- viewport transform: world -> screen (reads snapshot, not refs) ----
  const cx = size.w / 2;
  const cy = size.h / 2 + 28; // generous top padding for lab chrome
  const toScreen = (x: number, y: number): [number, number] => [
    x - snapshot.camX + cx,
    y - snapshot.camY + cy,
  ];

  const map = useMemo(() => {
    const m = new Map<string, RenderNode>();
    for (const n of snapshot.nodes) m.set(n.id, n);
    return m;
  }, [snapshot]);
  const focusNode = focusId ? toolById.get(focusId) : undefined;
  const focusCat = focusNode ? categoryById.get(focusNode.category) : undefined;

  // active set for de-emphasis: focus node + its visible neighbours
  const activeSet = useMemo(() => {
    const s = new Set<string>([focusId]);
    for (const nb of adjacency.get(focusId) ?? []) if (revealed.has(nb)) s.add(nb);
    return s;
  }, [focusId, revealed]);

  const hiddenCount = focusNode
    ? (adjacency.get(focusId) ?? []).filter((n) => !revealed.has(n)).length
    : 0;

  return (
    <div
      ref={wrapRef}
      className="absolute inset-0 overflow-hidden select-none"
      style={{
        background:
          'radial-gradient(120% 100% at 50% 0%, #0b1220 0%, #060912 55%, #03060d 100%)',
      }}
    >
      <svg
        width={size.w}
        height={size.h}
        className="absolute inset-0 block"
        style={{ touchAction: 'none' }}
      >
        <defs>
          <filter id="bloom-glow" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur stdDeviation="6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <radialGradient id="bloom-vignette" cx="50%" cy="42%" r="75%">
            <stop offset="60%" stopColor="#000" stopOpacity="0" />
            <stop offset="100%" stopColor="#000" stopOpacity="0.45" />
          </radialGradient>
        </defs>

        {/* faint dotted grid for an investigative "scene" feel */}
        <GridLayer
          w={size.w}
          h={size.h}
          camX={snapshot.camX}
          camY={snapshot.camY}
          ox={cx}
          oy={cy}
        />

        {/* edges */}
        <g>
          {edges.map((e) => {
            const na = map.get(e.a);
            const nb = map.get(e.b);
            if (!na || !nb) return null;
            const [ax, ay] = toScreen(na.x, na.y);
            const [bx, by] = toScreen(nb.x, nb.y);
            const isActive = activeSet.has(e.a) && activeSet.has(e.b);
            const isHover = hoverId === e.a || hoverId === e.b;
            const appear = Math.min(na.appear, nb.appear);
            // curved quadratic bezier (perpendicular offset)
            const mx = (ax + bx) / 2;
            const my = (ay + by) / 2;
            const dx = bx - ax;
            const dy = by - ay;
            const len = Math.hypot(dx, dy) || 1;
            const off = 18;
            const px = mx + (-dy / len) * off;
            const py = my + (dx / len) * off;
            const opacity = (isActive ? 0.9 : isHover ? 0.7 : 0.28) * appear;
            return (
              <g key={`${e.a}|${e.b}`} style={{ opacity }}>
                <path
                  d={`M ${ax} ${ay} Q ${px} ${py} ${bx} ${by}`}
                  fill="none"
                  stroke={isActive ? na.catGlow : '#5b6b86'}
                  strokeWidth={isActive ? 1.8 : 1.1}
                  strokeLinecap="round"
                />
                {(isActive || isHover) && (
                  <text
                    x={px}
                    y={py}
                    fill="#9fb2d4"
                    fontSize={9}
                    letterSpacing={1.2}
                    textAnchor="middle"
                    dominantBaseline="middle"
                    style={{ pointerEvents: 'none', fontWeight: 600 }}
                  >
                    {e.label}
                  </text>
                )}
              </g>
            );
          })}
        </g>

        {/* nodes */}
        <g>
          {[...map.values()].map((node) => {
            const [nx, ny] = toScreen(node.x, node.y);
            const isFocus = node.id === focusId;
            const isHover = node.id === hoverId;
            const inActive = activeSet.has(node.id);
            const hasHidden = (adjacency.get(node.id) ?? []).some(
              (n) => !revealed.has(n),
            );
            const isExpanded = expanded.has(node.id);
            const scale = node.appear * (isFocus ? 1.18 : isHover ? 1.08 : 1);
            const r = NODE_R * scale;
            const dim = inActive ? 1 : 0.4;
            const label = node.name;
            const labelW = Math.max(54, label.length * 7.0 + 26);
            return (
              <g
                key={node.id}
                transform={`translate(${nx} ${ny})`}
                style={{
                  cursor: 'pointer',
                  opacity: node.appear * dim,
                }}
                onMouseEnter={() => setHoverId(node.id)}
                onMouseLeave={() => setHoverId((h) => (h === node.id ? null : h))}
                onClick={() => expand(node.id)}
              >
                {/* halo */}
                {(isFocus || isHover) && (
                  <circle
                    r={r + 11}
                    fill="none"
                    stroke={node.catGlow}
                    strokeWidth={isFocus ? 2 : 1.2}
                    opacity={0.55}
                    filter="url(#bloom-glow)"
                  />
                )}
                {/* expand affordance ring: node has undiscovered neighbours */}
                {hasHidden && !isExpanded && (
                  <circle
                    r={r + 5}
                    fill="none"
                    stroke={node.catColor}
                    strokeWidth={1.4}
                    strokeDasharray="3 5"
                    opacity={0.7}
                  />
                )}
                {/* node body */}
                <circle
                  r={r}
                  fill={node.catColor}
                  fillOpacity={0.16}
                  stroke={node.catColor}
                  strokeWidth={isFocus ? 2.4 : 1.6}
                  filter={isFocus ? 'url(#bloom-glow)' : undefined}
                />
                <circle r={r * 0.42} fill={node.catColor} fillOpacity={0.9} />
                {/* caption pill */}
                <g transform={`translate(0 ${r + 16})`}>
                  <rect
                    x={-labelW / 2}
                    y={-11}
                    width={labelW}
                    height={22}
                    rx={11}
                    fill="#0a1322"
                    fillOpacity={0.85}
                    stroke={node.catColor}
                    strokeOpacity={0.55}
                    strokeWidth={1}
                  />
                  <text
                    x={0}
                    y={1}
                    fill="#eaf2ff"
                    fontSize={11}
                    fontWeight={600}
                    textAnchor="middle"
                    dominantBaseline="middle"
                    style={{ pointerEvents: 'none' }}
                  >
                    {label}
                  </text>
                </g>
              </g>
            );
          })}
        </g>

        <rect
          x={0}
          y={0}
          width={size.w}
          height={size.h}
          fill="url(#bloom-vignette)"
          style={{ pointerEvents: 'none' }}
        />
      </svg>

      {/* ---- top-left scene header ---- */}
      <div className="pointer-events-none absolute left-5 top-16 max-w-xs">
        <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-sky-300/80">
          Bloom · Graph Exploration
        </div>
        <div className="mt-1 text-sm text-slate-300/90">
          Click any node to expand its connections. They bloom outward; the
          scene re-centres on your selection.
        </div>
      </div>

      {/* ---- focus inspector card (bottom-left) ---- */}
      {focusNode && focusCat && (
        <div className="pointer-events-none absolute bottom-5 left-5 w-72 rounded-2xl border border-white/10 bg-slate-950/70 p-4 backdrop-blur-md">
          <div className="flex items-center gap-2">
            <span
              className="inline-block h-2.5 w-2.5 rounded-full"
              style={{ background: focusCat.color }}
            />
            <span className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-400">
              {focusCat.shortName}
            </span>
          </div>
          <div className="mt-1.5 text-lg font-semibold text-white">
            {focusNode.name}
          </div>
          <p className="mt-1 text-[12px] leading-snug text-slate-300/85">
            {focusNode.summary}
          </p>
          <div className="mt-2.5 text-[11px] text-slate-400">
            {hiddenCount > 0 ? (
              <span style={{ color: focusCat.color }}>
                {hiddenCount} more connection{hiddenCount > 1 ? 's' : ''} to expand
              </span>
            ) : (
              <span>All connections revealed</span>
            )}
          </div>
        </div>
      )}

      {/* ---- legend (top-right) ---- */}
      <div className="pointer-events-none absolute right-5 top-16 flex flex-col items-end gap-1.5">
        {categories.map((c) => (
          <div key={c.id} className="flex items-center gap-2">
            <span className="text-[10px] uppercase tracking-wider text-slate-400">
              {c.shortName}
            </span>
            <span
              className="inline-block h-2 w-2 rounded-full"
              style={{ background: c.color }}
            />
          </div>
        ))}
      </div>

      {/* ---- controls (bottom-right) ---- */}
      <div className="absolute bottom-5 right-5 flex items-center gap-2">
        <span className="rounded-full bg-slate-900/70 px-3 py-1.5 text-[11px] text-slate-400 backdrop-blur">
          {revealed.size} / {tools.length} nodes
        </span>
        <button
          type="button"
          onClick={reset}
          className="rounded-full border border-white/15 bg-white/5 px-4 py-1.5 text-[12px] font-medium text-slate-100 backdrop-blur transition hover:bg-white/12"
        >
          Collapse
        </button>
      </div>
    </div>
  );
}

// ---- subtle dotted grid that pans with the camera --------------------------
interface GridProps {
  w: number;
  h: number;
  camX: number;
  camY: number;
  ox: number;
  oy: number;
}
function GridLayer({ w, h, camX, camY, ox, oy }: GridProps) {
  const step = 56;
  const dots = useMemo(() => {
    const out: Array<[number, number]> = [];
    const cols = Math.ceil(w / step) + 2;
    const rows = Math.ceil(h / step) + 2;
    for (let i = 0; i < cols; i++) {
      for (let j = 0; j < rows; j++) {
        out.push([i, j]);
      }
    }
    return out;
  }, [w, h]);
  const offX = ((ox - camX) % step) - step;
  const offY = ((oy - camY) % step) - step;
  return (
    <g opacity={0.16}>
      {dots.map(([i, j]) => (
        <circle
          key={`${i}-${j}`}
          cx={offX + i * step}
          cy={offY + j * step}
          r={0.9}
          fill="#3a5277"
        />
      ))}
    </g>
  );
}
