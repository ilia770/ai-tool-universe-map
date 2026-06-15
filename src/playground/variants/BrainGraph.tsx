import { useCallback, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { CameraControls, Html } from '@react-three/drei';
import * as THREE from 'three';
import {
  categoryById,
  tools,
  toolById,
  type AITool,
} from '../../data/ai-tool-universe';

/**
 * Direction A — "AI Brain / Obsidian Graph".
 *
 * A force-directed 2.5D node graph. Layout is precomputed once at module
 * load with a small spring/repulsion relaxation (deterministic, no random
 * seeds), so every frame is cheap and stable.
 */

// ---------------------------------------------------------------------------
// Geometry / layout types
// ---------------------------------------------------------------------------

interface Node {
  id: string;
  tool: AITool;
  color: THREE.Color;
  glow: string;
  /** size weight derived from connectivity */
  size: number;
  position: THREE.Vector3;
}

interface Edge {
  a: number; // node index
  b: number; // node index
  /** 0 = relation edge, 1 = hub/category edge */
  kind: 0 | 1;
}

const DEG = Math.PI / 180;

// Deterministic, index-based jitter so the layout is reproducible.
function jitter(i: number, salt: number): number {
  const v = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return v - Math.floor(v) - 0.5; // [-0.5, 0.5)
}

// ---------------------------------------------------------------------------
// Precomputed force-directed layout (module-level, runs once)
// ---------------------------------------------------------------------------

interface Graph {
  nodes: Node[];
  edges: Edge[];
  indexById: Map<string, number>;
  adjacency: Map<string, Set<string>>;
  radius: number;
}

const GRAPH: Graph = buildGraph();

function buildGraph(): Graph {
  const indexById = new Map<string, number>();
  tools.forEach((tool, i) => indexById.set(tool.id, i));

  // Connectivity degree → node size weighting.
  const degree = new Map<string, number>();
  const bump = (id: string) => degree.set(id, (degree.get(id) ?? 0) + 1);

  const edgeKeys = new Set<string>();
  const edges: Edge[] = [];
  const pushEdge = (aId: string, bId: string, kind: 0 | 1) => {
    const a = indexById.get(aId);
    const b = indexById.get(bId);
    if (a === undefined || b === undefined || a === b) return;
    const key = a < b ? `${a}:${b}` : `${b}:${a}`;
    if (edgeKeys.has(key)) return;
    edgeKeys.add(key);
    edges.push({ a, b, kind });
    bump(aId);
    bump(bId);
  };

  // Relation edges (only when both endpoints exist).
  for (const tool of tools) {
    for (const relId of tool.relationIds) {
      if (toolById.has(relId)) pushEdge(tool.id, relId, 0);
    }
  }

  // Connect every tool to its category hub so the graph is fully connected.
  // The category hub is represented by the tool whose category === 'core'
  // (Founder OS) for the core group, and for the others we wire each tool to
  // Founder OS as the universal centre, plus to one representative per
  // category to give clustering. We use Founder OS (founder-os) as the
  // single hub the prompt calls out.
  const hubId = 'founder-os';
  if (toolById.has(hubId)) {
    for (const tool of tools) {
      if (tool.id !== hubId) pushEdge(tool.id, hubId, 1);
    }
  }

  // Seed positions from category angle on a 2.5D plane (mostly XY, small Z).
  const nodes: Node[] = tools.map((tool, i) => {
    const cat = categoryById.get(tool.category);
    const baseAngle = (cat?.angle ?? tool.angle) * DEG;
    const isHub = tool.id === hubId;
    // hub sits near the centre; others fan out by category, pushed by orbit.
    const ring = isHub ? 0 : 14 + tool.orbit * 6 + (jitter(i, 1) + 0.5) * 6;
    const ang = baseAngle + jitter(i, 2) * 0.5;
    const x = Math.cos(ang) * ring + jitter(i, 3) * 4;
    const y = Math.sin(ang) * ring * 0.78 + jitter(i, 4) * 4;
    const z = jitter(i, 5) * 6; // small depth jitter for 2.5D feel
    const deg = degree.get(tool.id) ?? 1;
    const color = new THREE.Color(cat?.color ?? '#9bd6ff');
    return {
      id: tool.id,
      tool,
      color,
      glow: cat?.glow ?? 'rgba(155,214,255,0.3)',
      size: isHub ? 2.6 : 0.85 + Math.min(deg, 8) * 0.16,
      position: new THREE.Vector3(x, y, z),
    };
  });

  relax(nodes, edges, indexById, hubId);

  // Re-centre on the hub (or centroid) and measure radius.
  const centre = new THREE.Vector3();
  const hubIdx = indexById.get(hubId);
  if (hubIdx !== undefined) centre.copy(nodes[hubIdx].position);
  let radius = 1;
  for (const n of nodes) {
    n.position.sub(centre);
    radius = Math.max(radius, n.position.length());
  }

  // Adjacency for neighbour highlighting.
  const adjacency = new Map<string, Set<string>>();
  for (const n of nodes) adjacency.set(n.id, new Set());
  for (const e of edges) {
    adjacency.get(nodes[e.a].id)?.add(nodes[e.b].id);
    adjacency.get(nodes[e.b].id)?.add(nodes[e.a].id);
  }

  return { nodes, edges, indexById, adjacency, radius };
}

// Simple deterministic spring (attraction along edges) + repulsion relaxation.
function relax(
  nodes: Node[],
  edges: Edge[],
  indexById: Map<string, number>,
  hubId: string,
): void {
  const n = nodes.length;
  const disp = nodes.map(() => new THREE.Vector3());
  const ITER = 110;
  const REPULSION = 380; // pairwise push strength
  const SPRING = 0.045; // edge pull
  const REST = 13; // ideal edge length
  const Z_DAMP = 0.82; // keep things mostly planar (2.5D)
  const hubIdx = indexById.get(hubId);
  const tmp = new THREE.Vector3();

  for (let it = 0; it < ITER; it++) {
    const cooling = 1 - it / ITER;
    for (let i = 0; i < n; i++) disp[i].set(0, 0, 0);

    // Repulsion between all node pairs.
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        tmp.copy(nodes[i].position).sub(nodes[j].position);
        let d2 = tmp.lengthSq();
        if (d2 < 0.01) {
          // separate coincident nodes deterministically
          tmp.set(jitter(i + j, 7), jitter(i + j, 8), 0).multiplyScalar(0.5);
          d2 = 0.25;
        }
        const force = REPULSION / d2;
        tmp.multiplyScalar(force / Math.sqrt(d2));
        disp[i].add(tmp);
        disp[j].sub(tmp);
      }
    }

    // Spring attraction along edges.
    for (const e of edges) {
      tmp.copy(nodes[e.a].position).sub(nodes[e.b].position);
      const len = tmp.length() || 0.001;
      const k = e.kind === 1 ? SPRING * 0.6 : SPRING;
      const f = (len - REST) * k;
      tmp.multiplyScalar(f / len);
      disp[e.a].sub(tmp);
      disp[e.b].add(tmp);
    }

    // Apply, with cooling and a mild planar bias.
    for (let i = 0; i < n; i++) {
      if (i === hubIdx) continue; // pin the hub at the centre
      disp[i].z *= Z_DAMP;
      const max = 6 * cooling + 0.5;
      if (disp[i].length() > max) disp[i].setLength(max);
      nodes[i].position.add(disp[i]);
      // gentle gravity toward origin keeps the graph compact
      nodes[i].position.multiplyScalar(0.998);
    }
  }
}

