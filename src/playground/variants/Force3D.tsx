import { useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, type ThreeEvent } from '@react-three/fiber';
import { CameraControls, Billboard, Text, Line } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  toolById,
  categoryById,
  workflowStages,
  type AITool,
  type ToolCategoryId,
  type WorkflowStageId,
} from '../../data/ai-tool-universe';

// ---------------------------------------------------------------------------
// Viewport + motion environment (read once, outside render where possible).
// On phones we draw a sparser reference grid and calm motion further.
// ---------------------------------------------------------------------------
function readEnv(): { compact: boolean; reduceMotion: boolean } {
  if (typeof window === 'undefined') {
    return { compact: false, reduceMotion: false };
  }
  return {
    compact: window.innerWidth < 768,
    reduceMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  };
}

// Frame-rate-independent damping factor for an exponential ease toward target.
// `rate` ~ fraction of remaining gap closed per second.
function damp(rate: number, delta: number): number {
  return 1 - Math.pow(1 - rate, Math.min(delta, 0.05) * 60);
}

/**
 * Direction N — "3D Force Graph" (structural / engineering-grade).
 *
 * A true 3D force-directed layout in the spirit of vasturiano/3d-force-graph:
 * crisp visible edges, spheres clearly sized by degree, readable cluster
 * structure under directional lighting. The emphasis is precision and
 * navigability — inspect the *real* connections in 3D — NOT cinematic bloom.
 *
 * Layout (d3-force-3d technique): velocity-Verlet integration with a
 * many-body charge force (repulsion), a link spring force (relations), an
 * intra-category cohesion force (so clusters read clearly), and a weak
 * centering force. Precomputed deterministically with a seeded PRNG and a
 * fixed iteration count with alpha decay, so there is no Math.random() at
 * render time and no per-frame allocation in the animation loop.
 */

// ---------------------------------------------------------------------------
// Deterministic PRNG (mulberry32) — seeded so the layout is identical every
// mount and never calls Math.random() during render / module init.
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Graph model
// ---------------------------------------------------------------------------
interface GraphNode {
  id: string;
  tool: AITool;
  color: THREE.Color;
  degree: number;
  radius: number;
  // simulation state
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
}

interface GraphEdge {
  a: number; // node index
  b: number; // node index
}

interface Layout {
  nodes: GraphNode[];
  edges: GraphEdge[];
  indexById: Map<string, number>;
  // flat edge geometry positions (2 verts * 3 comps per edge)
  edgePositions: Float32Array;
  adjacency: Set<string>[]; // neighbour node-index sets per node
  bounds: number;
  maxDegree: number;
}

const SEED = 0x5eed1234;
const ITERATIONS = 380;
const ALPHA_MIN = 0.001;
// alphaDecay = 1 - pow(alphaMin, 1/iterations) — matches d3-force convention.
const ALPHA_DECAY = 1 - Math.pow(ALPHA_MIN, 1 / ITERATIONS);
const VELOCITY_DECAY = 0.42;
const CHARGE = -240; // forceManyBody strength (repulsion)
const LINK_DISTANCE = 24;
const LINK_STRENGTH = 0.45;
const CENTER_STRENGTH = 0.02;
const CLUSTER_STRENGTH = 0.055; // intra-category cohesion → clearer clusters

