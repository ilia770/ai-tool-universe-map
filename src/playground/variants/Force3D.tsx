import { useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, type ThreeEvent } from '@react-three/fiber';
import { CameraControls, Billboard, Text, Line } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  toolById,
  categoryById,
  type AITool,
} from '../../data/ai-tool-universe';

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
    g.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    return g;
  }, [layout]);

  useEffect(() => {
    const colorAttr = geom.getAttribute('color') as THREE.BufferAttribute;
    const arr = colorAttr.array as Float32Array;
    layout.edges.forEach((e, i) => {
      const na = layout.nodes[e.a];
      const nb = layout.nodes[e.b];
      const touches = focusId !== null && (na.id === focusId || nb.id === focusId);
      const c = focusId === null ? EDGE_BASE : touches ? EDGE_HOT : EDGE_DIM;
      arr[i * 6 + 0] = c.r;
      arr[i * 6 + 1] = c.g;
      arr[i * 6 + 2] = c.b;
      arr[i * 6 + 3] = c.r;
      arr[i * 6 + 4] = c.g;
      arr[i * 6 + 5] = c.b;
    });
    colorAttr.needsUpdate = true;
  }, [geom, layout, focusId]);

  return (
    <lineSegments geometry={geom} renderOrder={1}>
      <lineBasicMaterial
        vertexColors
        transparent
        opacity={focusId ? 0.95 : 0.6}
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
  onHover,
  onClick,
}: {
  node: GraphNode;
  state: 'active' | 'neighbour' | 'dim' | 'idle';
  onHover: (id: string | null) => void;
  onClick: (id: string) => void;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const matRef = useRef<THREE.MeshStandardMaterial>(null);
  const targetScale = useRef(1);
  const targetEmissive = useRef(0.22);
  const targetOpacity = useRef(1);

  useEffect(() => {
    if (state === 'active') {
      targetScale.current = 1.35;
      targetEmissive.current = 0.9;
      targetOpacity.current = 1;
    } else if (state === 'neighbour') {
      targetScale.current = 1.12;
      targetEmissive.current = 0.55;
      targetOpacity.current = 1;
    } else if (state === 'dim') {
      targetScale.current = 0.86;
      targetEmissive.current = 0.06;
      targetOpacity.current = 0.32;
    } else {
      targetScale.current = 1;
      targetEmissive.current = 0.22;
      targetOpacity.current = 1;
    }
  }, [state]);

  useFrame((_, delta) => {
    const k = 1 - Math.pow(0.0006, delta);
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
      position={[node.x, node.y, node.z]}
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
      <sphereGeometry args={[node.radius, 48, 48]} />
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
function FocusRing({ node }: { node: GraphNode }) {
  const ref = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (ref.current) ref.current.rotation.z += delta * 0.6;
  });
  const r = node.radius * 1.9;
  return (
    <Billboard position={[node.x, node.y, node.z]}>
      <group ref={ref}>
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
}: {
  layout: Layout;
  activeId: string | null;
  hoverId: string | null;
  onHover: (id: string | null) => void;
  onClick: (id: string) => void;
  paused: boolean;
}) {
  const groupRef = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (groupRef.current && !paused) {
      groupRef.current.rotation.y += delta * 0.035;
    }
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
          <Node key={node.id} node={node} state={state} onHover={onHover} onClick={onClick} />
        );
      })}

      {focusNode ? <FocusRing node={focusNode} /> : null}

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
function ReferenceGrid({ extent }: { extent: number }) {
  const { points } = useMemo(() => {
    const lines: [number, number, number][] = [];
    const half = extent;
    const step = (extent * 2) / 16;
    for (let i = -8; i <= 8; i++) {
      const p = i * step;
      lines.push([-half, 0, p], [half, 0, p]);
      lines.push([p, 0, -half], [p, 0, half]);
    }
    return { points: lines };
  }, [extent]);
  return (
    <group position={[0, -extent * 0.78, 0]} renderOrder={0}>
      <Line points={points} color="#16304a" lineWidth={1} transparent opacity={0.4} segments />
    </group>
  );
}