// ---------------------------------------------------------------------------
// Shared GPU resources
// ---------------------------------------------------------------------------

const SPHERE_GEOM = new THREE.SphereGeometry(1, 22, 22);
const HALO_GEOM = new THREE.SphereGeometry(1, 18, 18);

// ---------------------------------------------------------------------------
// Edge lines (one merged LineSegments per kind)
// ---------------------------------------------------------------------------

function useEdgeGeometry(kind: 0 | 1) {
  return useMemo(() => {
    const segs = GRAPH.edges.filter((e) => e.kind === kind);
    const positions = new Float32Array(segs.length * 6);
    const colors = new Float32Array(segs.length * 6);
    const tmp = new THREE.Color();
    segs.forEach((e, i) => {
      const a = GRAPH.nodes[e.a];
      const b = GRAPH.nodes[e.b];
      positions.set([a.position.x, a.position.y, a.position.z], i * 6);
      positions.set([b.position.x, b.position.y, b.position.z], i * 6 + 3);
      tmp.copy(a.color).lerp(b.color, 0.5);
      colors.set([tmp.r, tmp.g, tmp.b], i * 6);
      colors.set([tmp.r, tmp.g, tmp.b], i * 6 + 3);
    });
    const geom = new THREE.BufferGeometry();
    geom.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geom.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    return { geom, segs };
  }, [kind]);
}

