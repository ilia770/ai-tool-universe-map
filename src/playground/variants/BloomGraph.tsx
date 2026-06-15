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
 * The core UX loop: start from a seed node and its neighbours, *expand* a node
 * to bloom its hidden neighbours outward on a clean radial fan, and *collapse*
 * step-by-step to walk back. Relationships are drawn as curved, directional
 * edges; focusing a node strongly highlights ONLY its direct connections while
 * everything else dims, so "what connects to what" is obvious at a glance.
 *
 * Interaction model (this is the part that makes it legible):
 *  - Click an UNEXPANDED node → expand it. Its hidden neighbours are seeded
 *    *at the parent's position* (appear=0) and SPRING outward, eased, onto an
 *    evenly-spaced angular fan pointing away from the parent's own anchor, so
 *    nodes never pile up. The camera eases to centre on the selection.
 *  - Click an already-EXPANDED node → collapse exactly the nodes it
 *    introduced (provenance-tracked), step-by-step. The ring count shrinks.
 *  - A breadcrumb of the expansion stack lets you "collapse last" or jump
 *    back to any earlier step. Escape collapses one step; Collapse-all resets.
 *
 * Layout is a deterministic Verlet-ish force simulation (repulsion + edge
 * springs + gravity) relaxing only the *visible* subgraph in a rAF loop.
 * Adjacency is derived from `relationIds` (made bidirectional). 2D SVG scene.
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

// directed relationship: the curated `relationIds` give us a natural source
// (the tool that declares the relation). Used for arrowhead direction.
const directedFrom: Set<string> = (() => {
  const s = new Set<string>();
  for (const t of tools) {
    for (const r of t.relationIds) {
      if (toolById.has(r)) s.add(`${t.id}->${r}`);
    }
  }
  return s;
})();

// ---- simulation node model -------------------------------------------------
interface SimNode {
  id: string;
  tool: AITool;
  cat: ToolCategory;
  x: number;
  y: number;
  vx: number;
  vy: number;
  appear: number; // 0 -> 1 spring-in
}

interface Edge {
  a: string;
  b: string;
  label: string;
  // directed a -> b for arrowhead (true when curated source is `a`)
  forward: boolean;
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

// relationship caption derived from the two tools' stages / category bond.
function edgeLabel(a: AITool, b: AITool): string {
  if (a.id === SEED_ID || b.id === SEED_ID) return 'ORCHESTRATES';
  if (a.category === b.category) return 'PEERS WITH';
  if (a.stage === b.stage) return `SHARES ${a.stage.toUpperCase()}`;
  return 'CONNECTS TO';
}

const NODE_R = 30;

export function BloomGraph() {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const [size, setSize] = useState({ w: 1200, h: 800 });

  // which tools are revealed
  const [revealed, setRevealed] = useState<Set<string>>(
    () => new Set([SEED_ID, ...(adjacency.get(SEED_ID) ?? [])]),
  );
  // which tools have been expanded (their hidden neighbours pulled in)
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set([SEED_ID]));
  // expansion stack: ordered provenance. Each entry records the parent that
  // was expanded and exactly which new ids it introduced — so collapse is
  // step-by-step and removes precisely what a given expansion added.
  const [stack, setStack] = useState<Array<{ parent: string; introduced: string[] }>>(
    () => [{ parent: SEED_ID, introduced: [...(adjacency.get(SEED_ID) ?? [])] }],
  );
  const [focusId, setFocusId] = useState<string>(SEED_ID);
  const [hoverId, setHoverId] = useState<string | null>(null);

