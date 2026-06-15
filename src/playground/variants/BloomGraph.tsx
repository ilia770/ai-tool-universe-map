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
  // collapse target: when a node is removed we don't pop it; we mark it
  // collapsing and let `appear` ease back to 0 (springing toward `px,py`,
  // its parent), then drop it from the sim once invisible.
  collapsing: boolean;
  px: number;
  py: number;
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
  appear: number; // 0 -> 1 spring-in / spring-out (collapse fades to 0)
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

// typed relationship between a focused tool and a neighbour, used by the
// detail-panel chips so "follow the connections" reads at a glance.
type RelKind = 'ORCHESTRATES' | 'PEER' | 'CONNECTS';
function relationKind(focus: AITool, nb: AITool): RelKind {
  if (focus.id === SEED_ID || nb.id === SEED_ID) return 'ORCHESTRATES';
  if (focus.category === nb.category) return 'PEER';
  return 'CONNECTS';
}

// shortest path (BFS over bidirectional adjacency) between two tools, used to
// reveal a hidden target found via search / chip navigation by blooming each
// hop along the way. Returns the id chain inclusive of both ends, or null.
function shortestPath(from: string, to: string): string[] | null {
  if (from === to) return [from];
  const prev = new Map<string, string>();
  const queue: string[] = [from];
  const seen = new Set<string>([from]);
  while (queue.length) {
    const cur = queue.shift() as string;
    for (const nb of adjacency.get(cur) ?? []) {
      if (seen.has(nb)) continue;
      seen.add(nb);
      prev.set(nb, cur);
      if (nb === to) {
        const path = [to];
        let p = cur;
        while (p !== from) {
          path.unshift(p);
          p = prev.get(p) as string;
        }
        path.unshift(from);
        return path;
      }
      queue.push(nb);
    }
  }
  return null;
}

const NODE_R = 30;