interface EdgesProps {
  kind: 0 | 1;
  selectedId: string | null;
}

function Edges({ kind, selectedId }: EdgesProps) {
  const { geom, segs } = useEdgeGeometry(kind);
  const matRef = useRef<THREE.LineBasicMaterial>(null);

  // When a node is selected, fade non-incident edges. Recompute the per-vertex
  // alpha only on selection change (not per frame).
  const opacityForSelection = useMemo(() => {
    if (!selectedId) return null;
    return segs.map((e) => {
      const incident =
        GRAPH.nodes[e.a].id === selectedId || GRAPH.nodes[e.b].id === selectedId;
      return incident ? 1 : 0.12;
    });
  }, [segs, selectedId]);

  useFrame(({ clock }) => {
    if (!matRef.current) return;
    // Pulsing baseline so links feel alive.
    const pulse = 0.5 + 0.5 * Math.sin(clock.elapsedTime * 1.3);
    const base = kind === 1 ? 0.16 : 0.34;
    matRef.current.opacity = base + pulse * (kind === 1 ? 0.05 : 0.1);
  });

  // Dim whole material when a selection exists and this group isn't strongly
  // incident. Cheap approximation: if any incident edge, keep bright.
  const groupDim =
    opacityForSelection && !opacityForSelection.some((o) => o === 1) ? 0.18 : 1;

  return (
    <lineSegments geometry={geom} renderOrder={-1}>
      <lineBasicMaterial
        ref={matRef}
        vertexColors
        transparent
        opacity={kind === 1 ? 0.18 : 0.36 * groupDim}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </lineSegments>
  );
}

// ---------------------------------------------------------------------------
// Node sphere + halo
// ---------------------------------------------------------------------------

interface NodeMeshProps {
  node: Node;
  state: 'normal' | 'selected' | 'neighbour' | 'dimmed';
  hovered: boolean;
  showLabel: boolean;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}