  // mutable simulation state lives in refs (no per-frame React allocation)
  const nodesRef = useRef<Map<string, SimNode>>(new Map());
  const camRef = useRef({ x: 0, y: 0, tx: 0, ty: 0 });
  const rafRef = useRef<number>(0);
  const focusIdRef = useRef<string>(SEED_ID);
  const edgesRef = useRef<Edge[]>([]);
  // deterministic fan seeds queued when expanding: id -> target offset from
  // parent. The sim seeds the node at the parent then springs it to target.
  const fanSeedRef = useRef<Map<string, { px: number; py: number }>>(new Map());
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
    const fan = fanSeedRef.current;
    for (const id of revealed) {
      if (map.has(id)) continue;
      const tool = toolById.get(id);
      if (!tool) continue;
      const cat = categoryById.get(tool.category);
      if (!cat) continue;
      // If this id was queued by an expansion, seed it AT the parent so it
      // springs out to its fan target. Otherwise place near a neighbour.
      const seed = fan.get(id);
      let ox: number;
      let oy: number;
      if (seed) {
        ox = seed.px;
        oy = seed.py;
        fan.delete(id);
      } else if (id === SEED_ID) {
        ox = 0;
        oy = 0;
      } else {
        const neighbours = adjacency.get(id) ?? [];
        const anchor = neighbours.map((n) => map.get(n)).find((n) => n);
        if (anchor) {
          ox = anchor.x + 1;
          oy = anchor.y + 1;
        } else {
          ox = 0;
          oy = 0;
        }
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
        // orient a->b along the curated direction when available
        const forward = directedFrom.has(`${id}->${nb}`)
          ? true
          : directedFrom.has(`${nb}->${id}`)
            ? false
            : true;
        out.push({ a: id, b: nb, label: edgeLabel(a, b), forward });
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
      const liveEdges = edgesRef.current;
      const fId = focusIdRef.current;
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
          const force = 18000 / d2;
          const fx = (dx / d) * force;
          const fy = (dy / d) * force;
          a.vx += fx;
          a.vy += fy;
          b.vx -= fx;
          b.vy -= fy;
        }
      }

      // spring attraction along visible edges
      const REST = NODE_R * 4.6;
      for (const e of liveEdges) {
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
        a.vx *= 0.86;
        a.vy *= 0.86;
        a.x += a.vx;
        a.y += a.vy;
        // eased spring-in (overshoot-free easeOut feel)
        if (a.appear < 1) {
          a.appear = Math.min(1, a.appear + (1 - a.appear) * 0.12 + 0.012);
        }
      }

      // ease camera toward target, locked to the (moving) focus node
      const cam = camRef.current;
      cam.x += (cam.tx - cam.x) * 0.09;
      cam.y += (cam.ty - cam.y) * 0.09;
      const f = map.get(fId);
      if (f) {
        cam.tx = f.x;
        cam.ty = f.y;
      }

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

  // ---- expand a node: reveal its hidden neighbours on a radial fan ----
  const expand = useCallback(
    (id: string) => {
      setFocusId(id);
      const parent = nodesRef.current.get(id);
      const hidden = (adjacency.get(id) ?? []).filter((nb) => !revealed.has(nb));
      if (hidden.length === 0) return; // nothing new — just refocus

      // direction the fan should point: away from the parent's own anchor
      // (its nearest already-placed neighbour), so we never grow back inward.
      let baseAng = 0;
      if (parent) {
        const anchor = (adjacency.get(id) ?? [])
          .map((nb) => nodesRef.current.get(nb))
          .find((nd) => nd && nd.id !== id);
        if (anchor) {
          baseAng = Math.atan2(parent.y - anchor.y, parent.x - anchor.x);
        } else {
          // seed node: fan upward
          baseAng = -Math.PI / 2;
        }
      }
      // even angular fan, deterministic jitter via seeded PRNG. Each new node
      // is seeded *at* the parent (so it springs out from the click point) but
      // nudged a few px along its fan angle so repulsion resolves it onto the
      // intended clean arc rather than a random scatter — no overlap.
      const rng = mulberry32(0x9e3779b9 ^ (revealed.size * 2654435761));
      const spread = Math.min(Math.PI * 1.5, 0.55 * hidden.length + 0.6);
      const px0 = parent ? parent.x : 0;
      const py0 = parent ? parent.y : 0;
      const fan = fanSeedRef.current;
      hidden.forEach((nb, i) => {
        const t = hidden.length === 1 ? 0.5 : i / (hidden.length - 1);
        const ang = baseAng + (t - 0.5) * spread + (rng() - 0.5) * 0.12;
        const nudge = NODE_R * 0.9 + i * 0.4;
        fan.set(nb, {
          px: px0 + Math.cos(ang) * nudge,
          py: py0 + Math.sin(ang) * nudge,
        });
      });

      setExpanded((prev) => {
        if (prev.has(id)) return prev;
        const next = new Set(prev);
        next.add(id);
        return next;
      });
      setStack((prev) => [...prev, { parent: id, introduced: hidden }]);
      setRevealed((prev) => {
        const next = new Set(prev);
        for (const nb of hidden) next.add(nb);
        return next;
      });
    },
    [revealed],
  );