function buildLayout(): Layout {
  const rand = mulberry32(SEED);

  const indexById = new Map<string, number>();
  const nodes: GraphNode[] = tools.map((tool, i) => {
    indexById.set(tool.id, i);
    const cat = categoryById.get(tool.category);
    return {
      id: tool.id,
      tool,
      color: new THREE.Color(cat ? cat.color : '#ffffff'),
      degree: 0,
      radius: 1,
      // initial positions on a sphere shell, seeded
      x: (rand() - 0.5) * 120,
      y: (rand() - 0.5) * 120,
      z: (rand() - 0.5) * 120,
      vx: 0,
      vy: 0,
      vz: 0,
    };
  });

  // Build unique edge set from relationIds (undirected, de-duplicated).
  const edgeKey = new Set<string>();
  const edges: GraphEdge[] = [];
  for (const tool of tools) {
    const a = indexById.get(tool.id);
    if (a === undefined) continue;
    for (const rid of tool.relationIds) {
      const b = indexById.get(rid);
      if (b === undefined) continue;
      const key = a < b ? `${a}-${b}` : `${b}-${a}`;
      if (edgeKey.has(key)) continue;
      edgeKey.add(key);
      edges.push({ a, b });
      nodes[a].degree += 1;
      nodes[b].degree += 1;
    }
  }

  let maxDegree = 1;
  for (const node of nodes) maxDegree = Math.max(maxDegree, node.degree);

  // Size by degree (sqrt scaling, like 3d-force-graph nodeVal default).
  for (const n of nodes) {
    n.radius = 1.5 + Math.sqrt(n.degree) * 1.35;
  }
  // Founder OS core is the hub — make it read as central.
  const core = indexById.get('founder-os');
  if (core !== undefined) {
    nodes[core].radius = Math.max(nodes[core].radius, 4.4);
    nodes[core].x = 0;
    nodes[core].y = 0;
    nodes[core].z = 0;
  }

  // Per-category running centroids (recomputed each tick) for cohesion force.
  const catIndex = new Map<string, number>();
  categories.forEach((c, i) => catIndex.set(c.id, i));
  const catCount = categories.length;
  const cx = new Float32Array(catCount);
  const cy = new Float32Array(catCount);
  const cz = new Float32Array(catCount);
  const cn = new Float32Array(catCount);

  // -------------------------------------------------------------------------
  // Force simulation — velocity Verlet integration with alpha annealing.
  // -------------------------------------------------------------------------
  let alpha = 1;
  const n = nodes.length;
  for (let iter = 0; iter < ITERATIONS && alpha > ALPHA_MIN; iter++) {
    alpha += (0 - alpha) * ALPHA_DECAY;

    // Category centroids.
    cx.fill(0);
    cy.fill(0);
    cz.fill(0);
    cn.fill(0);
    for (let i = 0; i < n; i++) {
      const ci = catIndex.get(nodes[i].tool.category);
      if (ci === undefined) continue;
      cx[ci] += nodes[i].x;
      cy[ci] += nodes[i].y;
      cz[ci] += nodes[i].z;
      cn[ci] += 1;
    }
    for (let c = 0; c < catCount; c++) {
      if (cn[c] > 0) {
        cx[c] /= cn[c];
        cy[c] /= cn[c];
        cz[c] /= cn[c];
      }
    }

    // Many-body repulsion (naive O(n^2); n is small — 49 nodes).
    for (let i = 0; i < n; i++) {
      const ni = nodes[i];
      for (let j = i + 1; j < n; j++) {
        const nj = nodes[j];
        let dx = ni.x - nj.x;
        let dy = ni.y - nj.y;
        let dz = ni.z - nj.z;
        let d2 = dx * dx + dy * dy + dz * dz;
        if (d2 < 1e-4) {
          // jitter apart deterministically
          dx = (rand() - 0.5) * 0.5;
          dy = (rand() - 0.5) * 0.5;
          dz = (rand() - 0.5) * 0.5;
          d2 = dx * dx + dy * dy + dz * dz + 1e-4;
        }
        const force = (CHARGE * alpha) / d2;
        const dist = Math.sqrt(d2);
        const fx = (dx / dist) * force;
        const fy = (dy / dist) * force;
        const fz = (dz / dist) * force;
        ni.vx -= fx;
        ni.vy -= fy;
        ni.vz -= fz;
        nj.vx += fx;
        nj.vy += fy;
        nj.vz += fz;
      }
    }

    // Link springs.
    for (const e of edges) {
      const a = nodes[e.a];
      const b = nodes[e.b];
      let dx = b.x - a.x;
      let dy = b.y - a.y;
      let dz = b.z - a.z;
      let dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist < 1e-4) dist = 1e-4;
      const diff = ((dist - LINK_DISTANCE) / dist) * LINK_STRENGTH * alpha;
      dx *= diff;
      dy *= diff;
      dz *= diff;
      a.vx += dx;
      a.vy += dy;
      a.vz += dz;
      b.vx -= dx;
      b.vy -= dy;
      b.vz -= dz;
    }

    // Intra-category cohesion + weak centering + integration.
    for (let i = 0; i < n; i++) {
      const node = nodes[i];
      const ci = catIndex.get(node.tool.category);
      if (ci !== undefined && cn[ci] > 1) {
        node.vx += (cx[ci] - node.x) * CLUSTER_STRENGTH * alpha;
        node.vy += (cy[ci] - node.y) * CLUSTER_STRENGTH * alpha;
        node.vz += (cz[ci] - node.z) * CLUSTER_STRENGTH * alpha;
      }
      node.vx -= node.x * CENTER_STRENGTH * alpha;
      node.vy -= node.y * CENTER_STRENGTH * alpha;
      node.vz -= node.z * CENTER_STRENGTH * alpha;

      node.vx *= 1 - VELOCITY_DECAY;
      node.vy *= 1 - VELOCITY_DECAY;
      node.vz *= 1 - VELOCITY_DECAY;

      node.x += node.vx;
      node.y += node.vy;
      node.z += node.vz;
    }

    // Pin the core to the origin each tick so the hub stays centred.
    if (core !== undefined) {
      nodes[core].x = 0;
      nodes[core].y = 0;
      nodes[core].z = 0;
      nodes[core].vx = 0;
      nodes[core].vy = 0;
      nodes[core].vz = 0;
    }
  }

  // Edge geometry + adjacency.
  const edgePositions = new Float32Array(edges.length * 6);
  edges.forEach((e, i) => {
    const a = nodes[e.a];
    const b = nodes[e.b];
    edgePositions[i * 6 + 0] = a.x;
    edgePositions[i * 6 + 1] = a.y;
    edgePositions[i * 6 + 2] = a.z;
    edgePositions[i * 6 + 3] = b.x;
    edgePositions[i * 6 + 4] = b.y;
    edgePositions[i * 6 + 5] = b.z;
  });

  const adjacency: Set<string>[] = nodes.map(() => new Set<string>());
  for (const e of edges) {
    adjacency[e.a].add(nodes[e.b].id);
    adjacency[e.b].add(nodes[e.a].id);
  }

  let bounds = 1;
  for (const node of nodes) {
    bounds = Math.max(bounds, Math.abs(node.x), Math.abs(node.y), Math.abs(node.z));
  }

  return { nodes, edges, indexById, edgePositions, adjacency, bounds, maxDegree };
}