function NodeMesh({
  node,
  state,
  hovered,
  showLabel,
  onSelect,
  onHover,
}: NodeMeshProps) {
  const coreRef = useRef<THREE.Mesh>(null);
  const haloRef = useRef<THREE.Mesh>(null);
  const groupRef = useRef<THREE.Group>(null);

  const targets = useMemo(() => {
    const base = node.size;
    const emissive =
      state === 'selected'
        ? 1.5
        : state === 'neighbour'
          ? 0.9
          : state === 'dimmed'
            ? 0.12
            : 0.45;
    const scale =
      (state === 'selected' ? 1.35 : state === 'dimmed' ? 0.8 : 1) *
      (hovered ? 1.18 : 1);
    const haloOpacity =
      state === 'selected'
        ? 0.5
        : hovered
          ? 0.4
          : state === 'neighbour'
            ? 0.22
            : state === 'dimmed'
              ? 0.04
              : 0.16;
    const coreOpacity = state === 'dimmed' ? 0.18 : 0.95;
    return { base, emissive, scale, haloOpacity, coreOpacity };
  }, [hovered, node.size, state]);

  useFrame(() => {
    const core = coreRef.current;
    const halo = haloRef.current;
    if (!core || !halo) return;
    const mat = core.material as THREE.MeshStandardMaterial;
    mat.emissiveIntensity += (targets.emissive - mat.emissiveIntensity) * 0.12;
    mat.opacity += (targets.coreOpacity - mat.opacity) * 0.12;
    const s = targets.base * targets.scale;
    core.scale.x += (s - core.scale.x) * 0.14;
    core.scale.y = core.scale.z = core.scale.x;
    const hmat = halo.material as THREE.MeshBasicMaterial;
    hmat.opacity += (targets.haloOpacity - hmat.opacity) * 0.1;
    const hs = node.size * 2.4 * (targets.scale * 0.6 + 0.6);
    halo.scale.x += (hs - halo.scale.x) * 0.1;
    halo.scale.y = halo.scale.z = halo.scale.x;
  });

  return (
    <group ref={groupRef} position={node.position}>
      <mesh
        ref={coreRef}
        geometry={SPHERE_GEOM}
        scale={node.size}
        onClick={(e) => {
          e.stopPropagation();
          onSelect(node.id);
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          onHover(node.id);
        }}
        onPointerOut={(e) => {
          e.stopPropagation();
          onHover(null);
        }}
      >
        <meshStandardMaterial
          color={node.color}
          emissive={node.color}
          emissiveIntensity={0.45}
          roughness={0.35}
          metalness={0.1}
          transparent
          opacity={0.95}
        />
      </mesh>
      <mesh ref={haloRef} geometry={HALO_GEOM} scale={node.size * 2.4}>
        <meshBasicMaterial
          color={node.color}
          transparent
          opacity={0.16}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      {showLabel && (
        <Html
          center
          distanceFactor={28}
          position={[0, node.size * 1.5 + 1.2, 0]}
          zIndexRange={[40, 0]}
          style={{ pointerEvents: 'none' }}
        >
          <span
            style={{
              display: 'inline-block',
              whiteSpace: 'nowrap',
              padding: '2px 9px',
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 600,
              letterSpacing: 0.2,
              color: '#eaf6ff',
              background: 'rgba(8,12,26,0.66)',
              border: `1px solid ${node.color.getStyle()}66`,
              boxShadow: `0 0 14px ${node.glow}`,
              backdropFilter: 'blur(4px)',
            }}
          >
            {node.tool.name}
          </span>
        </Html>
      )}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

interface SceneProps {
  selectedId: string | null;
  hoveredId: string | null;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}

function Scene({ selectedId, hoveredId, onSelect, onHover }: SceneProps) {
  const controlsRef = useRef<CameraControls>(null);
  const { invalidate } = useThree();
  const idleRef = useRef(0);

  const neighbours = useMemo(() => {
    if (!selectedId) return null;
    return GRAPH.adjacency.get(selectedId) ?? new Set<string>();
  }, [selectedId]);

  // Animate the camera to centre the selected node.
  const focusNode = useCallback(
    (id: string) => {
      const idx = GRAPH.indexById.get(id);
      const controls = controlsRef.current;
      if (idx === undefined || !controls) return;
      const p = GRAPH.nodes[idx].position;
      const dist = id === 'founder-os' ? GRAPH.radius * 1.7 : 26;
      void controls.setLookAt(
        p.x + dist * 0.3,
        p.y + dist * 0.18,
        p.z + dist,
        p.x,
        p.y,
        p.z,
        true,
      );
      invalidate();
    },
    [invalidate],
  );

  const handleSelect = useCallback(
    (id: string) => {
      onSelect(id);
      focusNode(id);
    },
    [focusNode, onSelect],
  );

  // Gentle idle drift of the whole graph when nothing is selected.
  const rootRef = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (!rootRef.current) return;
    if (!selectedId) {
      idleRef.current += delta * 0.06;
      rootRef.current.rotation.y = Math.sin(idleRef.current) * 0.18;
      rootRef.current.rotation.x = Math.cos(idleRef.current * 0.7) * 0.05;
    } else {
      // ease rotation back to neutral
      rootRef.current.rotation.y *= 0.96;
      rootRef.current.rotation.x *= 0.96;
    }
  });

  return (
    <>
      <color attach="background" args={['#03040a']} />
      <fog attach="fog" args={['#03040a', GRAPH.radius * 1.6, GRAPH.radius * 4]} />
      <ambientLight intensity={0.55} />
      <pointLight position={[0, 0, 40]} intensity={1.2} color="#bfe6ff" />
      <pointLight position={[-40, 30, -20]} intensity={0.5} color="#ff8bd2" />

      <CameraControls
        ref={controlsRef}
        makeDefault
        minDistance={12}
        maxDistance={GRAPH.radius * 4}
        dollySpeed={0.5}
        smoothTime={0.4}
      />

      <group ref={rootRef}>
        <Edges kind={1} selectedId={selectedId} />
        <Edges kind={0} selectedId={selectedId} />

        {GRAPH.nodes.map((node) => {
          let nodeState: NodeMeshProps['state'] = 'normal';
          if (selectedId) {
            if (node.id === selectedId) nodeState = 'selected';
            else if (neighbours?.has(node.id)) nodeState = 'neighbour';
            else nodeState = 'dimmed';
          }
          const hovered = hoveredId === node.id;
          const showLabel =
            nodeState === 'selected' ||
            nodeState === 'neighbour' ||
            hovered ||
            node.id === 'founder-os';
          return (
            <NodeMesh
              key={node.id}
              node={node}
              state={nodeState}
              hovered={hovered}
              showLabel={showLabel}
              onSelect={handleSelect}
              onHover={onHover}
            />
          );
        })}
      </group>
    </>
  );
}