  // ---- collapse to keep only the first `keepCount` expansion steps ----
  // Recomputes revealed/expanded purely from the kept stack (provenance
  // replay), so later steps whose parent is gone cascade away cleanly.
  const collapseToIndex = useCallback(
    (keepCount: number) => {
      if (keepCount >= stack.length) return;
      const kept = stack.slice(0, keepCount);
      const reveal = new Set<string>([SEED_ID]);
      const exp = new Set<string>();
      for (const stepEntry of kept) {
        exp.add(stepEntry.parent);
        reveal.add(stepEntry.parent);
        for (const nb of stepEntry.introduced) reveal.add(nb);
      }
      const newFocus = kept.length > 0 ? kept[kept.length - 1].parent : SEED_ID;
      setStack(kept);
      setRevealed(reveal);
      setExpanded(exp);
      setFocusId(newFocus);
    },
    [stack],
  );

  // collapse the children a node introduced (click on already-expanded node)
  const collapseNode = useCallback(
    (id: string) => {
      const idx = stack.findIndex((s) => s.parent === id);
      if (idx <= 0) return; // never collapse the seed step
      collapseToIndex(idx);
    },
    [stack, collapseToIndex],
  );

  const collapseLast = useCallback(() => {
    collapseToIndex(Math.max(1, stack.length - 1));
  }, [collapseToIndex, stack.length]);

  const reset = useCallback(() => {
    setRevealed(new Set([SEED_ID, ...(adjacency.get(SEED_ID) ?? [])]));
    setExpanded(new Set([SEED_ID]));
    setStack([{ parent: SEED_ID, introduced: [...(adjacency.get(SEED_ID) ?? [])] }]);
    setFocusId(SEED_ID);
  }, []);

  // node click router: expanded → collapse its children; else expand
  const onNodeClick = useCallback(
    (id: string) => {
      if (id !== SEED_ID && expanded.has(id) && stack.some((s) => s.parent === id)) {
        setFocusId(id);
        collapseNode(id);
      } else {
        expand(id);
      }
    },
    [expanded, stack, collapseNode, expand],
  );