// ---------------------------------------------------------------------------
// Base edge mesh — crisp, thin vertex-coloured lines. When a node is focused,
// its incident edges are repainted bright and the rest dim (but stay visible),
// so structure reads clearly without additive bloom.
// ---------------------------------------------------------------------------
const EDGE_BASE = new THREE.Color('#21364f');
const EDGE_DIM = new THREE.Color('#16263a');
const EDGE_HOT = new THREE.Color('#9fe8ff');

function Edges({ layout, focusId }: { layout: Layout; focusId: string | null }) {
  const geom = useMemo(() => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(layout.edgePositions, 3));
    const colors = new Float32Array(layout.edges.length * 6);
    // Seed at base colour so the very first frame has no flash.
    for (let i = 0; i < layout.edges.length; i++) {
      colors[i * 6 + 0] = EDGE_BASE.r;
      colors[i * 6 + 1] = EDGE_BASE.g;
      colors[i * 6 + 2] = EDGE_BASE.b;
      colors[i * 6 + 3] = EDGE_BASE.r;
      colors[i * 6 + 4] = EDGE_BASE.g;
      colors[i * 6 + 5] = EDGE_BASE.b;
    }
    g.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    return g;
  }, [layout]);

  const matRef = useRef<THREE.LineBasicMaterial>(null);
  const targetOpacity = useRef(0.6);
  useEffect(() => {
    targetOpacity.current = focusId ? 0.95 : 0.6;
  }, [focusId]);

  // Smoothly ease each edge's vertex colour + the global opacity toward the
  // target every frame — no snapping when focus changes.
  useFrame((_, delta) => {
    const colorAttr = geom.getAttribute('color') as THREE.BufferAttribute;
    const arr = colorAttr.array as Float32Array;
    const k = damp(0.85, delta);
    const edges = layout.edges;
    const nodes = layout.nodes;
    for (let i = 0; i < edges.length; i++) {
      const e = edges[i];
      const touches =
        focusId !== null && (nodes[e.a].id === focusId || nodes[e.b].id === focusId);
      const c = focusId === null ? EDGE_BASE : touches ? EDGE_HOT : EDGE_DIM;
      const o = i * 6;
      arr[o + 0] += (c.r - arr[o + 0]) * k;
      arr[o + 1] += (c.g - arr[o + 1]) * k;
      arr[o + 2] += (c.b - arr[o + 2]) * k;
      arr[o + 3] = arr[o + 0];
      arr[o + 4] = arr[o + 1];
      arr[o + 5] = arr[o + 2];
    }
    colorAttr.needsUpdate = true;
    const mat = matRef.current;
    if (mat) mat.opacity += (targetOpacity.current - mat.opacity) * k;
  });

  return (
    <lineSegments geometry={geom} renderOrder={1}>
      <lineBasicMaterial
        ref={matRef}
        vertexColors
        transparent
        opacity={0.6}
        depthWrite={false}
      />
    </lineSegments>
  );
}