// ---------------------------------------------------------------------------
// Public component
// ---------------------------------------------------------------------------

export function BrainGraph() {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const selectedTool = selectedId ? toolById.get(selectedId) : undefined;
  const selectedCategory = selectedTool
    ? categoryById.get(selectedTool.category)
    : undefined;

  const clearSelection = useCallback(() => setSelectedId(null), []);

  return (
    <div className="absolute inset-0 h-full w-full">
      <Canvas
        className="h-full w-full"
        style={{ width: '100%', height: '100%' }}
        camera={{ position: [10, 8, GRAPH.radius * 2.4], fov: 52, near: 0.1, far: 2000 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: false }}
        frameloop="always"
        onPointerMissed={clearSelection}
      >
        <Scene
          selectedId={selectedId}
          hoveredId={hoveredId}
          onSelect={setSelectedId}
          onHover={setHoveredId}
        />
      </Canvas>

      {/* Radial vignette overlay */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(circle at 50% 45%, transparent 40%, rgba(2,3,9,0.55) 80%, rgba(2,3,9,0.9) 100%)',
        }}
      />

      {/* Title / hint */}
      <div className="pointer-events-none absolute left-5 top-5 select-none">
        <p className="text-[11px] font-medium uppercase tracking-[0.28em] text-cyan-200/70">
          AI Brain
        </p>
        <p className="mt-1 text-[11px] text-white/35">
          {selectedId ? 'Click empty space to release focus' : 'Click a node to focus its neighbourhood'}
        </p>
      </div>

      {/* Selected-tool detail card */}
      {selectedTool && (
        <div
          className="pointer-events-none absolute bottom-5 left-5 max-w-xs rounded-2xl border p-4 backdrop-blur"
          style={{
            borderColor: `${selectedCategory?.color ?? '#9bd6ff'}55`,
            background: 'rgba(6,9,20,0.7)',
            boxShadow: `0 0 30px ${selectedCategory?.glow ?? 'rgba(155,214,255,0.3)'}`,
          }}
        >
          <p
            className="text-[10px] font-semibold uppercase tracking-[0.22em]"
            style={{ color: selectedCategory?.color ?? '#9bd6ff' }}
          >
            {selectedCategory?.shortName ?? selectedTool.category}
          </p>
          <p className="mt-1 text-base font-semibold text-white">
            {selectedTool.name}
          </p>
          <p className="mt-1.5 text-xs leading-relaxed text-white/60">
            {selectedTool.summary}
          </p>
        </div>
      )}
    </div>
  );
}