  // keyboard: escape collapses one step (step-by-step), shift+esc resets
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (e.shiftKey || stack.length <= 1) reset();
        else collapseLast();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [reset, collapseLast, stack.length]);

  // ---- viewport transform: world -> screen (reads snapshot, not refs) ----
  const cx = size.w / 2;
  const cy = size.h / 2 + 28; // generous top padding for lab chrome
  const toScreen = (x: number, y: number): [number, number] => [
    x - snapshot.camX + cx,
    y - snapshot.camY + cy,
  ];

  const map = useMemo(() => {
    const m = new Map<string, RenderNode>();
    for (const node of snapshot.nodes) m.set(node.id, node);
    return m;
  }, [snapshot]);
  const focusNode = focusId ? toolById.get(focusId) : undefined;
  const focusCat = focusNode ? categoryById.get(focusNode.category) : undefined;

  // active set: focus node + its visible neighbours (direct connections)
  const activeSet = useMemo(() => {
    const s = new Set<string>([focusId]);
    for (const nb of adjacency.get(focusId) ?? []) if (revealed.has(nb)) s.add(nb);
    return s;
  }, [focusId, revealed]);

  // paint dim edges first, then hovered, then active — so the highlighted
  // relationships always render on top and read crisply.
  const orderedEdges = useMemo(() => {
    const rank = (e: Edge) => {
      const isActive = activeSet.has(e.a) && activeSet.has(e.b);
      if (isActive) return 2;
      if (hoverId !== null && (hoverId === e.a || hoverId === e.b)) return 1;
      return 0;
    };
    return [...edges].sort((x, y) => rank(x) - rank(y));
  }, [edges, activeSet, hoverId]);

  const hiddenCount = focusNode
    ? (adjacency.get(focusId) ?? []).filter((nb) => !revealed.has(nb)).length
    : 0;
  const focusIsExpanded =
    focusId !== SEED_ID && expanded.has(focusId) && stack.some((s) => s.parent === focusId);

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
          {/* directional arrowheads — one tinted for active edges */}
          <marker
            id="bloom-arrow-dim"
            viewBox="0 0 10 10"
            refX="8"
            refY="5"
            markerWidth="6"
            markerHeight="6"
            orient="auto-start-reverse"
          >
            <path d="M 0 0 L 10 5 L 0 10 z" fill="#5b6b86" />
          </marker>
          <marker
            id="bloom-arrow-active"
            viewBox="0 0 10 10"
            refX="8"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto-start-reverse"
          >
            <path d="M 0 0 L 10 5 L 0 10 z" fill="#cfe0ff" />
          </marker>
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

        {/* edges (active/hover drawn last so highlights are never occluded) */}
        <g>
          {orderedEdges.map((e) => {
            const na = map.get(e.a);
            const nb = map.get(e.b);
            if (!na || !nb) return null;
            // draw in directed order a->b (curated source first)
            const src = e.forward ? na : nb;
            const dst = e.forward ? nb : na;
            const [ax, ay] = toScreen(src.x, src.y);
            const [bx, by] = toScreen(dst.x, dst.y);
            const isActive = activeSet.has(e.a) && activeSet.has(e.b);
            const isHover =
              hoverId !== null && (hoverId === e.a || hoverId === e.b);
            const appear = Math.min(na.appear, nb.appear);
            // curved quadratic bezier (perpendicular offset), shortened so the
            // arrowhead lands at the rim of the target node, not its centre.
            const dx = bx - ax;
            const dy = by - ay;
            const len = Math.hypot(dx, dy) || 1;
            const ux = dx / len;
            const uy = dy / len;
            const trim = NODE_R * 1.0;
            const sx = ax + ux * trim;
            const sy = ay + uy * trim;
            const ex = bx - ux * trim;
            const ey = by - uy * trim;
            const mx = (sx + ex) / 2;
            const my = (sy + ey) / 2;
            const off = 20;
            const px = mx + (-uy) * off;
            const py = my + ux * off;
            const focusedView = focusId !== SEED_ID || hoverId !== null;
            const baseOpacity = isActive
              ? 1
              : isHover
                ? 0.85
                : focusedView
                  ? 0.08
                  : 0.3;
            const opacity = baseOpacity * appear;
            return (
              <g key={`${e.a}|${e.b}`} style={{ opacity }}>
                <path
                  d={`M ${sx} ${sy} Q ${px} ${py} ${ex} ${ey}`}
                  fill="none"
                  stroke={isActive ? src.catGlow : '#5b6b86'}
                  strokeWidth={isActive ? 2.2 : isHover ? 1.6 : 1.1}
                  strokeLinecap="round"
                  markerEnd={
                    isActive
                      ? 'url(#bloom-arrow-active)'
                      : 'url(#bloom-arrow-dim)'
                  }
                />
                {(isActive || isHover) && (
                  <g style={{ pointerEvents: 'none' }}>
                    <rect
                      x={px - (e.label.length * 3.4 + 8)}
                      y={py - 9}
                      width={e.label.length * 6.8 + 16}
                      height={18}
                      rx={9}
                      fill="#070c16"
                      fillOpacity={0.92}
                      stroke={isActive ? src.catGlow : '#3c4a63'}
                      strokeOpacity={0.6}
                      strokeWidth={1}
                    />
                    <text
                      x={px}
                      y={py + 1}
                      fill={isActive ? '#eaf2ff' : '#9fb2d4'}
                      fontSize={9}
                      letterSpacing={1.1}
                      textAnchor="middle"
                      dominantBaseline="middle"
                      style={{ fontWeight: 700 }}
                    >
                      {e.label}
                    </text>
                  </g>
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
              (nb) => !revealed.has(nb),
            );
            const isExpandedNode =
              expanded.has(node.id) && stack.some((s) => s.parent === node.id);
            // spring-in: scale up from the parent point with a soft ease
            const ease = node.appear * node.appear * (3 - 2 * node.appear);
            const scale = ease * (isFocus ? 1.2 : isHover ? 1.09 : 1);
            const r = NODE_R * scale;
            const focusedView = focusId !== SEED_ID || hoverId !== null;
            const dim = inActive ? 1 : focusedView ? 0.22 : 1;
            const label = node.name;
            const labelW = Math.max(54, label.length * 7.0 + 26);
            return (
              <g
                key={node.id}
                transform={`translate(${nx} ${ny})`}
                style={{ cursor: 'pointer', opacity: ease * dim }}
                onMouseEnter={() => setHoverId(node.id)}
                onMouseLeave={() =>
                  setHoverId((h) => (h === node.id ? null : h))
                }
                onClick={() => onNodeClick(node.id)}
              >
                {/* focus / hover halo */}
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
                {/* expand affordance: dashed ring = undiscovered neighbours */}
                {hasHidden && !isExpandedNode && (
                  <circle
                    r={r + 5}
                    fill="none"
                    stroke={node.catColor}
                    strokeWidth={1.4}
                    strokeDasharray="3 5"
                    opacity={0.7}
                  />
                )}
                {/* collapse affordance: solid inner ring on expanded nodes */}
                {isExpandedNode && (
                  <circle
                    r={r + 5}
                    fill="none"
                    stroke={node.catGlow}
                    strokeWidth={1.4}
                    opacity={0.6}
                  />
                )}
                {/* node body */}
                <circle
                  r={r}
                  fill={node.catColor}
                  fillOpacity={0.16}
                  stroke={node.catColor}
                  strokeWidth={isFocus ? 2.6 : 1.6}
                  filter={isFocus ? 'url(#bloom-glow)' : undefined}
                />
                <circle r={r * 0.42} fill={node.catColor} fillOpacity={0.9} />
                {/* +/- glyph hint on hover for the active node */}
                {isHover && node.id !== SEED_ID && (
                  <text
                    x={0}
                    y={1}
                    fill="#eaf2ff"
                    fontSize={r * 0.5}
                    textAnchor="middle"
                    dominantBaseline="middle"
                    style={{ pointerEvents: 'none', fontWeight: 700 }}
                  >
                    {isExpandedNode ? '–' : hasHidden ? '+' : ''}
                  </text>
                )}
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
                    strokeOpacity={isFocus || inActive ? 0.8 : 0.45}
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
          Click a node to <span className="text-sky-200">expand</span> its
          connections. Click it again to{' '}
          <span className="text-sky-200">collapse</span>. Focusing dims the rest
          so it&apos;s clear what links to what.
        </div>
      </div>

      {/* ---- breadcrumb / expansion trail (top, centred under header) ---- */}
      <div className="pointer-events-auto absolute left-5 top-32 flex max-w-[60vw] flex-wrap items-center gap-1.5">
        {stack.map((s, i) => {
          const t = toolById.get(s.parent);
          const c = t ? categoryById.get(t.category) : undefined;
          const isLast = i === stack.length - 1;
          return (
            <span key={s.parent} className="flex items-center gap-1.5">
              {i > 0 && <span className="text-[11px] text-slate-600">›</span>}
              <button
                type="button"
                onClick={() => collapseToIndex(i + 1)}
                className="flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium backdrop-blur transition"
                style={{
                  borderColor: isLast
                    ? (c?.color ?? '#7dd3fc') + '99'
                    : 'rgba(255,255,255,0.1)',
                  background: isLast
                    ? (c?.color ?? '#7dd3fc') + '1f'
                    : 'rgba(15,23,42,0.6)',
                  color: isLast ? '#eaf2ff' : '#94a3b8',
                }}
              >
                <span
                  className="inline-block h-1.5 w-1.5 rounded-full"
                  style={{ background: c?.color ?? '#7dd3fc' }}
                />
                {t?.name ?? s.parent}
              </button>
            </span>
          );
        })}
      </div>

      {/* ---- focus inspector card (bottom-left) ---- */}
      {focusNode && focusCat && (
        <div className="absolute bottom-5 left-5 w-72 rounded-2xl border border-white/10 bg-slate-950/70 p-4 backdrop-blur-md">
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
          <div className="mt-3 flex items-center gap-2">
            {hiddenCount > 0 ? (
              <button
                type="button"
                onClick={() => expand(focusId)}
                className="rounded-full px-3 py-1.5 text-[11px] font-semibold text-slate-900 transition hover:brightness-110"
                style={{ background: focusCat.color }}
              >
                + Expand {hiddenCount} connection{hiddenCount > 1 ? 's' : ''}
              </button>
            ) : (
              <span className="text-[11px] text-slate-400">
                All connections revealed
              </span>
            )}
            {focusIsExpanded && (
              <button
                type="button"
                onClick={() => collapseNode(focusId)}
                className="rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-[11px] font-medium text-slate-200 transition hover:bg-white/12"
              >
                – Collapse
              </button>
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
          onClick={collapseLast}
          disabled={stack.length <= 1}
          className="rounded-full border border-white/15 bg-white/5 px-4 py-1.5 text-[12px] font-medium text-slate-100 backdrop-blur transition hover:bg-white/12 disabled:cursor-not-allowed disabled:opacity-35"
        >
          Collapse last
        </button>
        <button
          type="button"
          onClick={reset}
          disabled={stack.length <= 1}
          className="rounded-full border border-white/15 bg-white/5 px-4 py-1.5 text-[12px] font-medium text-slate-100 backdrop-blur transition hover:bg-white/12 disabled:cursor-not-allowed disabled:opacity-35"
        >
          Reset
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