// ---------------------------------------------------------------------------
// Main component.
// ---------------------------------------------------------------------------
export function Force3D() {
  const layout = useMemo(() => buildLayout(), []);
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const controls = useRef<CameraControls | null>(null);

  const activeNode = useMemo(() => {
    if (!activeId) return null;
    const idx = layout.indexById.get(activeId);
    return idx === undefined ? null : layout.nodes[idx];
  }, [activeId, layout]);

  const activeTool = activeId ? (toolById.get(activeId) ?? null) : null;
  const activeCat = activeTool ? categoryById.get(activeTool.category) : null;
  const neighbourTools = useMemo(() => {
    if (!activeId) return [];
    const idx = layout.indexById.get(activeId);
    if (idx === undefined) return [];
    return [...layout.adjacency[idx]]
      .map((id) => toolById.get(id))
      .filter((t): t is AITool => Boolean(t))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [activeId, layout]);

  const camDist = layout.bounds * 2.1;
  const resetView = () => {
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

        <ReferenceGrid extent={layout.bounds * 1.15} />

        <GraphGroup
          layout={layout}
          activeId={activeId}
          hoverId={hoverId}
          onHover={setHoverId}
          onClick={setActiveId}
          paused={Boolean(hoverId || activeId)}
        />

        <FlyController controls={controls} target={activeNode} />
        <CameraControls
          ref={controls}
          minDistance={10}
          maxDistance={camDist * 3}
          dollyToCursor
          smoothTime={0.4}
        />
      </Canvas>

      {/* Top chrome clearance + title */}
      <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between px-6 pt-16">
        <div>
          <p className="text-[11px] font-medium uppercase tracking-[0.34em] text-cyan-300/75">
            3D Force Graph
          </p>
          <p className="mt-1 text-sm text-white/45">
            Drag to orbit · scroll to dolly · hover to trace · click to fly in
          </p>
        </div>
        <div className="hidden text-right font-mono text-[10px] leading-relaxed text-white/35 sm:block">
          <div>
            <span className="text-white/55">{layout.nodes.length}</span> nodes ·{' '}
            <span className="text-white/55">{layout.edges.length}</span> edges
          </div>
          <div>force-directed · 3D</div>
        </div>
      </div>

      {/* Category legend — explains node colours, supports the "structural" read. */}
      <div className="pointer-events-none absolute left-6 top-32 hidden flex-col gap-1.5 md:flex">
        {categories.map((c) => (
          <div key={c.id} className="flex items-center gap-2">
            <span
              className="h-2 w-2 rounded-[2px]"
              style={{ backgroundColor: c.color }}
            />
            <span className="text-[10px] uppercase tracking-[0.18em] text-white/40">
              {c.shortName}
            </span>
          </div>
        ))}
      </div>

      {/* Reset-view affordance */}
      <button
        type="button"
        onClick={resetView}
        className="absolute right-6 top-32 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-[11px] font-medium tracking-wide text-white/60 backdrop-blur-md transition hover:border-cyan-300/40 hover:text-cyan-200"
      >
        Reset view
      </button>

      {/* Active node inspector card */}
      {activeTool && activeNode ? (
        <div className="absolute bottom-6 left-6 right-6 mx-auto max-w-md rounded-2xl border border-white/10 bg-[#070d18]/90 p-5 shadow-[0_24px_70px_rgba(0,0,0,0.6)] backdrop-blur-xl">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span
                className="h-2.5 w-2.5 rounded-[3px]"
                style={{
                  backgroundColor: activeCat?.color ?? '#fff',
                  boxShadow: `0 0 10px ${activeCat?.color ?? '#fff'}`,
                }}
              />
              <span className="text-[11px] uppercase tracking-[0.28em] text-white/45">
                {activeCat?.name ?? activeTool.category}
              </span>
            </div>
            <span className="font-mono text-[10px] uppercase tracking-[0.2em] text-cyan-300/70">
              {activeNode.degree} {activeNode.degree === 1 ? 'link' : 'links'}
            </span>
          </div>
          <h3 className="mt-2 text-xl font-semibold text-white">{activeTool.name}</h3>
          <p className="mt-1.5 text-sm leading-relaxed text-white/65">{activeTool.summary}</p>
          {neighbourTools.length > 0 ? (
            <div className="mt-3">
              <p className="mb-1.5 text-[10px] uppercase tracking-[0.24em] text-white/35">
                Connected to
              </p>
              <div className="flex flex-wrap gap-1.5">
                {neighbourTools.map((t) => {
                  const tc = categoryById.get(t.category);
                  return (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setActiveId(t.id)}
                      className="flex items-center gap-1.5 rounded-full border border-white/12 bg-white/5 px-2.5 py-1 text-[11px] text-white/70 transition hover:border-cyan-300/50 hover:text-cyan-100"
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
          <button
            type="button"
            onClick={() => setActiveId(null)}
            className="mt-3 text-[11px] uppercase tracking-[0.2em] text-white/35 transition hover:text-white/70"
          >
            Close
          </button>
        </div>
      ) : null}
    </div>
  );
}
