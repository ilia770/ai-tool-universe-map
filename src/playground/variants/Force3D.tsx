import { useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, type ThreeEvent } from '@react-three/fiber';
import { CameraControls, Billboard, Text } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  toolById,
  categoryById,
  type AITool,
} from '../../data/ai-tool-universe';

/**
 * Direction N — "3D Force Graph".
 *
 * Emulates vasturiano/3d-force-graph: a true 3D force-directed layout
 * (d3-force-3d technique — velocity Verlet integration with a many-body
 * charge force for repulsion, a link spring force for relations, and a
 * weak centering force) rendered with ThreeJS. Nodes are category-coloured
 * spheres sized by degree; relations are 3D line segments. The layout is
 * precomputed deterministically (seeded PRNG, fixed iteration count with
 * alpha decay) so there is no Math.random() at render time and no
 * per-frame allocation in the animation loop.
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
}

const SEED = 0x5eed1234;
const ITERATIONS = 320;
const ALPHA_MIN = 0.001;
// alphaDecay = 1 - pow(alphaMin, 1/iterations) — matches d3-force convention.
const ALPHA_DECAY = 1 - Math.pow(ALPHA_MIN, 1 / ITERATIONS);
const VELOCITY_DECAY = 0.4;
const CHARGE = -260; // forceManyBody strength (repulsion)
const LINK_DISTANCE = 26;
const LINK_STRENGTH = 0.32;
const CENTER_STRENGTH = 0.018;

function buildLayout(): Layout {
  const rand = mulberry32(SEED);

  // Build unique edge set from relationIds (undirected, de-duplicated).
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

  // Size by degree (sqrt scaling, like 3d-force-graph nodeVal default).
  for (const n of nodes) {
    n.radius = 1.6 + Math.sqrt(n.degree) * 1.25;
  }
  // Founder OS core is the hub — make it read as central.
  const core = indexById.get('founder-os');
  if (core !== undefined) {
    nodes[core].radius = Math.max(nodes[core].radius, 4.2);
    nodes[core].x = 0;
    nodes[core].y = 0;
    nodes[core].z = 0;
  }

  // -------------------------------------------------------------------------
  // Force simulation — velocity Verlet integration with alpha annealing.
  // -------------------------------------------------------------------------
  let alpha = 1;
  const n = nodes.length;
  for (let iter = 0; iter < ITERATIONS && alpha > ALPHA_MIN; iter++) {
    alpha += (0 - alpha) * ALPHA_DECAY;

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

    // Weak centering + integration.
    for (let i = 0; i < n; i++) {
      const node = nodes[i];
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

  return { nodes, edges, indexById, edgePositions, adjacency, bounds };
}

// ---------------------------------------------------------------------------
// Edge lines (single LineSegments, vertex-coloured by active/dim state).
// ---------------------------------------------------------------------------
function Edges({
  layout,
  activeId,
}: {
  layout: Layout;
  activeId: string | null;
}) {
  const geom = useMemo(() => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(layout.edgePositions, 3));
    const colors = new Float32Array(layout.edges.length * 6);
    g.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    return g;
  }, [layout]);

  // Precompute base + highlight color triplets per edge endpoint.
  useEffect(() => {
    const colorAttr = geom.getAttribute('color') as THREE.BufferAttribute;
    const arr = colorAttr.array as Float32Array;
    const base = new THREE.Color('#3a5878');
    const hot = new THREE.Color('#bff0ff');
    layout.edges.forEach((e, i) => {
      const na = layout.nodes[e.a];
      const nb = layout.nodes[e.b];
      const touches =
        activeId !== null && (na.id === activeId || nb.id === activeId);
      const ca = touches ? hot : base;
      const cb = touches ? hot : base;
      arr[i * 6 + 0] = ca.r;
      arr[i * 6 + 1] = ca.g;
      arr[i * 6 + 2] = ca.b;
      arr[i * 6 + 3] = cb.r;
      arr[i * 6 + 4] = cb.g;
      arr[i * 6 + 5] = cb.b;
    });
    colorAttr.needsUpdate = true;
  }, [geom, layout, activeId]);

  return (
    <lineSegments geometry={geom}>
      <lineBasicMaterial
        vertexColors
        transparent
        opacity={activeId ? 0.85 : 0.42}
        blending={THREE.AdditiveBlending}
        depthWrite={false}
      />
    </lineSegments>
  );
}

// ---------------------------------------------------------------------------
// A single node sphere with hover/active emissive response.
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
  const targetEmissive = useRef(0.55);

  useEffect(() => {
    if (state === 'active') {
      targetScale.current = 1.5;
      targetEmissive.current = 1.6;
    } else if (state === 'neighbour') {
      targetScale.current = 1.18;
      targetEmissive.current = 1.0;
    } else if (state === 'dim') {
      targetScale.current = 0.82;
      targetEmissive.current = 0.18;
    } else {
      targetScale.current = 1;
      targetEmissive.current = 0.55;
    }
  }, [state]);

  useFrame((_, delta) => {
    const m = meshRef.current;
    if (m) {
      const k = 1 - Math.pow(0.0001, delta);
      const cur = m.scale.x;
      const next = cur + (targetScale.current - cur) * k;
      m.scale.setScalar(next);
    }
    if (matRef.current) {
      const cur = matRef.current.emissiveIntensity;
      const k = 1 - Math.pow(0.0001, delta);
      matRef.current.emissiveIntensity = cur + (targetEmissive.current - cur) * k;
    }
  });

  return (
    <mesh
      ref={meshRef}
      position={[node.x, node.y, node.z]}
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
      <sphereGeometry args={[node.radius, 32, 32]} />
      <meshStandardMaterial
        ref={matRef}
        color={node.color}
        emissive={node.color}
        emissiveIntensity={0.55}
        roughness={0.32}
        metalness={0.1}
        transparent
        opacity={state === 'dim' ? 0.45 : 1}
      />
    </mesh>
  );
}

// ---------------------------------------------------------------------------
// Camera fly-to controller — flies CameraControls to a target node.
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
    if (!c) return;
    if (target) {
      const dist = target.radius * 6 + 18;
      c.setLookAt(
        target.x + dist * 0.6,
        target.y + dist * 0.4,
        target.z + dist,
        target.x,
        target.y,
        target.z,
        true,
      );
    }
  }, [controls, target]);
  return null;
}

// ---------------------------------------------------------------------------
// Slow ambient auto-rotate of the whole graph group when idle.
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
      groupRef.current.rotation.y += delta * 0.04;
    }
  });

  const focus = activeId ?? hoverId;
  const neighbours = useMemo(() => {
    if (!focus) return null;
    const idx = layout.indexById.get(focus);
    if (idx === undefined) return null;
    return layout.adjacency[idx];
  }, [focus, layout]);

  return (
    <group ref={groupRef}>
      <Edges layout={layout} activeId={focus} />
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
            onHover={onHover}
            onClick={onClick}
          />
        );
      })}
      {/* Label for the focused node, billboarded toward the camera. */}
      {focus
        ? layout.nodes
            .filter((node) => node.id === focus)
            .map((node) => (
              <Billboard
                key={`lbl-${node.id}`}
                position={[node.x, node.y + node.radius + 4, node.z]}
              >
                <Text
                  fontSize={3.4}
                  color="#eaffff"
                  anchorX="center"
                  anchorY="middle"
                  outlineWidth={0.18}
                  outlineColor="#06121f"
                >
                  {node.tool.name}
                </Text>
              </Billboard>
            ))
        : null}
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
      .filter((t): t is AITool => Boolean(t));
  }, [activeId, layout]);

  const camDist = layout.bounds * 2.1;

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#04070f]">
      {/* radial sci-fi backdrop */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(120% 90% at 50% 30%, rgba(34,68,110,0.45) 0%, rgba(6,12,24,0.85) 55%, #02040a 100%)',
        }}
      />

      <Canvas
        frameloop="always"
        dpr={[1, 2]}
        camera={{ position: [camDist * 0.4, camDist * 0.3, camDist], fov: 55, near: 0.1, far: 4000 }}
        gl={{ antialias: true, alpha: true }}
        onPointerMissed={() => {
          setActiveId(null);
          setHoverId(null);
        }}
      >
        <color attach="background" args={['#04070f']} />
        <fog attach="fog" args={['#04070f', camDist * 1.4, camDist * 3.4]} />

        <ambientLight intensity={0.35} />
        <directionalLight position={[120, 160, 120]} intensity={1.4} color="#cfe8ff" />
        <directionalLight position={[-140, -80, -120]} intensity={0.6} color="#7a5cff" />
        <pointLight position={[0, 0, 0]} intensity={2.2} distance={camDist * 2} color="#bdeaff" />

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
          minDistance={8}
          maxDistance={camDist * 3}
          dollyToCursor
          smoothTime={0.45}
        />
      </Canvas>

      {/* Top chrome clearance + title */}
      <div className="pointer-events-none absolute inset-x-0 top-0 px-6 pt-16">
        <p className="text-[11px] font-medium uppercase tracking-[0.32em] text-cyan-300/70">
          3D Force Graph
        </p>
        <p className="mt-1 text-sm text-white/45">
          Drag to orbit · scroll to dolly · hover to trace · click to fly in
        </p>
      </div>

      {/* Active node card */}
      {activeTool ? (
        <div className="absolute bottom-6 left-6 right-6 mx-auto max-w-md rounded-2xl border border-white/10 bg-[#070d18]/85 p-5 shadow-[0_20px_60px_rgba(0,0,0,0.55)] backdrop-blur-xl">
          <div className="flex items-center gap-2">
            <span
              className="h-2.5 w-2.5 rounded-full"
              style={{
                backgroundColor: activeCat?.color ?? '#fff',
                boxShadow: `0 0 12px ${activeCat?.color ?? '#fff'}`,
              }}
            />
            <span className="text-[11px] uppercase tracking-[0.28em] text-white/45">
              {activeCat?.name ?? activeTool.category}
            </span>
          </div>
          <h3 className="mt-2 text-xl font-semibold text-white">{activeTool.name}</h3>
          <p className="mt-1.5 text-sm leading-relaxed text-white/65">
            {activeTool.summary}
          </p>
          {neighbourTools.length > 0 ? (
            <div className="mt-3 flex flex-wrap gap-1.5">
              {neighbourTools.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setActiveId(t.id)}
                  className="rounded-full border border-white/12 bg-white/5 px-2.5 py-1 text-[11px] text-white/70 transition hover:border-cyan-300/50 hover:text-cyan-200"
                >
                  {t.name}
                </button>
              ))}
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