// ---------------------------------------------------------------------------
// A single node sphere. Matte-metal under directional light → depth reads from
// shading, not glow. Hover/active raise scale + a restrained emissive lift.
// ---------------------------------------------------------------------------
function Node({
  node,
  state,
  searchMatch,
  filteredOut,
  geometry,
  onHover,
  onClick,
}: {
  node: GraphNode;
  state: 'active' | 'neighbour' | 'dim' | 'idle';
  // True when this node matches the live search query (and a query exists).
  searchMatch: boolean;
  // True when an active category/stage filter excludes this node.
  filteredOut: boolean;
  geometry: THREE.SphereGeometry;
  onHover: (id: string | null) => void;
  onClick: (id: string) => void;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const matRef = useRef<THREE.MeshStandardMaterial>(null);
  // Scale is expressed relative to the node's intrinsic radius (the shared
  // geometry is a unit sphere), so base = node.radius.
  const targetScale = useRef(node.radius);
  const targetEmissive = useRef(0.22);
  const targetOpacity = useRef(1);

  useEffect(() => {
    // Base targets from selection state.
    let scale = node.radius;
    let emissive = 0.22;
    let opacity = 1;
    if (state === 'active') {
      scale = node.radius * 1.35;
      emissive = 0.9;
    } else if (state === 'neighbour') {
      scale = node.radius * 1.12;
      emissive = 0.55;
    } else if (state === 'dim') {
      scale = node.radius * 0.86;
      emissive = 0.06;
      opacity = 0.32;
    }
    // Search match overrides toward emphasis (calm lift, never garish).
    if (searchMatch) {
      scale = Math.max(scale, node.radius * 1.22);
      emissive = Math.max(emissive, 0.75);
      opacity = 1;
    }
    // Filtered-out nodes recede smoothly behind everything else.
    if (filteredOut) {
      scale = node.radius * 0.82;
      emissive = 0.04;
      opacity = 0.12;
    }
    targetScale.current = scale;
    targetEmissive.current = emissive;
    targetOpacity.current = opacity;
  }, [state, searchMatch, filteredOut, node.radius]);

  useFrame((_, delta) => {
    const k = damp(0.82, delta);
    const m = meshRef.current;
    if (m) {
      const next = m.scale.x + (targetScale.current - m.scale.x) * k;
      m.scale.setScalar(next);
    }
    const mat = matRef.current;
    if (mat) {
      mat.emissiveIntensity += (targetEmissive.current - mat.emissiveIntensity) * k;
      mat.opacity += (targetOpacity.current - mat.opacity) * k;
    }
  });

  return (
    <mesh
      ref={meshRef}
      geometry={geometry}
      position={[node.x, node.y, node.z]}
      scale={node.radius}
      renderOrder={2}
      onPointerOver={(e: ThreeEvent<PointerEvent>) => {
        e.stopPropagation();
        onHover(node.id);
      }}
      onPointerOut={() => onHover(null)}
      onClick={(e: ThreeEvent<MouseEvent>) => {
        e.stopPropagation();
        onClick(node.id);
      }}
    >
      <meshStandardMaterial
        ref={matRef}
        color={node.color}
        emissive={node.color}
        emissiveIntensity={0.22}
        roughness={0.38}
        metalness={0.55}
        transparent
        opacity={1}
      />
    </mesh>
  );
}

// ---------------------------------------------------------------------------
// Thin wireframe focus ring around the active node — a clean "selected"
// affordance that reads as an inspector, not a glow.
// ---------------------------------------------------------------------------
function FocusRing({ node, reduceMotion }: { node: GraphNode; reduceMotion: boolean }) {
  const spinRef = useRef<THREE.Group>(null);
  const scaleRef = useRef<THREE.Group>(null);
  // Ease the ring in from zero each time the focused node changes — no pop.
  useEffect(() => {
    if (scaleRef.current) scaleRef.current.scale.setScalar(0.001);
  }, [node.id]);
  useFrame((_, delta) => {
    if (spinRef.current && !reduceMotion) spinRef.current.rotation.z += delta * 0.6;
    const s = scaleRef.current;
    if (s) {
      const k = damp(0.8, delta);
      const next = s.scale.x + (1 - s.scale.x) * k;
      s.scale.setScalar(next);
    }
  });
  const r = node.radius * 1.9;
  return (
    <Billboard position={[node.x, node.y, node.z]}>
      <group ref={scaleRef}>
        <group ref={spinRef}>
          <mesh>
            <ringGeometry args={[r, r + 0.45, 64]} />
            <meshBasicMaterial
              color="#bde8ff"
              transparent
              opacity={0.85}
              side={THREE.DoubleSide}
              depthWrite={false}
            />
          </mesh>
        </group>
      </group>
    </Billboard>
  );
}

// ---------------------------------------------------------------------------
// Camera fly-to controller — flies CameraControls to a target node and fits.
// ---------------------------------------------------------------------------
function FlyController({
  controls,
  target,
}: {
  controls: React.RefObject<CameraControls | null>;
  target: GraphNode | null;
}) {
  useEffect(() => {
    const c = controls.current;
    if (!c || !target) return;
    const dist = target.radius * 5 + 22;
    c.setLookAt(
      target.x + dist * 0.55,
      target.y + dist * 0.32,
      target.z + dist,
      target.x,
      target.y,
      target.z,
      true,
    );
  }, [controls, target]);
  return null;
}

// ---------------------------------------------------------------------------
// Graph group — slow ambient yaw when idle; pauses on interaction.
// ---------------------------------------------------------------------------
function GraphGroup({
  layout,
  activeId,
  hoverId,
  onHover,
  onClick,
  paused,
  compact,
  reduceMotion,
  matchIds,
  filteredIds,
}: {
  layout: Layout;
  activeId: string | null;
  hoverId: string | null;
  onHover: (id: string | null) => void;
  onClick: (id: string) => void;
  paused: boolean;
  compact: boolean;
  reduceMotion: boolean;
  // Live search matches (empty when no query). Highlighted in the scene.
  matchIds: Set<string>;
  // Nodes excluded by the active category/stage filter (empty when no filter).
  filteredIds: Set<string>;
}) {
  const groupRef = useRef<THREE.Group>(null);

  // One shared unit-sphere geometry for all 49 nodes — per-node radius is
  // applied via mesh scale. Fewer segments on phones to stay light.
  const sphereGeom = useMemo(() => {
    const seg = compact ? 24 : 40;
    return new THREE.SphereGeometry(1, seg, seg);
  }, [compact]);
  useEffect(() => () => sphereGeom.dispose(), [sphereGeom]);

  // Target ambient yaw speed — calmer when reduced motion is requested.
  const yawSpeed = reduceMotion ? 0.012 : 0.035;
  const yawVel = useRef(0);
  useFrame((_, delta) => {
    // Ease the rotation velocity toward 0 (paused) or yawSpeed so starting /
    // stopping the ambient spin never snaps.
    const target = paused ? 0 : yawSpeed;
    yawVel.current += (target - yawVel.current) * damp(0.12, delta);
    if (groupRef.current) groupRef.current.rotation.y += yawVel.current * delta;
  });

  const focus = activeId ?? hoverId;
  const focusNode = useMemo(() => {
    if (!focus) return null;
    const idx = layout.indexById.get(focus);
    return idx === undefined ? null : layout.nodes[idx];
  }, [focus, layout]);
  const neighbours = useMemo(() => {
    if (!focus) return null;
    const idx = layout.indexById.get(focus);
    if (idx === undefined) return null;
    return layout.adjacency[idx];
  }, [focus, layout]);

  return (
    <group ref={groupRef}>
      <Edges layout={layout} focusId={focus} />
      {layout.nodes.map((node) => {
        let state: 'active' | 'neighbour' | 'dim' | 'idle' = 'idle';
        if (focus) {
          if (node.id === focus) state = 'active';
          else if (neighbours && neighbours.has(node.id)) state = 'neighbour';
          else state = 'dim';
        }
        return (
          <Node
            key={node.id}
            node={node}
            state={state}
            searchMatch={matchIds.size > 0 && matchIds.has(node.id)}
            filteredOut={filteredIds.has(node.id)}
            geometry={sphereGeom}
            onHover={onHover}
            onClick={onClick}
          />
        );
      })}

      {focusNode ? <FocusRing node={focusNode} reduceMotion={reduceMotion} /> : null}

      {/* Label for the focused node, billboarded toward the camera. */}
      {focusNode ? (
        <Billboard position={[focusNode.x, focusNode.y + focusNode.radius + 4.5, focusNode.z]}>
          <Text
            fontSize={3.2}
            color="#eaf8ff"
            anchorX="center"
            anchorY="middle"
            outlineWidth={0.16}
            outlineColor="#040810"
            fontWeight="bold"
          >
            {focusNode.tool.name}
          </Text>
        </Billboard>
      ) : null}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Reference grid floor — a faint engineering grid that grounds the graph in
// 3D space and reinforces the "structural inspector" read (not a nebula).
// ---------------------------------------------------------------------------
function ReferenceGrid({ extent, compact }: { extent: number; compact: boolean }) {
  const points = useMemo(() => {
    const lines: [number, number, number][] = [];
    const divisions = compact ? 10 : 16;
    const span = divisions / 2;
    const half = extent;
    const step = (extent * 2) / divisions;
    for (let i = -span; i <= span; i++) {
      const p = i * step;
      lines.push([-half, 0, p], [half, 0, p]);
      lines.push([p, 0, -half], [p, 0, half]);
    }
    return lines;
  }, [extent, compact]);
  return (
    <group position={[0, -extent * 0.78, 0]} renderOrder={0}>
      <Line
        points={points}
        color="#16304a"
        lineWidth={1}
        transparent
        opacity={0.4}
        depthWrite={false}
        segments
      />
    </group>
  );
}

// ---------------------------------------------------------------------------
// Main component.
// ---------------------------------------------------------------------------
// Per-category node counts — computed once at module scope (no Math.random,
// deterministic) so the legend can show how many tools live in each cluster.
const CATEGORY_COUNTS: Record<string, number> = (() => {
  const counts: Record<string, number> = {};
  for (const t of tools) counts[t.category] = (counts[t.category] ?? 0) + 1;
  return counts;
})();

// Stage display order + counts for the workflow filter row.
const STAGE_ORDER: WorkflowStageId[] = [
  'research',
  'planning',
  'execution',
  'approval',
  'review',
];
const STAGE_COUNTS: Record<string, number> = (() => {
  const counts: Record<string, number> = {};
  for (const t of tools) counts[t.stage] = (counts[t.stage] ?? 0) + 1;
  return counts;
})();

export function Force3D() {
  const layout = useMemo(() => buildLayout(), []);
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  // Active category / stage filters. `null` = no filter (all emphasised).
  const [catFilter, setCatFilter] = useState<ToolCategoryId | null>(null);
  const [stageFilter, setStageFilter] = useState<WorkflowStageId | null>(null);
  const controls = useRef<CameraControls | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  // Viewport + motion environment, kept reactive so the scene stays light and
  // calm if the device rotates / a setting changes.
  const [env, setEnv] = useState(readEnv);
  useEffect(() => {
    const onResize = () => setEnv(readEnv());
    window.addEventListener('resize', onResize);
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    mq.addEventListener('change', onResize);
    return () => {
      window.removeEventListener('resize', onResize);
      mq.removeEventListener('change', onResize);
    };
  }, []);
  const { compact, reduceMotion } = env;

  const activeNode = useMemo(() => {
    if (!activeId) return null;
    const idx = layout.indexById.get(activeId);
    return idx === undefined ? null : layout.nodes[idx];
  }, [activeId, layout]);

  const activeTool = activeId ? (toolById.get(activeId) ?? null) : null;
  const activeCat = activeTool ? categoryById.get(activeTool.category) : null;
  const activeStage = activeTool ? workflowStages[activeTool.stage] : null;
  const neighbourTools = useMemo(() => {
    if (!activeId) return [];
    const idx = layout.indexById.get(activeId);
    if (idx === undefined) return [];
    return [...layout.adjacency[idx]]
      .map((id) => toolById.get(id))
      .filter((t): t is AITool => Boolean(t))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [activeId, layout]);

  // -------------------------------------------------------------------------
  // Search — match by name / summary / category. Ordered list of matches so
  // Enter can fly to the first one. Empty query → no matches highlighted.
  // -------------------------------------------------------------------------
  const trimmedQuery = query.trim().toLowerCase();
  const searchMatches = useMemo(() => {
    if (!trimmedQuery) return [] as AITool[];
    return tools
      .filter((t) => {
        const cat = categoryById.get(t.category);
        return (
          t.name.toLowerCase().includes(trimmedQuery) ||
          t.summary.toLowerCase().includes(trimmedQuery) ||
          (cat ? cat.name.toLowerCase().includes(trimmedQuery) : false)
        );
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [trimmedQuery]);

  const matchIds = useMemo(
    () => new Set(searchMatches.map((t) => t.id)),
    [searchMatches],
  );

  // -------------------------------------------------------------------------
  // Filter — nodes excluded by the active category / stage filter recede in
  // the scene. A search match always rescues a node from being filtered out,
  // so search and filter compose rather than fight.
  // -------------------------------------------------------------------------
  const filteredIds = useMemo(() => {
    if (!catFilter && !stageFilter) return new Set<string>();
    const out = new Set<string>();
    for (const t of tools) {
      const failsCat = catFilter !== null && t.category !== catFilter;
      const failsStage = stageFilter !== null && t.stage !== stageFilter;
      if ((failsCat || failsStage) && !matchIds.has(t.id)) out.add(t.id);
    }
    return out;
  }, [catFilter, stageFilter, matchIds]);

  const camDist = layout.bounds * 2.1;
  const resetView = () => {
    setActiveId(null);
    setQuery('');
    setCatFilter(null);
    setStageFilter(null);
    controls.current?.setLookAt(
      camDist * 0.45,
      camDist * 0.32,
      camDist,
      0,
      0,
      0,
      true,
    );
  };

  const focusFirstMatch = () => {
    const first = searchMatches[0];
    if (first) setActiveId(first.id);
  };

  // Keyboard: Enter focuses first match (handled on the input), Esc clears the
  // query / deselects from anywhere on the screen.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (query) setQuery('');
        else if (activeId) setActiveId(null);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [query, activeId]);

  const toggleCat = (id: ToolCategoryId) =>
    setCatFilter((cur) => (cur === id ? null : id));
  const toggleStage = (id: WorkflowStageId) =>
    setStageFilter((cur) => (cur === id ? null : id));

  const hasFilter = catFilter !== null || stageFilter !== null;
  const showHint = !activeTool && !trimmedQuery && !hasFilter;

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#05080f]">
      {/* Cool, near-flat backdrop — legible, not cinematic. */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(130% 100% at 50% 18%, rgba(28,52,82,0.4) 0%, rgba(8,14,26,0.92) 58%, #04070e 100%)',
        }}
      />

      <Canvas
        frameloop="always"
        dpr={[1, 2]}
        camera={{
          position: [camDist * 0.45, camDist * 0.32, camDist],
          fov: 50,
          near: 0.1,
          far: 4000,
        }}
        gl={{ antialias: true, alpha: true }}
        onPointerMissed={() => {
          setActiveId(null);
          setHoverId(null);
        }}
      >
        <color attach="background" args={['#05080f']} />
        <fog attach="fog" args={['#05080f', camDist * 1.5, camDist * 3.6]} />

        {/* Directional key + cool fill → spheres get real volume / depth. */}
        <ambientLight intensity={0.45} />
        <hemisphereLight args={['#cfe6ff', '#0a1422', 0.5]} />
        <directionalLight position={[120, 180, 120]} intensity={2.0} color="#ffffff" />
        <directionalLight position={[-160, -60, -120]} intensity={0.7} color="#5b78ff" />

        <ReferenceGrid extent={layout.bounds * 1.15} compact={compact} />

        <GraphGroup
          layout={layout}
          activeId={activeId}
          hoverId={hoverId}
          onHover={setHoverId}
          onClick={setActiveId}
          paused={Boolean(hoverId || activeId)}
          compact={compact}
          reduceMotion={reduceMotion}
          matchIds={matchIds}
          filteredIds={filteredIds}
        />

        <FlyController controls={controls} target={activeNode} />
        <CameraControls
          ref={controls}
          minDistance={10}
          maxDistance={camDist * 3}
          dollyToCursor
          smoothTime={reduceMotion ? 0.25 : 0.45}
        />
      </Canvas>

      {/* Top chrome clearance + title + search (frosted-glass HUD). */}
      <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between gap-3 px-4 pt-16 sm:px-6">
        <div className="flex min-w-0 flex-col gap-2">
          <div className="rounded-2xl border border-white/10 bg-white/[0.06] px-4 py-3 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl">
            <p className="text-[11px] font-medium uppercase tracking-[0.34em] text-cyan-300/80">
              3D Force Graph
            </p>
            <p className="mt-1 text-xs text-white/55 sm:text-sm">
              Drag to orbit · pinch to zoom · tap a node to fly in
            </p>
          </div>

          {/* Search field — glass, with live match count + clear affordance. */}
          <div className="pointer-events-auto flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.06] px-3.5 py-2.5 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl focus-within:border-cyan-300/40">
            <svg
              viewBox="0 0 24 24"
              className="h-4 w-4 shrink-0 text-white/35"
              fill="none"
              stroke="currentColor"
              strokeWidth={2}
              strokeLinecap="round"
            >
              <circle cx="11" cy="11" r="7" />
              <path d="m21 21-4.3-4.3" />
            </svg>
            <input
              ref={searchRef}
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  focusFirstMatch();
                } else if (e.key === 'Escape') {
                  setQuery('');
                }
              }}
              placeholder="Search tools…"
              aria-label="Search tools"
              className="w-40 bg-transparent text-sm text-white/85 outline-none placeholder:text-white/35 sm:w-52"
            />
            {trimmedQuery ? (
              <button
                type="button"
                onClick={() => {
                  setQuery('');
                  searchRef.current?.focus();
                }}
                aria-label="Clear search"
                className="shrink-0 rounded-full px-1 text-white/40 transition hover:text-white/80 active:scale-90"
              >
                ✕
              </button>
            ) : null}
          </div>

          {/* Live search results — click to fly to a node. */}
          {trimmedQuery ? (
            <div className="pointer-events-auto max-h-[40vh] w-[18rem] overflow-y-auto overscroll-contain rounded-2xl border border-white/10 bg-white/[0.07] p-1.5 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl">
              {searchMatches.length === 0 ? (
                <p className="px-3 py-2 text-xs text-white/45">No tools match “{query.trim()}”.</p>
              ) : (
                searchMatches.map((t) => {
                  const tc = categoryById.get(t.category);
                  return (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setActiveId(t.id)}
                      className={`flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left transition duration-200 hover:bg-white/[0.1] active:scale-[0.98] ${
                        activeId === t.id ? 'bg-white/[0.12]' : ''
                      }`}
                    >
                      <span
                        className="h-2 w-2 shrink-0 rounded-full"
                        style={{ backgroundColor: tc?.color ?? '#fff' }}
                      />
                      <span className="min-w-0 flex-1 truncate text-sm text-white/85">{t.name}</span>
                      <span className="shrink-0 text-[9px] uppercase tracking-[0.18em] text-white/35">
                        {tc?.shortName ?? t.category}
                      </span>
                    </button>
                  );
                })
              )}
            </div>
          ) : null}
        </div>

        <div className="hidden rounded-2xl border border-white/10 bg-white/[0.06] px-4 py-3 text-right font-mono text-[10px] leading-relaxed text-white/45 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl sm:block">
          <div>
            <span className="text-white/70">{layout.nodes.length}</span> nodes ·{' '}
            <span className="text-white/70">{layout.edges.length}</span> edges
          </div>
          <div>force-directed · 3D</div>
        </div>
      </div>

      {/* Category legend — interactive glass card; toggling a category
          emphasises its tools and recedes the rest. Hidden on phones. */}
      <div className="pointer-events-auto absolute left-4 top-1/2 hidden -translate-y-1/2 flex-col gap-1 rounded-2xl border border-white/10 bg-white/[0.06] p-2 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl sm:left-6 md:flex">
        <p className="px-2 pb-1 pt-0.5 text-[9px] uppercase tracking-[0.24em] text-white/35">
          Categories
        </p>
        {categories.map((c) => {
          const on = catFilter === c.id;
          return (
            <button
              key={c.id}
              type="button"
              onClick={() => toggleCat(c.id)}
              aria-pressed={on}
              className={`flex items-center gap-2 rounded-xl px-2 py-1.5 text-left transition duration-300 active:scale-[0.97] ${
                on
                  ? 'bg-white/[0.12]'
                  : catFilter
                    ? 'opacity-45 hover:opacity-80'
                    : 'hover:bg-white/[0.08]'
              }`}
            >
              <span
                className="h-2 w-2 shrink-0 rounded-[2px]"
                style={{
                  backgroundColor: c.color,
                  boxShadow: on ? `0 0 8px ${c.color}` : 'none',
                }}
              />
              <span className="flex-1 text-[10px] uppercase tracking-[0.18em] text-white/55">
                {c.shortName}
              </span>
              <span className="font-mono text-[9px] text-white/35">
                {CATEGORY_COUNTS[c.id] ?? 0}
              </span>
            </button>
          );
        })}
      </div>

      {/* Workflow-stage filter row — glass chips along the bottom edge. */}
      <div className="pointer-events-none absolute inset-x-0 bottom-4 flex flex-wrap justify-center gap-1.5 px-4 sm:bottom-6">
        {STAGE_ORDER.map((sid) => {
          const on = stageFilter === sid;
          return (
            <button
              key={sid}
              type="button"
              onClick={() => toggleStage(sid)}
              aria-pressed={on}
              className={`pointer-events-auto rounded-full border px-3 py-1.5 text-[10px] uppercase tracking-[0.16em] backdrop-blur-xl transition duration-300 active:scale-95 ${
                on
                  ? 'border-cyan-300/50 bg-cyan-300/15 text-cyan-100'
                  : 'border-white/10 bg-white/[0.06] text-white/55 hover:bg-white/[0.1] hover:text-white/80'
              }`}
            >
              {workflowStages[sid].name}
              <span className="ml-1.5 font-mono text-white/35">{STAGE_COUNTS[sid] ?? 0}</span>
            </button>
          );
        })}
      </div>

      {/* Reset / overview affordance — glass button, comfortable tap target. */}
      <button
        type="button"
        onClick={resetView}
        className="pointer-events-auto absolute right-4 top-32 rounded-2xl border border-white/10 bg-white/[0.06] px-4 py-2.5 text-[11px] font-medium tracking-wide text-white/70 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl transition duration-300 hover:border-cyan-300/40 hover:bg-white/[0.1] hover:text-cyan-100 active:scale-95 sm:right-6"
      >
        Overview
      </button>

      {/* Initial hint / empty state — fades out once the user engages. */}
      <div
        className={`pointer-events-none absolute inset-x-0 top-1/2 mx-auto flex max-w-xs -translate-y-1/2 flex-col items-center px-6 text-center transition-opacity duration-700 ${
          showHint ? 'opacity-100' : 'opacity-0'
        }`}
        aria-hidden={!showHint}
      >
        <p className="text-[11px] uppercase tracking-[0.32em] text-cyan-300/70">
          Inspect the universe
        </p>
        <p className="mt-2 text-sm leading-relaxed text-white/55">
          Tap any node to fly in and reveal what it does and what it connects to.
          Search to find a tool, or filter by category and stage.
        </p>
      </div>

      {/* Active node inspector card — liquid glass, eased slide-up, scrollable
          so it never overflows on phone height. Sits above the stage chips. */}
      <div
        className={`pointer-events-none absolute bottom-16 left-4 right-4 mx-auto max-w-md transition-all duration-500 ease-out sm:bottom-20 ${
          activeTool && activeNode
            ? 'translate-y-0 opacity-100'
            : 'pointer-events-none translate-y-6 opacity-0'
        }`}
        aria-hidden={!(activeTool && activeNode)}
      >
        {activeTool && activeNode ? (
          <div className="pointer-events-auto max-h-[58vh] overflow-y-auto overscroll-contain rounded-[1.4rem] border border-white/10 bg-white/[0.08] p-5 shadow-[0_24px_70px_rgba(0,0,0,0.6)] backdrop-blur-2xl">
            <div className="flex items-center justify-between gap-3">
              <div className="flex min-w-0 items-center gap-2">
                <span
                  className="h-2.5 w-2.5 shrink-0 rounded-[3px]"
                  style={{
                    backgroundColor: activeCat?.color ?? '#fff',
                    boxShadow: `0 0 10px ${activeCat?.color ?? '#fff'}`,
                  }}
                />
                <span className="truncate text-[11px] uppercase tracking-[0.28em] text-white/50">
                  {activeCat?.name ?? activeTool.category}
                </span>
              </div>
              <span className="shrink-0 font-mono text-[10px] uppercase tracking-[0.2em] text-cyan-300/75">
                {activeNode.degree} {activeNode.degree === 1 ? 'link' : 'links'}
              </span>
            </div>
            <h3 className="mt-2 text-xl font-semibold text-white">{activeTool.name}</h3>

            {/* Workflow stage badge — where this tool sits in the flow. */}
            {activeStage ? (
              <div className="mt-2 inline-flex items-center gap-1.5 rounded-full border border-cyan-300/25 bg-cyan-300/10 px-2.5 py-1">
                <span className="text-[9px] uppercase tracking-[0.2em] text-cyan-200/70">Stage</span>
                <span className="text-[11px] font-medium text-cyan-100/90">{activeStage.name}</span>
              </div>
            ) : null}

            <p className="mt-2.5 text-sm leading-relaxed text-white/70">{activeTool.summary}</p>

            {neighbourTools.length > 0 ? (
              <div className="mt-3">
                <p className="mb-1.5 text-[10px] uppercase tracking-[0.24em] text-white/40">
                  Connected to ({neighbourTools.length})
                </p>
                <div className="flex flex-wrap gap-1.5">
                  {neighbourTools.map((t) => {
                    const tc = categoryById.get(t.category);
                    return (
                      <button
                        key={t.id}
                        type="button"
                        onClick={() => setActiveId(t.id)}
                        className="flex items-center gap-1.5 rounded-full border border-white/15 bg-white/[0.07] px-3 py-1.5 text-[11px] text-white/75 transition duration-300 hover:border-cyan-300/50 hover:bg-white/[0.12] hover:text-cyan-100 active:scale-95"
                      >
                        <span
                          className="h-1.5 w-1.5 rounded-full"
                          style={{ backgroundColor: tc?.color ?? '#fff' }}
                        />
                        {t.name}
                      </button>
                    );
                  })}
                </div>
              </div>
            ) : null}

            <div className="mt-4 flex items-center gap-2">
              {activeTool.url ? (
                <a
                  href={activeTool.url}
                  target="_blank"
                  rel="noreferrer noopener"
                  className="inline-flex items-center gap-1.5 rounded-full border border-cyan-300/30 bg-cyan-300/10 px-4 py-2 text-[11px] font-medium uppercase tracking-[0.16em] text-cyan-100 transition duration-300 hover:border-cyan-300/60 hover:bg-cyan-300/20 active:scale-95"
                >
                  Open
                  <svg viewBox="0 0 24 24" className="h-3 w-3" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M7 17 17 7M9 7h8v8" />
                  </svg>
                </a>
              ) : null}
              <button
                type="button"
                onClick={() => setActiveId(null)}
                className="rounded-full border border-white/10 bg-white/[0.05] px-4 py-2 text-[11px] uppercase tracking-[0.2em] text-white/45 transition duration-300 hover:bg-white/[0.1] hover:text-white/80 active:scale-95"
              >
                Close
              </button>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
