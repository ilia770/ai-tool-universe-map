import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { CameraControls, Html } from '@react-three/drei';
import * as THREE from 'three';
import {
  categories,
  categoryById,
  workflowStages,
  type AITool,
  type ToolCategory,
  type ToolCategoryId,
} from '../../data/ai-tool-universe';
import { type AddedTool } from '../toolStoreContext';
import { useToolStore } from '../useToolStore';
import { getToolInitials } from '../../lib/tool-logos';
import { useInAppBrowser } from '../../components/useInAppBrowser';

/**
 * Direction A — "AI Brain / Obsidian Graph".
 *
 * A force-directed 2.5D node graph. The layout is derived from the shared
 * reactive tool store (49 seed tools + anything the user adds via the +
 * button) inside a useMemo keyed on `tools`. A persistent id→position ref
 * seeds every recompute, so existing nodes keep their place and a newly
 * added tool eases into its category cluster instead of reshuffling the
 * whole graph.
 *
 * Production layer: glass search, category legend filter, relation-depth
 * highlighting (direct neighbours bright, 2nd-degree dim, rest faint), a
 * full liquid-glass detail panel with clickable connection chips, brand
 * icons (logo.dev / uploaded image, with dot/monogram fallback) rendered
 * only on labelled nodes, and a reset-to-overview control. Built on top of
 * the existing iOS-polished smoothness (frame-rate-independent easing,
 * viewport-tiered budgets, touch, reduced-motion).
 */

// ---------------------------------------------------------------------------
// Geometry / layout types
// ---------------------------------------------------------------------------

interface Node {
  id: string;
  tool: AddedTool;
  color: THREE.Color;
  glow: string;
  /** size weight derived from connectivity */
  size: number;
  /** true for user-added tools — gets a subtle "new" ring + ease-in. */
  isNew: boolean;
  position: THREE.Vector3;
}

interface Edge {
  a: number; // node index
  b: number; // node index
  /** 0 = relation edge, 1 = hub/category edge */
  kind: 0 | 1;
}

interface Graph {
  nodes: Node[];
  edges: Edge[];
  indexById: Map<string, number>;
  adjacency: Map<string, Set<string>>;
  radius: number;
}

const DEG = Math.PI / 180;
const HUB_ID = 'founder-os';

// Deterministic, index-based jitter so the layout is reproducible.
function jitter(i: number, salt: number): number {
  const v = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return v - Math.floor(v) - 0.5; // [-0.5, 0.5)
}