// All logical edges, computed once. Render filters by node presence so edges
// fade with their (springing-out) nodes instead of popping; the simulation
// filters by `revealed` so collapsing nodes aren't spring-held in place.
const allEdges: Edge[] = (() => {
  const seen = new Set<string>();
  const out: Edge[] = [];
  for (const t of tools) {
    const a = t;
    for (const nb of adjacency.get(t.id) ?? []) {
      const key = t.id < nb ? `${t.id}|${nb}` : `${nb}|${t.id}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const b = toolById.get(nb);
      if (!b) continue;
      const forward = directedFrom.has(`${t.id}->${nb}`)
        ? true
        : directedFrom.has(`${nb}->${t.id}`)
          ? false
          : true;
      out.push({ a: t.id, b: nb, label: edgeLabel(a, b), forward });
    }
  }
  return out;
})();

export function BloomGraph() {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const [size, setSize] = useState({ w: 1200, h: 800 });

  // calm motion further when the OS requests reduced motion. Read live so the
  // sim loop (which only mounts once) can honour the latest preference.
  const reducedMotionRef = useRef(false);
  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const apply = () => {
      reducedMotionRef.current = mq.matches;
    };
    apply();
    mq.addEventListener('change', apply);
    return () => mq.removeEventListener('change', apply);
  }, []);

  // small-viewport flag for lightweight ambient counts (grid density, etc.)
  const isCompact = size.w < 768;

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

  // search + category filter (production: start exploration from any tool,
  // constrain what blooms). Both are purely additive to the bloom model.
  const [query, setQuery] = useState('');
  const [mutedCats, setMutedCats] = useState<Set<string>>(() => new Set());
  const searchRef = useRef<HTMLInputElement | null>(null);

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
        collapsing: false,
        px: ox,
        py: oy,
      });
    }
    // collapse: don't pop nodes — mark them collapsing so they ease back
    // toward the nearest still-revealed neighbour (their visual "parent")
    // and the sim drops them only once they've faded out.
    for (const node of map.values()) {
      if (revealed.has(node.id)) {
        // re-revealing a node mid-collapse should cancel the collapse
        if (node.collapsing) node.collapsing = false;
        continue;
      }
      if (!node.collapsing) {
        node.collapsing = true;
        const anchor = (adjacency.get(node.id) ?? [])
          .map((nb) => map.get(nb))
          .find((nd) => nd && revealed.has(nd.id) && !nd.collapsing);
        node.px = anchor ? anchor.x : 0;
        node.py = anchor ? anchor.y : 0;
      }
    }
  }, [revealed]);

  // ---- visible edges (both endpoints revealed) — drives simulation springs.
  const edges = useMemo<Edge[]>(
    () => allEdges.filter((e) => revealed.has(e.a) && revealed.has(e.b)),
    [revealed],
  );

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

      const reduced = reducedMotionRef.current;
      // ease constants: gentler springs when reduced motion is requested.
      const camEase = reduced ? 0.16 : 0.09;
      const appearGain = reduced ? 0.2 : 0.12;
      const appearBias = reduced ? 0.02 : 0.012;

      // repulsion (O(n^2) — fine for <=49 nodes). Collapsing nodes are leaving
      // so they neither push nor get pushed — keeps the staying cluster calm.
      for (let i = 0; i < n; i++) {
        const a = arr[i];
        if (a.collapsing) continue;
        for (let j = i + 1; j < n; j++) {
          const b = arr[j];
          if (b.collapsing) continue;
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
        if (a.collapsing) {
          // spring HOME toward the parent point while fading out — no pop.
          a.x += (a.px - a.x) * (reduced ? 0.22 : 0.16);
          a.y += (a.py - a.y) * (reduced ? 0.22 : 0.16);
          a.vx = 0;
          a.vy = 0;
          a.appear += (0 - a.appear) * (reduced ? 0.28 : 0.18) - 0.012;
          if (a.appear <= 0.02) {
            a.appear = 0;
            map.delete(a.id);
          }
          continue;
        }
        a.vx += -a.x * 0.0009;
        a.vy += -a.y * 0.0009;
        a.vx *= 0.86;
        a.vy *= 0.86;
        a.x += a.vx;
        a.y += a.vy;
        // eased spring-in (overshoot-free easeOut feel)
        if (a.appear < 1) {
          a.appear = Math.min(1, a.appear + (1 - a.appear) * appearGain + appearBias);
        }
      }

      // ease camera toward target, locked to the (moving) focus node
      const cam = camRef.current;
      cam.x += (cam.tx - cam.x) * camEase;
      cam.y += (cam.ty - cam.y) * camEase;
      const f = map.get(fId);
      if (f && !f.collapsing) {
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

  // ---- reveal a (possibly hidden) tool by blooming each hop along the BFS
  // path from the nearest already-revealed seed, then focus it. Powers search
  // results and detail-panel relationship chips: any tool becomes reachable
  // while keeping the breadcrumb provenance coherent. Hops are recorded as
  // expansion steps so collapse still walks back cleanly.
  const revealAndFocus = useCallback(
    (targetId: string) => {
      if (!toolById.has(targetId)) return;
      if (revealed.has(targetId)) {
        setFocusId(targetId);
        return;
      }
      // find a path from a currently-revealed node to the target so we bloom
      // a connected trail (never an orphan). Prefer the focus node's path.
      const sources = [focusId, ...revealed];
      let path: string[] | null = null;
      for (const s of sources) {
        const p = shortestPath(s, targetId);
        if (p) {
          path = p;
          break;
        }
      }
      if (!path) {
        setFocusId(targetId);
        return;
      }

      // bloom along the path: each hop's neighbour-set is the next node.
      const nextRevealed = new Set(revealed);
      const newSteps: Array<{ parent: string; introduced: string[] }> = [];
      const nextExpanded = new Set<string>();
      const fan = fanSeedRef.current;
      const map = nodesRef.current;
      for (let i = 0; i < path.length - 1; i++) {
        const parentId = path[i];
        const childId = path[i + 1];
        if (nextRevealed.has(childId)) continue;
        nextRevealed.add(childId);
        nextExpanded.add(parentId);
        newSteps.push({ parent: parentId, introduced: [childId] });
        // seed the child at the parent so it springs out (matches `expand`).
        const parentNode = map.get(parentId);
        const px0 = parentNode ? parentNode.x : 0;
        const py0 = parentNode ? parentNode.y : 0;
        const ang = -Math.PI / 2 + i * 0.7;
        fan.set(childId, {
          px: px0 + Math.cos(ang) * (NODE_R * 1.1),
          py: py0 + Math.sin(ang) * (NODE_R * 1.1),
        });
      }

      if (newSteps.length > 0) {
        setRevealed(nextRevealed);
        setExpanded((prev) => new Set([...prev, ...nextExpanded]));
        setStack((prev) => [...prev, ...newSteps]);
      }
      setFocusId(targetId);
    },
    [revealed, focusId],
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

  // keyboard: Escape clears an active search/category filter first, otherwise
  // collapses one step (step-by-step); shift+esc resets. "/" focuses search.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === '/' && document.activeElement !== searchRef.current) {
        e.preventDefault();
        searchRef.current?.focus();
        return;
      }
      if (e.key === 'Escape') {
        if (query || mutedCats.size > 0) {
          setQuery('');
          setMutedCats(new Set());
          searchRef.current?.blur();
          return;
        }
        if (e.shiftKey || stack.length <= 1) reset();
        else collapseLast();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [reset, collapseLast, stack.length, query, mutedCats]);

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

  // ---- search matches (across ALL tools, not just revealed) ----
  const trimmedQuery = query.trim().toLowerCase();
  const searchMatches = useMemo(() => {
    if (!trimmedQuery) return [] as AITool[];
    return tools
      .filter(
        (t) =>
          t.name.toLowerCase().includes(trimmedQuery) ||
          t.summary.toLowerCase().includes(trimmedQuery) ||
          (categoryById.get(t.category)?.name.toLowerCase().includes(trimmedQuery) ??
            false),
      )
      .slice(0, 6);
  }, [trimmedQuery]);
  const matchIds = useMemo(
    () => new Set(searchMatches.map((t) => t.id)),
    [searchMatches],
  );

  // ---- category mute set: tools whose category is muted recede (eased) ----
  const anyMuted = mutedCats.size > 0;

  // counts per category over the full universe (legend chips)
  const catCounts = useMemo(() => {
    const m = new Map<string, number>();
    for (const t of tools) m.set(t.category, (m.get(t.category) ?? 0) + 1);
    return m;
  }, []);

  const toggleCat = useCallback((id: string) => {
    setMutedCats((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  // active set: focus node + its visible neighbours (direct connections)
  const activeSet = useMemo(() => {
    const s = new Set<string>([focusId]);
    for (const nb of adjacency.get(focusId) ?? []) if (revealed.has(nb)) s.add(nb);
    return s;
  }, [focusId, revealed]);

  // Render edges whose BOTH endpoints are currently in the sim snapshot
  // (revealed OR still springing out). This lets collapsing edges fade with
  // their nodes instead of popping. Paint dim edges first, then hovered, then
  // active — so highlighted relationships render on top and read crisply.
  const orderedEdges = useMemo(() => {
    const rank = (e: Edge) => {
      const isActive = activeSet.has(e.a) && activeSet.has(e.b);
      if (isActive) return 2;
      if (hoverId !== null && (hoverId === e.a || hoverId === e.b)) return 1;
      return 0;
    };
    return allEdges
      .filter((e) => map.has(e.a) && map.has(e.b))
      .sort((x, y) => rank(x) - rank(y));
  }, [map, activeSet, hoverId]);

  const hiddenCount = focusNode
    ? (adjacency.get(focusId) ?? []).filter((nb) => !revealed.has(nb)).length
    : 0;
  const focusIsExpanded =
    focusId !== SEED_ID && expanded.has(focusId) && stack.some((s) => s.parent === focusId);

  // typed relationship chips for the detail panel: every neighbour of the
  // focus node, its kind (ORCHESTRATES/PEER/CONNECTS) and whether it's already
  // revealed. Clicking a chip blooms+focuses that neighbour. Revealed chips
  // first so the visible graph is easy to walk.
  const relationChips = useMemo(() => {
    if (!focusNode) return [];
    const out: Array<{
      tool: AITool;
      cat: ToolCategory | undefined;
      kind: RelKind;
      revealed: boolean;
    }> = [];
    for (const nb of adjacency.get(focusNode.id) ?? []) {
      const t = toolById.get(nb);
      if (!t) continue;
      out.push({
        tool: t,
        cat: categoryById.get(t.category),
        kind: relationKind(focusNode, t),
        revealed: revealed.has(nb),
      });
    }
    out.sort((a, b) => Number(b.revealed) - Number(a.revealed));
    return out;
  }, [focusNode, revealed]);

  const stageLabel = focusNode
    ? focusNode.stage.charAt(0).toUpperCase() + focusNode.stage.slice(1)
    : '';

  return (
    <div
      ref={wrapRef}
      className="absolute inset-0 overflow-hidden select-none"
      style={{
        background:
          'radial-gradient(120% 100% at 50% 0%, #0b1220 0%, #060912 55%, #03060d 100%)',
      }}
    >
      <style>{`
        @keyframes bloomCardIn {
          from { opacity: 0; transform: translateY(6px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-reduced-motion: reduce) {
          [style*="bloomCardIn"] { animation: none !important; }
        }
      `}</style>
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
          compact={isCompact}
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
            const ta = toolById.get(e.a);
            const tb = toolById.get(e.b);
            const edgeMuted =
              anyMuted &&
              ((ta ? mutedCats.has(ta.category) : false) ||
                (tb ? mutedCats.has(tb.category) : false));
            let baseOpacity = isActive
              ? 1
              : isHover
                ? 0.85
                : focusedView
                  ? 0.08
                  : 0.3;
            if (edgeMuted && !isActive) baseOpacity = Math.min(baseOpacity, 0.05);
            // Two-layer opacity: outer group eases the highlight/dim change
            // (CSS transition → no snap on selection); inner group carries the
            // frame-driven spring `appear` (no transition → tracks the sim).
            return (
              <g
                key={`${e.a}|${e.b}`}
                style={{
                  opacity: baseOpacity,
                  transition: 'opacity 320ms cubic-bezier(0.22,1,0.36,1)',
                }}
              >
                <g style={{ opacity: appear }}>
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
            const nodeTool = toolById.get(node.id);
            const isMutedCat = nodeTool ? mutedCats.has(nodeTool.category) : false;
            const isMatch = matchIds.has(node.id);
            // spring-in: scale up from the parent point with a soft ease
            const ease = node.appear * node.appear * (3 - 2 * node.appear);
            const scale = ease * (isFocus ? 1.2 : isHover ? 1.09 : 1);
            const r = NODE_R * scale;
            const focusedView = focusId !== SEED_ID || hoverId !== null;
            // dim priority: muted category recedes hardest, then non-active in a
            // focused view, then search dims unmatched while a query is active.
            let dim = inActive ? 1 : focusedView ? 0.22 : 1;
            if (isMutedCat && !isFocus) dim = Math.min(dim, 0.1);
            if (trimmedQuery && !isMatch && !isFocus) dim = Math.min(dim, 0.16);
            const label = node.name;
            const labelW = Math.max(54, label.length * 7.0 + 26);
            // comfortable touch target — at least ~22px radius regardless of
            // the visual node size, so taps land on phones.
            const hitR = Math.max(r + 14, 26);
            return (
              <g
                key={node.id}
                transform={`translate(${nx} ${ny})`}
                style={{ cursor: 'pointer' }}
                onMouseEnter={() => setHoverId(node.id)}
                onMouseLeave={() =>
                  setHoverId((h) => (h === node.id ? null : h))
                }
                onClick={() => onNodeClick(node.id)}
              >
                {/* invisible generous hit area for touch */}
                <circle r={hitR} fill="transparent" />
                {/* inner: frame-driven spring `appear` (no transition) wrapped
                    by CSS-eased highlight `dim` (smooth on selection). */}
                <g
                  style={{
                    opacity: dim,
                    transition: 'opacity 320ms cubic-bezier(0.22,1,0.36,1)',
                  }}
                >
                <g style={{ opacity: ease }}>
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
                {/* search-match pulse ring (only while a query is active) */}
                {isMatch && !isFocus && (
                  <circle
                    r={r + 9}
                    fill="none"
                    stroke="#fde68a"
                    strokeWidth={1.8}
                    opacity={0.85}
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

      {/* ---- top-left scene header (liquid glass) ---- */}
      <div className="pointer-events-none absolute left-4 top-16 max-w-[min(20rem,calc(100vw-2rem))] rounded-2xl border border-white/10 bg-white/[0.07] p-3.5 shadow-[0_8px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
        <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-sky-300/80">
          Bloom · Graph Exploration
        </div>
        <div className="mt-1 text-[13px] leading-snug text-slate-300/90">
          Tap a node to <span className="text-sky-200">expand</span> its
          connections. Tap it again to{' '}
          <span className="text-sky-200">collapse</span>. Focusing dims the rest
          so it&apos;s clear what links to what.
        </div>
        <div className="mt-2 text-[11px] text-slate-400/80">
          Press{' '}
          <kbd className="rounded bg-white/10 px-1 py-0.5 font-mono text-[10px] text-slate-200">
            /
          </kbd>{' '}
          to search · <span className="text-slate-300">Esc</span> to step back
        </div>
      </div>

      {/* ---- search (top-center) — liquid glass; starts exploration anywhere ---- */}
      <div className="pointer-events-auto absolute left-1/2 top-16 z-20 w-[min(22rem,calc(100vw-2rem))] -translate-x-1/2">
        <div className="overflow-hidden rounded-2xl border border-white/10 bg-white/[0.07] shadow-[0_8px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
          <div className="flex items-center gap-2 px-3">
            <svg
              width="15"
              height="15"
              viewBox="0 0 24 24"
              fill="none"
              className="shrink-0 text-slate-400"
              aria-hidden
            >
              <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="2" />
              <path
                d="m20 20-3.5-3.5"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
            <input
              ref={searchRef}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && searchMatches.length > 0) {
                  revealAndFocus(searchMatches[0].id);
                } else if (e.key === 'Escape') {
                  if (query) {
                    e.stopPropagation();
                    setQuery('');
                  } else {
                    searchRef.current?.blur();
                  }
                }
              }}
              type="text"
              inputMode="search"
              placeholder="Search the AI-tool universe…"
              aria-label="Search tools"
              className="min-h-[40px] w-full bg-transparent py-2 text-[13px] text-slate-100 placeholder:text-slate-500 focus:outline-none"
            />
            {query && (
              <button
                type="button"
                onClick={() => setQuery('')}
                aria-label="Clear search"
                className="shrink-0 rounded-full px-1.5 text-[16px] leading-none text-slate-400 transition hover:text-slate-100"
              >
                ×
              </button>
            )}
          </div>
          {trimmedQuery && (
            <div className="border-t border-white/10 px-1.5 pb-1.5 pt-1">
              {searchMatches.length === 0 ? (
                <div className="px-2.5 py-2 text-[12px] text-slate-400">
                  No tools match “{query.trim()}”.
                </div>
              ) : (
                searchMatches.map((t, i) => {
                  const c = categoryById.get(t.category);
                  return (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => revealAndFocus(t.id)}
                      className="flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2 text-left transition hover:bg-white/[0.08] active:scale-[0.99]"
                    >
                      <span
                        className="inline-block h-2 w-2 shrink-0 rounded-full"
                        style={{ background: c?.color ?? '#7dd3fc' }}
                      />
                      <span className="flex min-w-0 flex-col">
                        <span className="truncate text-[12.5px] font-medium text-slate-100">
                          {t.name}
                        </span>
                        <span className="truncate text-[10.5px] text-slate-400">
                          {c?.shortName} · {t.stage}
                        </span>
                      </span>
                      {i === 0 && (
                        <span className="ml-auto shrink-0 rounded bg-white/10 px-1.5 py-0.5 font-mono text-[9px] text-slate-300">
                          ↵
                        </span>
                      )}
                    </button>
                  );
                })
              )}
            </div>
          )}
        </div>
      </div>

      {/* ---- breadcrumb / expansion trail (top, under header) — glass ---- */}
      {stack.length > 1 && (
        <div className="pointer-events-auto absolute left-4 right-4 top-[8.5rem] flex max-w-[min(60vw,40rem)] flex-wrap items-center gap-1.5 rounded-2xl border border-white/10 bg-white/[0.06] px-2.5 py-2 shadow-[0_8px_30px_rgba(0,0,0,0.3)] backdrop-blur-2xl sm:right-auto">
          {stack.map((s, i) => {
            const t = toolById.get(s.parent);
            const c = t ? categoryById.get(t.category) : undefined;
            const isLast = i === stack.length - 1;
            return (
              <span key={s.parent} className="flex items-center gap-1.5">
                {i > 0 && <span className="text-[11px] text-slate-500">›</span>}
                <button
                  type="button"
                  onClick={() => collapseToIndex(i + 1)}
                  className="flex min-h-[30px] items-center gap-1.5 rounded-full border px-3 py-1 text-[11px] font-medium transition active:scale-[0.97]"
                  style={{
                    borderColor: isLast
                      ? (c?.color ?? '#7dd3fc') + '99'
                      : 'rgba(255,255,255,0.12)',
                    background: isLast
                      ? (c?.color ?? '#7dd3fc') + '24'
                      : 'rgba(255,255,255,0.05)',
                    color: isLast ? '#eaf2ff' : '#aab8cf',
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
      )}

      {/* ---- tool detail panel (bottom-left) — liquid glass ---- */}
      {focusNode && focusCat && (
        <div className="absolute bottom-4 left-4 flex max-h-[calc(100vh-9rem)] w-[min(20rem,calc(100vw-2rem))] flex-col overflow-hidden rounded-2xl border border-white/10 bg-white/[0.07] shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-2xl">
          {/* keyed so content cross-fades smoothly between selections */}
          <div
            key={focusNode.id}
            className="flex min-h-0 flex-col"
            style={{ animation: 'bloomCardIn 320ms cubic-bezier(0.22,1,0.36,1)' }}
          >
            <div className="px-4 pt-4">
              <div className="flex items-center gap-2">
                <span
                  className="inline-block h-2.5 w-2.5 rounded-full"
                  style={{ background: focusCat.color }}
                />
                <span className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                  {focusCat.shortName}
                </span>
                <span className="text-slate-600">·</span>
                <span
                  className="rounded-full px-2 py-0.5 text-[9.5px] font-semibold uppercase tracking-[0.12em]"
                  style={{
                    color: focusCat.glow,
                    background: focusCat.color + '1f',
                  }}
                >
                  {stageLabel}
                </span>
              </div>
              <div className="mt-1.5 flex items-start justify-between gap-2">
                <div className="text-lg font-semibold leading-tight text-white">
                  {focusNode.name}
                </div>
                {focusNode.url && (
                  <a
                    href={focusNode.url}
                    target="_blank"
                    rel="noreferrer noopener"
                    className="mt-0.5 inline-flex shrink-0 items-center gap-1 rounded-full border border-white/15 bg-white/[0.06] px-2.5 py-1 text-[10.5px] font-medium text-slate-200 transition hover:bg-white/[0.12] active:scale-[0.97]"
                  >
                    Open
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" aria-hidden>
                      <path
                        d="M7 17 17 7M9 7h8v8"
                        stroke="currentColor"
                        strokeWidth="2.2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </a>
                )}
              </div>
              <p className="mt-1.5 text-[12px] leading-relaxed text-slate-300/85">
                {focusNode.summary}
              </p>
            </div>

            {/* connected-to: typed relationship chips */}
            {relationChips.length > 0 && (
              <div className="mt-3 flex min-h-0 flex-col px-4">
                <div className="mb-1.5 flex items-center justify-between">
                  <span className="text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-400">
                    Connected to · {relationChips.length}
                  </span>
                </div>
                <div className="-mr-1 flex max-h-[9.5rem] flex-wrap gap-1.5 overflow-y-auto pr-1">
                  {relationChips.map((rel) => (
                    <button
                      key={rel.tool.id}
                      type="button"
                      onClick={() => revealAndFocus(rel.tool.id)}
                      onMouseEnter={() => setHoverId(rel.tool.id)}
                      onMouseLeave={() =>
                        setHoverId((h) => (h === rel.tool.id ? null : h))
                      }
                      className="group flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] transition active:scale-[0.97]"
                      style={{
                        borderColor: rel.revealed
                          ? (rel.cat?.color ?? '#7dd3fc') + '66'
                          : 'rgba(255,255,255,0.1)',
                        background: rel.revealed
                          ? (rel.cat?.color ?? '#7dd3fc') + '14'
                          : 'rgba(255,255,255,0.03)',
                      }}
                    >
                      <span
                        className="inline-block h-1.5 w-1.5 shrink-0 rounded-full"
                        style={{
                          background: rel.revealed
                            ? (rel.cat?.color ?? '#7dd3fc')
                            : 'transparent',
                          boxShadow: rel.revealed
                            ? 'none'
                            : `inset 0 0 0 1.5px ${rel.cat?.color ?? '#7dd3fc'}`,
                        }}
                      />
                      <span className="font-medium text-slate-100">
                        {rel.tool.name}
                      </span>
                      <span
                        className="text-[8.5px] font-bold uppercase tracking-[0.08em]"
                        style={{ color: (rel.cat?.glow ?? '#9fb2d4') + 'cc' }}
                      >
                        {rel.kind}
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            )}

            <div className="mt-3 flex flex-wrap items-center gap-2 px-4 pb-4">
              {hiddenCount > 0 ? (
                <button
                  type="button"
                  onClick={() => expand(focusId)}
                  className="min-h-[34px] rounded-full px-3.5 py-1.5 text-[11px] font-semibold text-slate-900 transition hover:brightness-110 active:scale-[0.97]"
                  style={{ background: focusCat.color }}
                >
                  + Expand all {hiddenCount} neighbour{hiddenCount > 1 ? 's' : ''}
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
                  className="min-h-[34px] rounded-full border border-white/15 bg-white/[0.06] px-3.5 py-1.5 text-[11px] font-medium text-slate-200 transition hover:bg-white/[0.12] active:scale-[0.97]"
                >
                  – Collapse
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ---- category filter + legend (top-right) — interactive glass ---- */}
      <div className="pointer-events-auto absolute right-4 top-16 hidden w-[12.5rem] flex-col gap-1 rounded-2xl border border-white/10 bg-white/[0.06] px-2.5 py-2.5 shadow-[0_8px_30px_rgba(0,0,0,0.3)] backdrop-blur-2xl sm:flex">
        <div className="mb-0.5 flex items-center justify-between px-1">
          <span className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-400">
            Categories
          </span>
          {anyMuted && (
            <button
              type="button"
              onClick={() => setMutedCats(new Set())}
              className="rounded-full px-1.5 text-[10px] text-sky-300/90 transition hover:text-sky-200"
            >
              Reset
            </button>
          )}
        </div>
        {categories.map((c) => {
          const muted = mutedCats.has(c.id);
          return (
            <button
              key={c.id}
              type="button"
              onClick={() => toggleCat(c.id)}
              aria-pressed={!muted}
              className="flex min-h-[30px] items-center gap-2 rounded-lg px-2 py-1 text-left transition active:scale-[0.98]"
              style={{
                background: muted ? 'transparent' : 'rgba(255,255,255,0.05)',
                opacity: muted ? 0.4 : 1,
              }}
            >
              <span
                className="inline-block h-2.5 w-2.5 shrink-0 rounded-full"
                style={{
                  background: muted ? 'transparent' : c.color,
                  boxShadow: muted ? `inset 0 0 0 1.5px ${c.color}` : 'none',
                }}
              />
              <span className="flex-1 truncate text-[11px] text-slate-200">
                {c.shortName}
              </span>
              <span className="shrink-0 text-[10px] tabular-nums text-slate-400">
                {catCounts.get(c.id) ?? 0}
              </span>
            </button>
          );
        })}
      </div>

      {/* ---- controls (bottom-right) — liquid glass ---- */}
      <div className="absolute bottom-4 right-4 flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.06] px-2 py-2 shadow-[0_8px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
        <span className="hidden rounded-full bg-white/[0.04] px-3 py-1.5 text-[11px] text-slate-300/80 sm:inline">
          {revealed.size} / {tools.length} nodes
        </span>
        <button
          type="button"
          onClick={collapseLast}
          disabled={stack.length <= 1}
          className="min-h-[36px] rounded-full border border-white/15 bg-white/[0.06] px-4 py-1.5 text-[12px] font-medium text-slate-100 transition hover:bg-white/[0.12] active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-35 disabled:active:scale-100"
        >
          Collapse last
        </button>
        <button
          type="button"
          onClick={reset}
          disabled={stack.length <= 1}
          className="min-h-[36px] rounded-full border border-white/15 bg-white/[0.06] px-4 py-1.5 text-[12px] font-medium text-slate-100 transition hover:bg-white/[0.12] active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-35 disabled:active:scale-100"
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
  compact: boolean;
}
function GridLayer({ w, h, camX, camY, ox, oy, compact }: GridProps) {
  // Larger spacing on small viewports = fewer dots (lighter on mobile).
  const step = compact ? 72 : 56;
  const dots = useMemo(() => {
    const out: Array<[number, number]> = [];
    const cols = Math.ceil(w / step) + 2;
    const rows = Math.ceil(h / step) + 2;
    // hard cap on dot count so very large viewports never blow up the DOM.
    const maxDots = 900;
    for (let i = 0; i < cols; i++) {
      for (let j = 0; j < rows; j++) {
        if (out.length >= maxDots) break;
        out.push([i, j]);
      }
    }
    return out;
  }, [w, h, step]);
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