// Second-degree neighbours of a node (direct neighbours excluded).
function secondDegree(graph: Graph, id: string): Set<string> {
  const direct = graph.adjacency.get(id);
  const out = new Set<string>();
  if (!direct) return out;
  for (const nId of direct) {
    const nn = graph.adjacency.get(nId);
    if (!nn) continue;
    for (const mId of nn) {
      if (mId !== id && !direct.has(mId)) out.add(mId);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Force-directed layout — derived from the reactive store, position-stable
// ---------------------------------------------------------------------------

/**
 * Build the graph from the current tool list. `prevPos` carries node
 * positions across recomputes (by id): existing nodes resume where they
 * were so the relaxation barely nudges them, while genuinely new ids are
 * seeded near their category cluster and then settle in. On return the
 * map is updated with the final positions for the next recompute.
 */
function buildGraph(
  tools: AddedTool[],
  toolById: Map<string, AddedTool>,
  prevPos: Map<string, THREE.Vector3>,
): Graph {
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

  // Connect every tool to the Founder OS hub so the graph stays connected.
  if (toolById.has(HUB_ID)) {
    for (const tool of tools) {
      if (tool.id !== HUB_ID) pushEdge(tool.id, HUB_ID, 1);
    }
  }

  // Count of brand-new (no prior position) nodes — drives whether we run the
  // full cold relax or just a light warm settle on top of stable positions.
  let freshCount = 0;
  for (const tool of tools) if (!prevPos.has(tool.id)) freshCount += 1;
  const isInitial = prevPos.size === 0;

  // Seed positions: resume from prevPos where known, otherwise from category
  // angle on a 2.5D plane (mostly XY, small Z).
  const nodes: Node[] = tools.map((tool, i) => {
    const cat = categoryById.get(tool.category);
    const isHub = tool.id === HUB_ID;
    const prior = prevPos.get(tool.id);
    let position: THREE.Vector3;
    if (prior) {
      position = prior.clone();
    } else {
      const baseAngle = (cat?.angle ?? tool.angle) * DEG;
      const ring = isHub ? 0 : 14 + tool.orbit * 6 + (jitter(i, 1) + 0.5) * 6;
      const ang = baseAngle + jitter(i, 2) * 0.5;
      const x = Math.cos(ang) * ring + jitter(i, 3) * 4;
      const y = Math.sin(ang) * ring * 0.78 + jitter(i, 4) * 4;
      const z = jitter(i, 5) * 6;
      position = new THREE.Vector3(x, y, z);
    }
    const deg = degree.get(tool.id) ?? 1;
    const color = new THREE.Color(cat?.color ?? '#9bd6ff');
    return {
      id: tool.id,
      tool,
      color,
      glow: cat?.glow ?? 'rgba(155,214,255,0.3)',
      size: isHub ? 2.6 : 0.85 + Math.min(deg, 8) * 0.16,
      isNew: Boolean(tool.userAdded),
      position,
    };
  });

  // Only relax when needed: a full pass on first build, and a short warm pass
  // when a tool was added (so the newcomer settles into its cluster without
  // jarring the rest). No new ids → no work, positions are already final.
  if (isInitial) relax(nodes, edges, indexById, 110);
  else if (freshCount > 0) relax(nodes, edges, indexById, 36);

  // Re-centre on the hub (or origin) and measure radius.
  const centre = new THREE.Vector3();
  const hubIdx = indexById.get(HUB_ID);
  if (hubIdx !== undefined) centre.copy(nodes[hubIdx].position);
  let radius = 1;
  for (const n of nodes) {
    n.position.sub(centre);
    radius = Math.max(radius, n.position.length());
  }

  // Persist final positions for the next recompute (smooth incremental adds).
  prevPos.clear();
  for (const n of nodes) prevPos.set(n.id, n.position.clone());

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
  iterations: number,
): void {
  const n = nodes.length;
  const disp = nodes.map(() => new THREE.Vector3());
  const REPULSION = 380; // pairwise push strength
  const SPRING = 0.045; // edge pull
  const REST = 13; // ideal edge length
  const Z_DAMP = 0.82; // keep things mostly planar (2.5D)
  const hubIdx = indexById.get(HUB_ID);
  const tmp = new THREE.Vector3();

  for (let it = 0; it < iterations; it++) {
    const cooling = 1 - it / iterations;
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
// Environment helpers (mobile / reduced-motion) — read once, no per-frame work
// ---------------------------------------------------------------------------

function readIsSmall(): boolean {
  if (typeof window === 'undefined') return false;
  return window.innerWidth < 768;
}

function readReducedMotion(): boolean {
  if (typeof window === 'undefined' || !window.matchMedia) return false;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

// ---------------------------------------------------------------------------
// Shared GPU resources
// ---------------------------------------------------------------------------

// Lower-poly spheres on phones keep the draw light without a visible drop.
const SPHERE_SEGMENTS = readIsSmall() ? 16 : 22;
const HALO_SEGMENTS = readIsSmall() ? 12 : 18;
const SPHERE_GEOM = new THREE.SphereGeometry(1, SPHERE_SEGMENTS, SPHERE_SEGMENTS);
const HALO_GEOM = new THREE.SphereGeometry(1, HALO_SEGMENTS, HALO_SEGMENTS);

// ---------------------------------------------------------------------------
// Edge lines (one merged LineSegments per kind)
// ---------------------------------------------------------------------------

function useEdgeGeometry(graph: Graph, kind: 0 | 1) {
  return useMemo(() => {
    let segs = graph.edges.filter((e) => e.kind === kind);
    // Bound relation-edge count on phones: keep the strongest (shortest) links
    // so the graph stays legible and light instead of a dense haze.
    if (kind === 0 && readIsSmall() && segs.length > 90) {
      segs = [...segs]
        .sort(
          (p, q) =>
            graph.nodes[p.a].position.distanceToSquared(graph.nodes[p.b].position) -
            graph.nodes[q.a].position.distanceToSquared(graph.nodes[q.b].position),
        )
        .slice(0, 90);
    }
    const positions = new Float32Array(segs.length * 6);
    const colors = new Float32Array(segs.length * 6);
    const tmp = new THREE.Color();
    segs.forEach((e, i) => {
      const a = graph.nodes[e.a];
      const b = graph.nodes[e.b];
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
  }, [graph, kind]);
}

interface EdgesProps {
  graph: Graph;
  kind: 0 | 1;
  selectedId: string | null;
  reducedMotion: boolean;
}

function Edges({ graph, kind, selectedId, reducedMotion }: EdgesProps) {
  const { geom, segs } = useEdgeGeometry(graph, kind);
  const matRef = useRef<THREE.LineBasicMaterial>(null);

  // Whether this edge group has any edge incident to the current selection.
  // Computed only on selection change (not per frame), no allocations in loop.
  const incidentToSelection = useMemo(() => {
    if (!selectedId) return true;
    for (const e of segs) {
      if (graph.nodes[e.a].id === selectedId || graph.nodes[e.b].id === selectedId) {
        return true;
      }
    }
    return false;
  }, [graph, segs, selectedId]);

  useFrame(({ clock }) => {
    const mat = matRef.current;
    if (!mat) return;
    // Pulsing baseline so links feel alive (held calm under reduced motion).
    const pulse = reducedMotion
      ? 0.5
      : 0.5 + 0.5 * Math.sin(clock.elapsedTime * 1.3);
    const base = kind === 1 ? 0.16 : 0.34;
    const swing = kind === 1 ? 0.05 : 0.1;
    // When a selection exists and this group isn't incident, ease toward dim.
    const dim = selectedId && !incidentToSelection ? 0.18 : 1;
    const target = (base + pulse * swing) * dim;
    mat.opacity += (target - mat.opacity) * 0.12;
  });

  return (
    <lineSegments geometry={geom} renderOrder={-1}>
      <lineBasicMaterial
        ref={matRef}
        vertexColors
        transparent
        opacity={kind === 1 ? 0.18 : 0.36}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </lineSegments>
  );
}

// ---------------------------------------------------------------------------
// Node sphere + halo
// ---------------------------------------------------------------------------

/**
 * Relation-depth + filter state collapsed into a single visual tier:
 *   selected  — the focused node
 *   neighbour — direct (1st-degree) connection of the selection
 *   far       — 2nd-degree connection (dimmer)
 *   dimmed    — unrelated to the selection, or filtered/search-out
 *   match     — a search/filter highlight when nothing is selected
 *   normal    — resting state
 */
type NodeState =
  | 'normal'
  | 'selected'
  | 'neighbour'
  | 'far'
  | 'dimmed'
  | 'match';

interface NodeMeshProps {
  node: Node;
  state: NodeState;
  hovered: boolean;
  showLabel: boolean;
  iconUrl: string | undefined;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}

/**
 * Round-cropped brand icon badge, centred exactly on the node. Mounted only
 * when the node already shows a label (selected / hovered / near / in-focus),
 * so we never mount 49+ DOM nodes at once. Falls back to a coloured dot /
 * monogram when no icon URL is available or the image fails to load.
 */
function NodeBadge({ node, iconUrl }: { node: Node; iconUrl: string | undefined }) {
  const [failed, setFailed] = useState(false);
  const showImg = Boolean(iconUrl) && !failed;
  const ring = node.color.getStyle();
  const diameter = 30;

  return (
    <Html
      center
      transform
      sprite
      distanceFactor={20}
      position={[0, 0, 0]}
      zIndexRange={[30, 0]}
      style={{ pointerEvents: 'none' }}
    >
      <div
        style={{
          width: diameter,
          height: diameter,
          borderRadius: '50%',
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'rgba(8,12,26,0.72)',
          border: `1.5px solid ${ring}`,
          boxShadow: `0 0 10px ${node.glow}`,
        }}
      >
        {showImg ? (
          <img
            src={iconUrl}
            alt=""
            width={diameter}
            height={diameter}
            decoding="async"
            onError={() => setFailed(true)}
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        ) : (
          <span
            style={{
              fontSize: 11,
              fontWeight: 700,
              letterSpacing: 0.2,
              color: '#eaf6ff',
              lineHeight: 1,
            }}
          >
            {getToolInitials(node.tool.name)}
          </span>
        )}
      </div>
    </Html>
  );
}

function NodeMesh({
  node,
  state,
  hovered,
  showLabel,
  iconUrl,
  onSelect,
  onHover,
}: NodeMeshProps) {
  const coreRef = useRef<THREE.Mesh>(null);
  const haloRef = useRef<THREE.Mesh>(null);
  const ringRef = useRef<THREE.Mesh>(null);
  const groupRef = useRef<THREE.Group>(null);
  // Ease-in for freshly added nodes (scale 0 → 1 on first frames).
  const grow = useRef(node.isNew ? 0 : 1);

  const targets = useMemo(() => {
    const base = node.size;
    const emissive =
      state === 'selected'
        ? 1.5
        : state === 'match'
          ? 1.2
          : state === 'neighbour'
            ? 0.9
            : state === 'far'
              ? 0.45
              : state === 'dimmed'
                ? 0.1
                : 0.45;
    const scale =
      (state === 'selected'
        ? 1.35
        : state === 'match'
          ? 1.22
          : state === 'dimmed'
            ? 0.78
            : state === 'far'
              ? 0.92
              : 1) * (hovered ? 1.18 : 1);
    const haloOpacity =
      state === 'selected'
        ? 0.5
        : state === 'match'
          ? 0.42
          : hovered
            ? 0.4
            : state === 'neighbour'
              ? 0.22
              : state === 'far'
                ? 0.1
                : state === 'dimmed'
                  ? 0.03
                  : 0.16;
    const coreOpacity = state === 'dimmed' ? 0.16 : state === 'far' ? 0.6 : 0.95;
    return { base, emissive, scale, haloOpacity, coreOpacity };
  }, [hovered, node.size, state]);

  useFrame((_, delta) => {
    const core = coreRef.current;
    const halo = haloRef.current;
    if (!core || !halo) return;
    // Ease the spawn growth toward 1 (frame-rate independent).
    if (grow.current < 1) {
      grow.current = Math.min(1, grow.current + (1 - grow.current) * (1 - Math.exp(-6 * delta)) + delta * 0.6);
    }
    const g = grow.current;
    // Frame-rate independent easing: same spring feel at 60 / 120 Hz.
    const k = 1 - Math.exp(-9 * delta);
    const hk = 1 - Math.exp(-7 * delta);
    const mat = core.material as THREE.MeshStandardMaterial;
    mat.emissiveIntensity += (targets.emissive - mat.emissiveIntensity) * k;
    mat.opacity += (targets.coreOpacity - mat.opacity) * k;
    const s = targets.base * targets.scale * g;
    core.scale.x += (s - core.scale.x) * k;
    core.scale.y = core.scale.z = core.scale.x;
    const hmat = halo.material as THREE.MeshBasicMaterial;
    hmat.opacity += (targets.haloOpacity - hmat.opacity) * hk;
    const hs = node.size * 2.4 * (targets.scale * 0.6 + 0.6) * g;
    halo.scale.x += (hs - halo.scale.x) * hk;
    halo.scale.y = halo.scale.z = halo.scale.x;
    // Subtle pulsing "new" ring for user-added nodes.
    const ring = ringRef.current;
    if (ring) {
      const rmat = ring.material as THREE.MeshBasicMaterial;
      const t = 0.45 + 0.35 * Math.sin(performance.now() * 0.004);
      rmat.opacity += (t * g - rmat.opacity) * hk;
      const rs = node.size * (targets.scale * 1.7 + 0.4) * g;
      ring.scale.x += (rs - ring.scale.x) * hk;
      ring.scale.y = ring.scale.z = ring.scale.x;
    }
  });

  return (
    <group ref={groupRef} position={node.position}>
      <mesh
        ref={coreRef}
        geometry={SPHERE_GEOM}
        scale={node.isNew ? 0.001 : node.size}
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
      {node.isNew && (
        <mesh ref={ringRef} geometry={HALO_GEOM} scale={node.size * 1.7}>
          <meshBasicMaterial
            color="#eaf6ff"
            wireframe
            transparent
            opacity={0}
            depthWrite={false}
            blending={THREE.AdditiveBlending}
          />
        </mesh>
      )}
      {showLabel && (
        <>
          <NodeBadge node={node} iconUrl={iconUrl} />
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
                padding: '3px 10px',
                borderRadius: 999,
                fontSize: 12,
                fontWeight: 600,
                letterSpacing: 0.2,
                color: '#eaf6ff',
                background: 'rgba(8,12,26,0.55)',
                border: `1px solid ${node.color.getStyle()}55`,
                boxShadow: `0 4px 18px rgba(0,0,0,0.35), 0 0 14px ${node.glow}`,
                backdropFilter: 'blur(10px)',
                WebkitBackdropFilter: 'blur(10px)',
              }}
            >
              {node.tool.name}
            </span>
          </Html>
        </>
      )}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

interface SceneProps {
  graph: Graph;
  selectedId: string | null;
  hoveredId: string | null;
  matchIds: Set<string> | null;
  mutedCats: Set<ToolCategoryId>;
  reducedMotion: boolean;
  focusToken: number;
  iconUrlFor: (tool: AITool) => string | undefined;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}

function Scene({
  graph,
  selectedId,
  hoveredId,
  matchIds,
  mutedCats,
  reducedMotion,
  focusToken,
  iconUrlFor,
  onSelect,
  onHover,
}: SceneProps) {
  const controlsRef = useRef<CameraControls>(null);
  const { invalidate } = useThree();
  const idleRef = useRef(0);

  const neighbours = useMemo(() => {
    if (!selectedId) return null;
    return graph.adjacency.get(selectedId) ?? new Set<string>();
  }, [graph, selectedId]);

  const secondDeg = useMemo(() => {
    if (!selectedId) return null;
    return secondDegree(graph, selectedId);
  }, [graph, selectedId]);

  // Animate the camera to centre the selected node.
  const focusNode = useCallback(
    (id: string) => {
      const idx = graph.indexById.get(id);
      const controls = controlsRef.current;
      if (idx === undefined || !controls) return;
      const p = graph.nodes[idx].position;
      const dist = id === HUB_ID ? graph.radius * 1.7 : 26;
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
    [graph, invalidate],
  );

  // Pull the camera back to an overview of the whole graph.
  const resetView = useCallback(() => {
    const controls = controlsRef.current;
    if (!controls) return;
    const d = graph.radius * 2.4;
    void controls.setLookAt(10, 8, d, 0, 0, 0, true);
    invalidate();
  }, [graph, invalidate]);

  const handleSelect = useCallback(
    (id: string) => {
      onSelect(id);
      focusNode(id);
    },
    [focusNode, onSelect],
  );

  // React to external focus requests (search Enter / chip clicks / reset).
  // focusToken increments to retrigger; selectedId null → overview.
  const lastToken = useRef(focusToken);
  useEffect(() => {
    if (focusToken === lastToken.current) return;
    lastToken.current = focusToken;
    if (selectedId) focusNode(selectedId);
    else resetView();
  }, [focusToken, selectedId, focusNode, resetView]);

  // Gentle idle drift of the whole graph when nothing is selected.
  const rootRef = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    const root = rootRef.current;
    if (!root) return;
    // Frame-rate independent return-to-neutral.
    const settle = 1 - Math.exp(-5 * delta);
    if (!selectedId && !reducedMotion) {
      idleRef.current += delta * 0.06;
      const targetY = Math.sin(idleRef.current) * 0.18;
      const targetX = Math.cos(idleRef.current * 0.7) * 0.05;
      root.rotation.y += (targetY - root.rotation.y) * settle;
      root.rotation.x += (targetX - root.rotation.x) * settle;
    } else {
      // ease rotation back to neutral (also the reduced-motion resting state)
      root.rotation.y += (0 - root.rotation.y) * settle;
      root.rotation.x += (0 - root.rotation.x) * settle;
    }
  });

  return (
    <>
      <color attach="background" args={['#03040a']} />
      <fog attach="fog" args={['#03040a', graph.radius * 1.6, graph.radius * 4]} />
      <ambientLight intensity={0.55} />
      <pointLight position={[0, 0, 40]} intensity={1.2} color="#bfe6ff" />
      <pointLight position={[-40, 30, -20]} intensity={0.5} color="#ff8bd2" />

      <CameraControls
        ref={controlsRef}
        makeDefault
        minDistance={12}
        maxDistance={graph.radius * 4}
        dollySpeed={0.5}
        truckSpeed={0}
        smoothTime={reducedMotion ? 0.3 : 0.55}
        draggingSmoothTime={0.18}
      />

      <group ref={rootRef}>
        <Edges graph={graph} kind={1} selectedId={selectedId} reducedMotion={reducedMotion} />
        <Edges graph={graph} kind={0} selectedId={selectedId} reducedMotion={reducedMotion} />

        {graph.nodes.map((node) => {
          const muted = mutedCats.size > 0 && mutedCats.has(node.tool.category);
          let nodeState: NodeState = 'normal';
          if (selectedId) {
            if (node.id === selectedId) nodeState = 'selected';
            else if (neighbours?.has(node.id)) nodeState = 'neighbour';
            else if (secondDeg?.has(node.id)) nodeState = 'far';
            else nodeState = 'dimmed';
            // A category filter further recedes muted nodes even within the
            // selection's neighbourhood.
            if (muted && nodeState !== 'selected') nodeState = 'dimmed';
          } else if (matchIds) {
            nodeState = matchIds.has(node.id) ? 'match' : 'dimmed';
          } else if (muted) {
            nodeState = 'dimmed';
          }

          const hovered = hoveredId === node.id;
          const showLabel =
            nodeState === 'selected' ||
            nodeState === 'neighbour' ||
            nodeState === 'match' ||
            hovered ||
            (node.id === HUB_ID && !selectedId && !matchIds);
          return (
            <NodeMesh
              key={node.id}
              node={node}
              state={nodeState}
              hovered={hovered}
              showLabel={showLabel}
              iconUrl={showLabel ? iconUrlFor(node.tool) : undefined}
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
// Glass UI primitives
// ---------------------------------------------------------------------------

const GLASS =
  'rounded-2xl border border-white/10 bg-white/[0.06] shadow-[0_8px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl';

interface CategoryLegendProps {
  counts: Map<ToolCategoryId, number>;
  mutedCats: Set<ToolCategoryId>;
  onToggle: (id: ToolCategoryId) => void;
  onSolo: (id: ToolCategoryId) => void;
}

function CategoryLegend({ counts, mutedCats, onToggle, onSolo }: CategoryLegendProps) {
  const anyMuted = mutedCats.size > 0;
  return (
    <div className={`pointer-events-auto ${GLASS} p-2.5`}>
      <div className="flex items-center justify-between gap-3 px-1 pb-1.5">
        <p className="text-[10px] font-semibold uppercase tracking-[0.24em] text-white/55">
          Categories
        </p>
        {anyMuted && (
          <button
            type="button"
            onClick={() => onSolo('__all__' as ToolCategoryId)}
            className="text-[10px] font-medium text-cyan-200/80 transition-colors hover:text-cyan-100"
          >
            Show all
          </button>
        )}
      </div>
      <div className="flex flex-col gap-0.5">
        {categories.map((cat: ToolCategory) => {
          const muted = mutedCats.has(cat.id);
          const count = counts.get(cat.id) ?? 0;
          return (
            <button
              key={cat.id}
              type="button"
              onClick={() => onToggle(cat.id)}
              onDoubleClick={() => onSolo(cat.id)}
              title={`${cat.name} — ${cat.description}\nClick to toggle • double-click to solo`}
              className="group flex items-center gap-2.5 rounded-xl px-2 py-1.5 text-left transition-colors duration-200 hover:bg-white/[0.07]"
              style={{ minHeight: 34, opacity: muted ? 0.4 : 1 }}
            >
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-full transition-all duration-300"
                style={{
                  background: cat.color,
                  boxShadow: muted ? 'none' : `0 0 10px ${cat.glow}`,
                }}
              />
              <span className="flex-1 text-[12px] font-medium text-white/80">
                {cat.shortName}
              </span>
              <span className="text-[10px] tabular-nums text-white/40">
                {count}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Public component
// ---------------------------------------------------------------------------

export function BrainGraph() {
  const { openInApp } = useInAppBrowser();
  const { tools, toolById, iconUrlFor } = useToolStore();

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [reducedMotion, setReducedMotion] = useState(readReducedMotion);
  const [query, setQuery] = useState('');
  const [mutedCats, setMutedCats] = useState<Set<ToolCategoryId>>(new Set());
  const [focusToken, setFocusToken] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const graph = useMemo(
    () => buildGraph(tools, toolById, new Map()),
    [tools, toolById],
  );

  // Category counts derived from the reactive tool list.
  const categoryCounts = useMemo(() => {
    const m = new Map<ToolCategoryId, number>();
    for (const t of tools) m.set(t.category, (m.get(t.category) ?? 0) + 1);
    return m;
  }, [tools]);

  // Search matches (only when query is non-empty and nothing is selected).
  const trimmed = query.trim().toLowerCase();
  const matchIds = useMemo(() => {
    if (!trimmed) return null;
    const ids = new Set<string>();
    for (const t of tools) {
      const cat = categoryById.get(t.category);
      if (
        t.name.toLowerCase().includes(trimmed) ||
        t.summary.toLowerCase().includes(trimmed) ||
        (cat?.name.toLowerCase().includes(trimmed) ?? false)
      ) {
        ids.add(t.id);
      }
    }
    return ids;
  }, [tools, trimmed]);

  const firstMatch = useMemo(() => {
    if (!matchIds || matchIds.size === 0) return null;
    for (const t of tools) if (matchIds.has(t.id)) return t.id;
    return null;
  }, [tools, matchIds]);

  // Focus / fly-to helper used by search, chips, and reset.
  const focusOn = useCallback((id: string | null) => {
    setSelectedId(id);
    setFocusToken((t) => t + 1);
  }, []);

  // Remember the last selected id so the detail card keeps its content while
  // it eases out after deselect.
  const [lastId, setLastId] = useState<string | null>(null);
  useEffect(() => {
    if (selectedId) {
      const id = window.setTimeout(() => setLastId(selectedId), 0);
      return () => window.clearTimeout(id);
    }
    return undefined;
  }, [selectedId]);
  const cardId = selectedId ?? lastId;

  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = () => setReducedMotion(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const cardTool = cardId ? toolById.get(cardId) : undefined;
  const cardCategory = cardTool
    ? categoryById.get(cardTool.category)
    : undefined;
  const cardStage = cardTool ? workflowStages[cardTool.stage] : undefined;

  // Connections of the selected tool that actually exist in the dataset.
  const cardRelations = useMemo(() => {
    if (!cardTool) return [];
    const seen = new Set<string>();
    const out: AITool[] = [];
    for (const id of cardTool.relationIds) {
      if (seen.has(id)) continue;
      const t = toolById.get(id);
      if (t) {
        seen.add(id);
        out.push(t);
      }
    }
    return out;
  }, [cardTool, toolById]);

  const clearSelection = useCallback(() => setSelectedId(null), []);

  const handleSelect = useCallback((id: string) => {
    setSelectedId(id);
    // Camera focus is driven inside the Scene's handleSelect; no token needed.
  }, []);

  const toggleCat = useCallback((id: ToolCategoryId) => {
    setMutedCats((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  // Solo: isolate one category (mute every other). '__all__' clears the filter.
  const soloCat = useCallback((id: ToolCategoryId) => {
    if ((id as string) === '__all__') {
      setMutedCats(new Set());
      return;
    }
    setMutedCats(() => {
      const next = new Set<ToolCategoryId>();
      for (const c of categories) if (c.id !== id) next.add(c.id);
      return next;
    });
  }, []);

  // Keyboard: Enter focuses first match, Esc clears selection / search.
  const onSearchKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter' && firstMatch) {
        e.preventDefault();
        setQuery('');
        focusOn(firstMatch);
        inputRef.current?.blur();
      } else if (e.key === 'Escape') {
        e.preventDefault();
        if (query) setQuery('');
        else focusOn(null);
        inputRef.current?.blur();
      }
    },
    [firstMatch, focusOn, query],
  );

  // Global Esc to deselect even when not in the input.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      const el = document.activeElement;
      if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA')) return;
      if (selectedId) focusOn(null);
      else if (mutedCats.size > 0) setMutedCats(new Set());
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [selectedId, mutedCats, focusOn]);

  const showReset = selectedId !== null || mutedCats.size > 0 || trimmed !== '';

  return (
    <div className="absolute inset-0 h-full w-full">
      <Canvas
        className="h-full w-full"
        style={{ width: '100%', height: '100%' }}
        camera={{ position: [10, 8, graph.radius * 2.4], fov: 52, near: 0.1, far: 2000 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: false }}
        frameloop="always"
        onPointerMissed={clearSelection}
      >
        <Scene
          graph={graph}
          selectedId={selectedId}
          hoveredId={hoveredId}
          matchIds={selectedId ? null : matchIds}
          mutedCats={mutedCats}
          reducedMotion={reducedMotion}
          focusToken={focusToken}
          iconUrlFor={iconUrlFor}
          onSelect={handleSelect}
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

      {/* Top-left cluster: title + search + legend (clears lab chrome ~64px) */}
      <div className="pointer-events-none absolute left-4 top-32 z-10 flex w-[15.5rem] max-w-[calc(100%-2rem)] flex-col gap-2.5 sm:left-5">
        {/* Title / hint pill */}
        <div className={`pointer-events-none ${GLASS} px-3.5 py-2.5`}>
          <p className="text-[11px] font-medium uppercase tracking-[0.28em] text-cyan-200/80">
            AI Brain
          </p>
          <p className="mt-1 text-[11px] leading-relaxed text-white/45">
            {selectedId
              ? 'Showing this tool and its connections — tap empty space to release'
              : trimmed
                ? `${matchIds?.size ?? 0} match${(matchIds?.size ?? 0) === 1 ? '' : 'es'} • Enter to focus`
                : `Search, filter, or tap a node to explore all ${tools.length} tools`}
          </p>
        </div>

        {/* Search field */}
        <div className={`pointer-events-auto ${GLASS} flex items-center gap-2 px-3 py-2`}>
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
            className="shrink-0 text-white/40"
            aria-hidden="true"
          >
            <circle cx="11" cy="11" r="7" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={onSearchKeyDown}
            placeholder="Search tools…"
            aria-label="Search AI tools"
            spellCheck={false}
            autoComplete="off"
            className="w-full bg-transparent text-[13px] text-white/90 placeholder:text-white/35 focus:outline-none"
          />
          {query && (
            <button
              type="button"
              onClick={() => {
                setQuery('');
                inputRef.current?.focus();
              }}
              aria-label="Clear search"
              className="shrink-0 rounded-md px-1 text-white/40 transition-colors hover:text-white/80"
            >
              ✕
            </button>
          )}
        </div>

        {/* Category legend (hidden while a search is active to reduce clutter) */}
        {!trimmed && (
          <CategoryLegend
            counts={categoryCounts}
            mutedCats={mutedCats}
            onToggle={toggleCat}
            onSolo={soloCat}
          />
        )}
      </div>

      {/* Reset / overview control (top-right) */}
      <div className="pointer-events-none absolute right-4 top-16 z-10 sm:right-5">
        <button
          type="button"
          onClick={() => {
            setQuery('');
            setMutedCats(new Set());
            focusOn(null);
          }}
          aria-label="Reset to overview"
          className={`pointer-events-auto ${GLASS} flex items-center gap-1.5 px-3 py-2 text-[11px] font-medium text-white/75 transition-all duration-300 hover:bg-white/[0.12] active:scale-[0.97]`}
          style={{
            minHeight: 36,
            opacity: showReset ? 1 : 0,
            transform: showReset ? 'translateY(0)' : 'translateY(-6px)',
            pointerEvents: showReset ? 'auto' : 'none',
          }}
        >
          <svg
            width="13"
            height="13"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <path d="M3 12a9 9 0 1 0 3-6.7" />
            <path d="M3 4v4h4" />
          </svg>
          Overview
        </button>
      </div>

      {/* Selected-tool detail card — liquid glass, eased show/hide */}
      <div
        className="pointer-events-none absolute bottom-4 left-4 right-4 z-10 flex justify-start sm:right-auto sm:bottom-5 sm:left-5"
        aria-hidden={!selectedId}
      >
        {cardTool && (
          <div
            className="w-full max-w-[23rem] origin-bottom-left rounded-2xl border border-white/10 bg-white/[0.07] p-4 shadow-[0_12px_40px_rgba(0,0,0,0.45)] backdrop-blur-2xl transition-all duration-300 ease-out"
            style={{
              opacity: selectedId ? 1 : 0,
              transform: selectedId
                ? 'translateY(0) scale(1)'
                : 'translateY(10px) scale(0.97)',
              pointerEvents: selectedId ? 'auto' : 'none',
              boxShadow: `0 12px 40px rgba(0,0,0,0.45), 0 0 26px ${cardCategory?.glow ?? 'rgba(155,214,255,0.25)'}`,
            }}
          >
            {/* Category + workflow stage row */}
            <div className="flex items-center gap-2">
              <span
                className="inline-flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-[0.2em]"
                style={{ color: cardCategory?.color ?? '#9bd6ff' }}
              >
                <span
                  className="h-2 w-2 rounded-full"
                  style={{
                    background: cardCategory?.color ?? '#9bd6ff',
                    boxShadow: `0 0 8px ${cardCategory?.glow ?? 'rgba(155,214,255,0.4)'}`,
                  }}
                />
                {cardCategory?.shortName ?? cardTool.category}
              </span>
              {cardStage && (
                <span className="rounded-full border border-white/10 bg-white/[0.05] px-2 py-0.5 text-[9px] font-medium uppercase tracking-[0.14em] text-white/55">
                  {cardStage.name}
                </span>
              )}
            </div>

            <p className="mt-2 text-base font-semibold leading-snug text-white">
              {cardTool.name}
            </p>
            <p className="mt-1.5 text-xs leading-relaxed text-white/65">
              {cardTool.summary}
            </p>

            {/* Connections — clickable chips that fly to that tool */}
            {cardRelations.length > 0 && (
              <div className="mt-3">
                <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-white/40">
                  Connected to
                </p>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  {cardRelations.map((rel) => {
                    const relCat = categoryById.get(rel.category);
                    return (
                      <button
                        key={rel.id}
                        type="button"
                        onClick={() => focusOn(rel.id)}
                        className="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-white/[0.05] px-2.5 py-1 text-[11px] font-medium text-white/80 transition-all duration-200 hover:bg-white/[0.12] active:scale-[0.96]"
                        style={{ minHeight: 28 }}
                      >
                        <span
                          className="h-1.5 w-1.5 rounded-full"
                          style={{ background: relCat?.color ?? '#9bd6ff' }}
                        />
                        {rel.name}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {cardTool.url && (
              <button
                type="button"
                onClick={() => openInApp(cardTool.url!, cardTool.name)}
                className="mt-3 inline-flex items-center rounded-xl border border-white/10 bg-white/[0.06] px-3 py-1.5 text-[11px] font-medium text-white/80 transition-colors duration-200 hover:bg-white/[0.12] active:bg-white/[0.16]"
                style={{ minHeight: 36 }}
              >
                Open tool →
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
