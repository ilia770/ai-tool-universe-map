import {
  useMemo,
  useRef,
  useState,
  useCallback,
  useEffect,
  type KeyboardEvent as ReactKeyboardEvent,
} from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Billboard, Text } from '@react-three/drei';
import * as THREE from 'three';
import {
  categories,
  categoryById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';
import { type AddedTool } from '../toolStoreContext';
import { useToolStore } from '../useToolStore';
import { useInAppBrowser } from '../../components/useInAppBrowser';

/* ------------------------------------------------------------------ *
 * Neural Universe — Direction O (HERO showpiece)
 *
 * The brief: this must feel like flying *inside* a gigantic living AI
 * brain — lush, volumetric, cinematic — and must read as obviously
 * different from N's clean force graph.
 *
 * What makes it distinct & premium here:
 *  - Multi-layer living neuron bodies: glass shell + bright emissive
 *    core + radial dendrite spikes + double additive halo, with varied
 *    organic sizes (the 49 tools are bright hero neurons; hundreds of
 *    dimmer ambient neurons form the surrounding tissue).
 *  - Pulses physically travelling along every synapse (instanced GPU
 *    sparks), accelerating + brightening inside a focused sub-world.
 *  - Volumetric depth: heavy bloom, depth-of-field, fog falloff,
 *    chromatic-aberration lens feel, slow majestic eased camera drift.
 *  - TheBrain navigation: click a hero neuron → camera *flies in* and
 *    that neuron becomes the centre of its own sub-world; its connected
 *    tools bloom + pulse, everything else recedes/dims. Exit via empty
 *    space, the Back button, or Esc.
 * ------------------------------------------------------------------ */

/* --- seeded PRNG (no Math.random in render / module init) --------- */
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

/* --- viewport / motion budget (read once, mobile-aware) ----------- */
// Small screens get fewer ambient neurons + haze and fewer pulses so the
// scene stays buttery on a phone. Read defensively for SSR safety.
const VIEWPORT_W =
  typeof window !== 'undefined' ? window.innerWidth : 1280;
const IS_SMALL = VIEWPORT_W < 768;
const PREFERS_REDUCED_MOTION =
  typeof window !== 'undefined' &&
  typeof window.matchMedia === 'function' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// scale ambient density down hard on phones
const CLUSTER_CORE_COUNT = IS_SMALL ? 28 : 60;
const CLUSTER_OTHER_COUNT = IS_SMALL ? 18 : 40;
const HAZE_COUNT = IS_SMALL ? 140 : 340;
const PULSES_PER_EDGE = IS_SMALL ? 1 : 2;

/* --- types -------------------------------------------------------- */
interface HeroNode {
  tool: AddedTool;
  category: ToolCategory;
  pos: THREE.Vector3;
  color: THREE.Color;
  size: number;
  phase: number;
}

interface AmbientNode {
  pos: THREE.Vector3;
  color: THREE.Color;
  scale: number;
  phase: number;
}

interface Edge {
  a: string;
  b: string;
}

// helper so TS narrows the category id union without an `any`
function asCatId(id: string): AITool['category'] {
  return id as AITool['category'];
}

const HERO_ID = 'founder-os';

/* --- layout (precomputed once at module scope) -------------------- */
// One cluster centre per category, arranged on a tilted, depth-varied
// ring so the brain has front/back lobes rather than a flat disc.
const clusterCenters = new Map<string, THREE.Vector3>();
categories.forEach((cat, i) => {
  const t = (i / categories.length) * Math.PI * 2;
  const r = 32;
  clusterCenters.set(
    cat.id,
    new THREE.Vector3(
      Math.cos(t) * r,
      Math.sin(t * 2) * 9 + Math.cos(t * 3) * 4,
      Math.sin(t) * r,
    ),
  );
});
// the core lobe sits dead-centre so the hero owns the middle
clusterCenters.set('core', new THREE.Vector3(0, 0, 0));

// Deterministic per-tool RNG seed so a node's size / phase stay stable
// regardless of how many other tools exist around it (important so that
// adding a tool never reshuffles the appearance of existing nodes).
function seedForTool(tool: AITool): number {
  let h = 0x5eed01;
  const id = tool.id;
  for (let i = 0; i < id.length; i++) h = (Math.imul(h, 31) + id.charCodeAt(i)) | 0;
  return h >>> 0;
}

/* --- reactive graph derivation -----------------------------------
 * Built from the store's reactive tool list. `prevPos` lets us reuse a
 * node's previous world position by id so adding a tool never reflows
 * the existing constellation — only brand-new ids get a fresh slot. */
interface Graph {
  heroNodes: HeroNode[];
  heroById: Map<string, HeroNode>;
  heroPosById: Map<string, THREE.Vector3>;
  edges: Edge[];
  adjacency: Map<string, Set<string>>;
  edgesByNode: Map<string, number[]>;
}

function buildGraph(
  toolList: readonly AddedTool[],
  prevPos: Map<string, THREE.Vector3>,
): Graph {
  const byCat = new Map<string, AddedTool[]>();
  for (const tool of toolList) {
    const list = byCat.get(tool.category) ?? [];
    list.push(tool);
    byCat.set(tool.category, list);
  }

  const heroNodes: HeroNode[] = [];
  for (const [catId, list] of byCat) {
    const center = clusterCenters.get(catId) ?? new THREE.Vector3();
    const category = categoryById.get(asCatId(catId)) ?? categories[0];
    const golden = Math.PI * (3 - Math.sqrt(5));
    list.forEach((tool, idx) => {
      const isHero = tool.id === HERO_ID;
      // per-tool deterministic RNG keeps size/phase stable across rebuilds
      const rand = mulberry32(seedForTool(tool));
      let pos = prevPos.get(tool.id);
      if (!pos) {
        const y = list.length === 1 ? 0 : 1 - (idx / (list.length - 1)) * 2;
        const radius = Math.sqrt(Math.max(0, 1 - y * y));
        const theta = golden * idx;
        const jitter = 0.6 + rand() * 0.5;
        const spread = catId === 'core' ? 3 : 10 * jitter;
        pos = isHero
          ? new THREE.Vector3(0, 0, 0)
          : new THREE.Vector3(
              center.x + Math.cos(theta) * radius * spread,
              center.y + y * spread * 0.7 + (rand() - 0.5) * 3.5,
              center.z + Math.sin(theta) * radius * spread,
            );
      }
      // organic size variety; relation-rich nodes read as bigger hubs
      const hubBonus = Math.min(tool.relationIds.length, 6) * 0.06;
      const size = isHero ? 2.4 : 0.9 + rand() * 0.5 + hubBonus;
      heroNodes.push({
        tool,
        category,
        pos,
        color: new THREE.Color(category.color),
        size,
        phase: rand() * Math.PI * 2,
      });
    });
  }

  const heroById = new Map<string, HeroNode>(heroNodes.map((n) => [n.tool.id, n]));
  const heroPosById = new Map<string, THREE.Vector3>(
    heroNodes.map((n) => [n.tool.id, n.pos]),
  );

  // hero-to-hero edges from relationIds (deduped, both endpoints present)
  const seen = new Set<string>();
  const edges: Edge[] = [];
  for (const node of heroNodes) {
    for (const relId of node.tool.relationIds) {
      if (!heroPosById.has(relId)) continue;
      const key = [node.tool.id, relId].sort().join('|');
      if (seen.has(key)) continue;
      seen.add(key);
      edges.push({ a: node.tool.id, b: relId });
    }
  }

  const adjacency = new Map<string, Set<string>>();
  for (const e of edges) {
    (adjacency.get(e.a) ?? adjacency.set(e.a, new Set()).get(e.a)!).add(e.b);
    (adjacency.get(e.b) ?? adjacency.set(e.b, new Set()).get(e.b)!).add(e.a);
  }

  const edgesByNode = new Map<string, number[]>();
  edges.forEach((e, i) => {
    (edgesByNode.get(e.a) ?? edgesByNode.set(e.a, []).get(e.a)!).push(i);
    (edgesByNode.get(e.b) ?? edgesByNode.set(e.b, []).get(e.b)!).push(i);
  });

  return { heroNodes, heroById, heroPosById, edges, adjacency, edgesByNode };
}

const AMBIENT_NODES: AmbientNode[] = (() => {
  const rand = mulberry32(0x1d0e77);
  const out: AmbientNode[] = [];
  const deep = new THREE.Color('#070d24');
  // dense glial tissue clustered around each category centre
  for (const cat of categories) {
    const center = clusterCenters.get(cat.id) ?? new THREE.Vector3();
    const base = new THREE.Color(cat.color);
    const count = cat.id === 'core' ? CLUSTER_CORE_COUNT : CLUSTER_OTHER_COUNT;
    for (let i = 0; i < count; i++) {
      const dir = new THREE.Vector3(
        rand() - 0.5,
        rand() - 0.5,
        rand() - 0.5,
      ).normalize();
      const dist = 4 + Math.pow(rand(), 1.7) * 18;
      const pos = center.clone().addScaledVector(dir, dist);
      const c = base.clone().lerp(deep, 0.5 + rand() * 0.15);
      out.push({
        pos,
        color: c,
        scale: 0.16 + rand() * 0.42,
        phase: rand() * Math.PI * 2,
      });
    }
  }
  // far volumetric haze — gives the field real depth
  for (let i = 0; i < HAZE_COUNT; i++) {
    const dir = new THREE.Vector3(
      rand() - 0.5,
      rand() - 0.5,
      rand() - 0.5,
    ).normalize();
    const dist = 58 + rand() * 110;
    out.push({
      pos: dir.multiplyScalar(dist),
      color: new THREE.Color('#1b2c57').lerp(new THREE.Color('#6ed0ff'), rand() * 0.55),
      scale: 0.09 + rand() * 0.2,
      phase: rand() * Math.PI * 2,
    });
  }
  return out;
})();

/* --- shared textures at module scope ------------------------------ */
function makeGlowTexture(): THREE.Texture {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.22, 'rgba(255,255,255,0.7)');
  g.addColorStop(0.5, 'rgba(255,255,255,0.2)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

/* ------------------------------------------------------------------ *
 * Ambient field — additive billboard halos (Cosmograph-style glow)
 * ------------------------------------------------------------------ */
function AmbientField({ glow, focused }: { glow: THREE.Texture; focused: boolean }) {
  const ref = useRef<THREE.InstancedMesh>(null);
  const dimRef = useRef(1);
  const dummy = useMemo(() => new THREE.Object3D(), []);
  const colorArray = useMemo(() => {
    const arr = new Float32Array(AMBIENT_NODES.length * 3);
    AMBIENT_NODES.forEach((n, i) => {
      arr[i * 3] = n.color.r;
      arr[i * 3 + 1] = n.color.g;
      arr[i * 3 + 2] = n.color.b;
    });
    return arr;
  }, []);
  const { camera } = useThree();

  useFrame((state, delta) => {
    const mesh = ref.current;
    if (!mesh) return;
    const dt = Math.min(delta, 1 / 30);
    const t = state.clock.elapsedTime;
    dimRef.current = THREE.MathUtils.lerp(
      dimRef.current,
      focused ? 0.22 : 1,
      1 - Math.pow(0.02, dt),
    );
    const dim = dimRef.current;
    for (let i = 0; i < AMBIENT_NODES.length; i++) {
      const n = AMBIENT_NODES[i];
      dummy.position.copy(n.pos);
      dummy.quaternion.copy(camera.quaternion);
      const pulse = PREFERS_REDUCED_MOTION
        ? 0.9
        : 0.82 + Math.sin(t * 0.7 + n.phase) * 0.18;
      dummy.scale.setScalar(n.scale * pulse * dim);
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
    }
    mesh.instanceMatrix.needsUpdate = true;
  });

  return (
    <instancedMesh
      ref={ref}
      args={[undefined, undefined, AMBIENT_NODES.length]}
      frustumCulled={false}
    >
      <planeGeometry args={[1, 1]}>
        <instancedBufferAttribute attach="attributes-color" args={[colorArray, 3]} />
      </planeGeometry>
      <meshBasicMaterial
        map={glow}
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
        vertexColors
        opacity={0.9}
      />
    </instancedMesh>
  );
}

/* ------------------------------------------------------------------ *
 * Synapse pulses — bright sparks travelling along every edge.
 * One instanced mesh; per-edge travel precomputed, positions mutated.
 * ------------------------------------------------------------------ */
function SynapsePulses({
  glow,
  activeId,
  edges,
  heroPosById,
  edgesByNode,
  toolById,
}: {
  glow: THREE.Texture;
  activeId: string | null;
  edges: Edge[];
  heroPosById: Map<string, THREE.Vector3>;
  edgesByNode: Map<string, number[]>;
  toolById: Map<string, AddedTool>;
}) {
  const ref = useRef<THREE.InstancedMesh>(null);
  const dummy = useMemo(() => new THREE.Object3D(), []);
  const { camera } = useThree();
  const total = edges.length * PULSES_PER_EDGE;

  // per-pulse static params + scratch endpoints (precomputed per graph)
  const data = useMemo(() => {
    const rand = mulberry32(0xabc123);
    const offset = new Float32Array(total);
    const speed = new Float32Array(total);
    const ax = new Float32Array(total);
    const ay = new Float32Array(total);
    const az = new Float32Array(total);
    const bx = new Float32Array(total);
    const by = new Float32Array(total);
    const bz = new Float32Array(total);
    edges.forEach((e, ei) => {
      const pa = heroPosById.get(e.a)!;
      const pb = heroPosById.get(e.b)!;
      for (let k = 0; k < PULSES_PER_EDGE; k++) {
        const i = ei * PULSES_PER_EDGE + k;
        offset[i] = rand();
        speed[i] = 0.12 + rand() * 0.16;
        ax[i] = pa.x;
        ay[i] = pa.y;
        az[i] = pa.z;
        bx[i] = pb.x;
        by[i] = pb.y;
        bz[i] = pb.z;
      }
    });
    return { offset, speed, ax, ay, az, bx, by, bz };
  }, [total, edges, heroPosById]);

  // edge "hot" factor: 1 when edge touches the active node, else 0
  const hotByEdge = useMemo(() => {
    const arr = new Float32Array(edges.length);
    if (activeId) {
      const idxs = edgesByNode.get(activeId);
      if (idxs) for (const i of idxs) arr[i] = 1;
    }
    return arr;
  }, [activeId, edges, edgesByNode]);

  const colorArray = useMemo(() => {
    const arr = new Float32Array(total * 3);
    edges.forEach((e, ei) => {
      const col = new THREE.Color(
        categoryById.get(toolById.get(e.b)!.category)!.color,
      ).lerp(new THREE.Color('#ffffff'), 0.4);
      for (let k = 0; k < PULSES_PER_EDGE; k++) {
        const i = ei * PULSES_PER_EDGE + k;
        arr[i * 3] = col.r;
        arr[i * 3 + 1] = col.g;
        arr[i * 3 + 2] = col.b;
      }
    });
    return arr;
  }, [total, edges, toolById]);

  useFrame((state) => {
    const mesh = ref.current;
    if (!mesh) return;
    // reduced-motion: pulses crawl rather than dart
    const t = state.clock.elapsedTime * (PREFERS_REDUCED_MOTION ? 0.35 : 1);
    const hasActive = activeId != null;
    for (let ei = 0; ei < edges.length; ei++) {
      const hot = hotByEdge[ei];
      // unfocused: gentle ambient pulses everywhere; focused: only hot edges
      const visible = hasActive ? hot > 0.5 : true;
      const boost = hot > 0.5 ? 2.2 : 1;
      for (let k = 0; k < PULSES_PER_EDGE; k++) {
        const i = ei * PULSES_PER_EDGE + k;
        if (!visible) {
          dummy.scale.setScalar(0);
          dummy.updateMatrix();
          mesh.setMatrixAt(i, dummy.matrix);
          continue;
        }
        let p = (data.offset[i] + t * data.speed[i] * boost) % 1;
        if (p < 0) p += 1;
        dummy.position.set(
          THREE.MathUtils.lerp(data.ax[i], data.bx[i], p),
          THREE.MathUtils.lerp(data.ay[i], data.by[i], p),
          THREE.MathUtils.lerp(data.az[i], data.bz[i], p),
        );
        dummy.quaternion.copy(camera.quaternion);
        // fade in/out at the ends of the synapse
        const ends = Math.sin(p * Math.PI);
        const baseSize = hot > 0.5 ? 1.5 : 0.7;
        dummy.scale.setScalar(baseSize * ends);
        dummy.updateMatrix();
        mesh.setMatrixAt(i, dummy.matrix);
      }
    }
    mesh.instanceMatrix.needsUpdate = true;
  });

  return (
    <instancedMesh
      ref={ref}
      args={[undefined, undefined, total]}
      frustumCulled={false}
    >
      <planeGeometry args={[1, 1]}>
        <instancedBufferAttribute attach="attributes-color" args={[colorArray, 3]} />
      </planeGeometry>
      <meshBasicMaterial
        map={glow}
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
        vertexColors
        opacity={0.95}
      />
    </instancedMesh>
  );
}

/* ------------------------------------------------------------------ *
 * Hero neuron — glass shell + emissive core + dendrite spikes + halos
 * ------------------------------------------------------------------ */
const SPIKE_GEO = new THREE.ConeGeometry(0.08, 0.5, 6);

type NeuronState = 'idle' | 'active' | 'neighbor' | 'dimmed' | 'search';

function HeroNeuron({
  node,
  state,
  onSelect,
  onHover,
  glow,
}: {
  node: HeroNode;
  state: NeuronState;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
  glow: THREE.Texture;
}) {
  const groupRef = useRef<THREE.Group>(null);
  const haloRef = useRef<THREE.Mesh>(null);
  const halo2Ref = useRef<THREE.Mesh>(null);
  const coreRef = useRef<THREE.MeshStandardMaterial>(null);
  const shellRef = useRef<THREE.MeshPhysicalMaterial>(null);
  const [hovered, setHovered] = useState(false);
  const isHero = node.tool.id === HERO_ID;
  const isNew = node.tool.userAdded === true;
  const baseScale = node.size;
  const sCur = useRef(baseScale);
  const haloCur = useRef(1);
  const emisCur = useRef(1.1);
  const opCur = useRef(1);
  // user-added nodes ease/scale in gently from 0 so they don't pop
  const bornCur = useRef(isNew ? 0 : 1);

  // dendrite spike directions (precomputed per node)
  const spikes = useMemo(() => {
    const rand = mulberry32(node.tool.id.length * 2654435761 + node.tool.name.length);
    const n = isHero ? 14 : 7;
    const golden = Math.PI * (3 - Math.sqrt(5));
    return Array.from({ length: n }, (_, i) => {
      const y = 1 - (i / (n - 1)) * 2;
      const r = Math.sqrt(Math.max(0, 1 - y * y));
      const th = golden * i + rand() * 0.4;
      const dir = new THREE.Vector3(Math.cos(th) * r, y, Math.sin(th) * r);
      const q = new THREE.Quaternion().setFromUnitVectors(
        new THREE.Vector3(0, 1, 0),
        dir,
      );
      return {
        position: dir.clone().multiplyScalar(1.05),
        quaternion: q,
        len: 0.7 + rand() * 0.6,
      };
    });
  }, [node.tool.id, node.tool.name, isHero]);

  useFrame((s, delta) => {
    const g = groupRef.current;
    if (!g) return;
    const dt = Math.min(delta, 1 / 30);
    // frame-rate-independent easing — identical settle on 60 & 120 Hz
    const kFast = 1 - Math.pow(0.0001, dt);
    const kSoft = 1 - Math.pow(0.00005, dt);
    const t = s.clock.elapsedTime;
    const breathe = PREFERS_REDUCED_MOTION
      ? 1
      : 1 + Math.sin(t * 1.2 + node.phase) * 0.05;

    // base values pushed up to keep the bloom-free glow reading bright
    let s2 = baseScale;
    let haloOn = isHero ? 1.9 : 1.4;
    let emis = isHero ? 2.4 : 1.7;
    let opacity = 1;
    if (state === 'active') {
      s2 = baseScale * 1.5;
      haloOn = 3.4;
      emis = 4.2;
    } else if (state === 'neighbor') {
      s2 = baseScale * 1.22;
      haloOn = 2.5;
      emis = 3;
    } else if (state === 'search') {
      // a search match while no tool is focused — make it sing
      s2 = baseScale * 1.35;
      haloOn = 3.2;
      emis = 4;
    } else if (state === 'dimmed') {
      haloOn = 0.32;
      emis = 0.4;
      opacity = 0.3;
    }
    if (hovered && state !== 'active') {
      s2 *= 1.2;
      haloOn = Math.max(haloOn, 2.1);
      emis = Math.max(emis, 2.4);
    }
    sCur.current = THREE.MathUtils.lerp(sCur.current, s2 * breathe, kFast);
    haloCur.current = THREE.MathUtils.lerp(haloCur.current, haloOn, kSoft);
    emisCur.current = THREE.MathUtils.lerp(emisCur.current, emis, kSoft);
    opCur.current = THREE.MathUtils.lerp(opCur.current, opacity, kSoft);
    // gentle birth scale-in for freshly added nodes (settles to 1)
    bornCur.current = THREE.MathUtils.lerp(bornCur.current, 1, kSoft);
    g.scale.setScalar(sCur.current * bornCur.current);
    // slow majestic self-rotation (held still when reduced-motion)
    g.rotation.y = PREFERS_REDUCED_MOTION ? node.phase : t * 0.12 + node.phase;

    const activePulse =
      !PREFERS_REDUCED_MOTION &&
      (state === 'active' || state === 'neighbor' || state === 'search')
        ? 1 + Math.sin(t * 3.4) * 0.18
        : 1;
    if (haloRef.current) {
      haloRef.current.scale.setScalar(haloCur.current * activePulse);
      haloRef.current.quaternion.copy(s.camera.quaternion);
    }
    if (halo2Ref.current) {
      halo2Ref.current.scale.setScalar(haloCur.current * 1.8 * activePulse);
      halo2Ref.current.quaternion.copy(s.camera.quaternion);
      const m = halo2Ref.current.material as THREE.MeshBasicMaterial;
      m.opacity = 0.18 * haloCur.current * 0.6;
    }
    if (coreRef.current) coreRef.current.emissiveIntensity = emisCur.current;
    if (shellRef.current) shellRef.current.opacity = 0.16 + opCur.current * 0.14;
  });

  const labelVisible =
    state === 'active' || state === 'neighbor' || state === 'search' || hovered;
  const haloSize = isHero ? 8 : 4.6;

  return (
    <group ref={groupRef} position={node.pos}>
      {/* wide outer atmosphere halo */}
      <mesh ref={halo2Ref}>
        <planeGeometry args={[haloSize, haloSize]} />
        <meshBasicMaterial
          map={glow}
          color={node.color}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
          opacity={0.18}
        />
      </mesh>
      {/* tight bright halo */}
      <mesh ref={haloRef}>
        <planeGeometry args={[haloSize * 0.62, haloSize * 0.62]} />
        <meshBasicMaterial
          map={glow}
          color={node.color}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
          opacity={0.9}
        />
      </mesh>

      {/* dendrite spikes */}
      {spikes.map((sp, i) => (
        <mesh
          key={i}
          geometry={SPIKE_GEO}
          position={sp.position}
          quaternion={sp.quaternion}
          scale={[1, sp.len, 1]}
        >
          <meshBasicMaterial
            color={node.color}
            transparent
            opacity={0.5}
            blending={THREE.AdditiveBlending}
            depthWrite={false}
          />
        </mesh>
      ))}

      {/* translucent glass shell (clickable) */}
      <mesh
        onClick={(e) => {
          e.stopPropagation();
          onSelect(node.tool.id);
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          setHovered(true);
          onHover(node.tool.id);
          document.body.style.cursor = 'pointer';
        }}
        onPointerOut={() => {
          setHovered(false);
          onHover(null);
          document.body.style.cursor = 'auto';
        }}
      >
        <icosahedronGeometry args={[1.18, 3]} />
        <meshPhysicalMaterial
          ref={shellRef}
          color={node.color}
          transparent
          opacity={0.22}
          roughness={0.05}
          metalness={0}
          transmission={0.6}
          thickness={1.2}
          clearcoat={1}
          clearcoatRoughness={0.1}
          depthWrite={false}
        />
      </mesh>

      {/* bright emissive core */}
      <mesh scale={0.7}>
        <icosahedronGeometry args={[1, 4]} />
        <meshStandardMaterial
          ref={coreRef}
          color={node.color}
          emissive={node.color}
          emissiveIntensity={1.4}
          roughness={0.25}
          metalness={0.1}
        />
      </mesh>

      {/* inner specular spark */}
      <mesh scale={0.34}>
        <icosahedronGeometry args={[1, 2]} />
        <meshBasicMaterial color="#ffffff" transparent opacity={0.35} />
      </mesh>

      {labelVisible && (
        <Billboard position={[0, (isHero ? 3.4 : 2.2) + (state === 'active' ? 0.4 : 0), 0]}>
          <Text
            fontSize={isHero ? 1.5 : 0.95}
            color="#ffffff"
            anchorX="center"
            anchorY="bottom"
            outlineWidth={0.05}
            outlineColor="#04060f"
            maxWidth={14}
          >
            {node.tool.name}
          </Text>
        </Billboard>
      )}
    </group>
  );
}

/* ------------------------------------------------------------------ *
 * Synapse links — additive line segments, dimming when focused
 * ------------------------------------------------------------------ */
function Synapses({
  activeId,
  edges,
  heroPosById,
  adjacency,
  toolById,
}: {
  activeId: string | null;
  edges: Edge[];
  heroPosById: Map<string, THREE.Vector3>;
  adjacency: Map<string, Set<string>>;
  toolById: Map<string, AddedTool>;
}) {
  const baseRef = useRef<THREE.LineSegments>(null);
  const activeRef = useRef<THREE.LineSegments>(null);
  const activeMat = useRef<THREE.LineBasicMaterial>(null);

  const baseGeo = useMemo(() => {
    const positions = new Float32Array(edges.length * 6);
    const colors = new Float32Array(edges.length * 6);
    edges.forEach((e, i) => {
      const pa = heroPosById.get(e.a)!;
      const pb = heroPosById.get(e.b)!;
      positions.set([pa.x, pa.y, pa.z, pb.x, pb.y, pb.z], i * 6);
      const colA = new THREE.Color(categoryById.get(toolById.get(e.a)!.category)!.color).multiplyScalar(0.45);
      const colB = new THREE.Color(categoryById.get(toolById.get(e.b)!.category)!.color).multiplyScalar(0.45);
      colors.set([colA.r, colA.g, colA.b, colB.r, colB.g, colB.b], i * 6);
    });
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    return geo;
  }, [edges, heroPosById, toolById]);

  const activeGeo = useMemo(() => {
    if (!activeId) return null;
    const neighbors = adjacency.get(activeId);
    if (!neighbors || neighbors.size === 0) return null;
    const center = heroPosById.get(activeId)!;
    const positions = new Float32Array(neighbors.size * 6);
    const colors = new Float32Array(neighbors.size * 6);
    let i = 0;
    for (const nb of neighbors) {
      const p = heroPosById.get(nb)!;
      positions.set([center.x, center.y, center.z, p.x, p.y, p.z], i * 6);
      const col = new THREE.Color(categoryById.get(toolById.get(nb)!.category)!.color);
      colors.set([1, 1, 1, col.r, col.g, col.b], i * 6);
      i++;
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    return geo;
  }, [activeId, heroPosById, adjacency, toolById]);

  useFrame((s, delta) => {
    const dt = Math.min(delta, 1 / 30);
    if (baseRef.current) {
      const m = baseRef.current.material as THREE.LineBasicMaterial;
      m.opacity = THREE.MathUtils.lerp(m.opacity, activeId ? 0.04 : 0.2, 1 - Math.pow(0.02, dt));
    }
    if (activeMat.current) {
      activeMat.current.opacity = PREFERS_REDUCED_MOTION
        ? 0.7
        : 0.6 + Math.sin(s.clock.elapsedTime * 4) * 0.3;
    }
  });

  return (
    <group>
      <lineSegments ref={baseRef} geometry={baseGeo}>
        <lineBasicMaterial
          vertexColors
          transparent
          opacity={0.2}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </lineSegments>
      {activeGeo && (
        <lineSegments ref={activeRef} geometry={activeGeo}>
          <lineBasicMaterial
            ref={activeMat}
            vertexColors
            transparent
            opacity={0.8}
            depthWrite={false}
            blending={THREE.AdditiveBlending}
          />
        </lineSegments>
      )}
    </group>
  );
}

/* ------------------------------------------------------------------ *
 * Camera rig — eased fly-in on selection (TheBrain re-centre)
 * ------------------------------------------------------------------ */
const HOME_TARGET = new THREE.Vector3(0, 0, 0);
const _orbit = new THREE.Vector3();

function CameraRig({
  activeId,
  heroPosById,
  heroById,
}: {
  activeId: string | null;
  heroPosById: Map<string, THREE.Vector3>;
  heroById: Map<string, HeroNode>;
}) {
  const { camera } = useThree();
  const targetPos = useRef(new THREE.Vector3(0, 12, 78));
  const lookTarget = useRef(HOME_TARGET.clone());
  const current = useRef(HOME_TARGET.clone());
  const angle = useRef(0);

  useFrame((s, delta) => {
    // clamp delta so a tab-restore / stutter can't make the camera jump
    const dt = Math.min(delta, 1 / 30);
    angle.current += dt * (PREFERS_REDUCED_MOTION ? 0.018 : 0.05);
    if (activeId) {
      const focus = heroPosById.get(activeId);
      if (focus) {
        const node = heroById.get(activeId);
        // dolly in close; radius scales a touch with neuron size
        const rad = 11 + (node ? node.size * 1.4 : 0);
        _orbit.set(
          Math.cos(angle.current) * rad,
          5 + Math.sin(angle.current * 0.7) * 2,
          Math.sin(angle.current) * rad,
        );
        targetPos.current.copy(focus).add(_orbit);
        lookTarget.current.copy(focus);
      }
    } else {
      // slow majestic drift around the whole brain
      targetPos.current.set(
        Math.cos(angle.current * 0.5) * 78,
        14 + Math.sin(angle.current * 0.4) * 6,
        Math.sin(angle.current * 0.5) * 78,
      );
      lookTarget.current.copy(HOME_TARGET);
    }
    // eased follow — different speeds give a cinematic settle
    const posK = 1 - Math.pow(activeId ? 0.0009 : 0.004, dt);
    const lookK = 1 - Math.pow(0.0015, dt);
    camera.position.lerp(targetPos.current, posK);
    current.current.lerp(lookTarget.current, lookK);
    camera.lookAt(current.current);
  });

  return null;
}

/* ------------------------------------------------------------------ *
 * Scene
 * ------------------------------------------------------------------ */
function Scene({
  activeId,
  hoverId,
  searchIds,
  activeCats,
  onSelect,
  onHover,
  heroNodes,
  heroById,
  heroPosById,
  edges,
  adjacency,
  edgesByNode,
  toolById,
}: {
  activeId: string | null;
  hoverId: string | null;
  searchIds: Set<string> | null;
  activeCats: Set<string> | null;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
  heroNodes: HeroNode[];
  heroById: Map<string, HeroNode>;
  heroPosById: Map<string, THREE.Vector3>;
  edges: Edge[];
  adjacency: Map<string, Set<string>>;
  edgesByNode: Map<string, number[]>;
  toolById: Map<string, AddedTool>;
}) {
  const glow = useMemo(() => makeGlowTexture(), []);
  const neighbors = activeId ? adjacency.get(activeId) : undefined;

  const stateOf = useCallback(
    (id: string): NeuronState => {
      // a focused tool always wins — its sub-world is the story
      if (activeId) {
        if (id === activeId) return 'active';
        if (neighbors?.has(id)) return 'neighbor';
        return 'dimmed';
      }
      const tool = toolById.get(id);
      // category filter: tools outside the active set recede
      if (activeCats && tool && !activeCats.has(tool.category)) return 'dimmed';
      // search: matches sing, everything else recedes
      if (searchIds) return searchIds.has(id) ? 'search' : 'dimmed';
      return 'idle';
    },
    [activeId, neighbors, searchIds, activeCats, toolById],
  );

  return (
    <>
      <color attach="background" args={['#04060f']} />
      <fog attach="fog" args={['#04060f', 48, 165]} />
      <ambientLight intensity={0.45} />
      <pointLight position={[0, 30, 30]} intensity={1.3} color="#9bd9ff" />
      <pointLight position={[-40, -20, -20]} intensity={0.6} color="#ff8bd2" />

      <CameraRig activeId={activeId} heroPosById={heroPosById} heroById={heroById} />
      <AmbientField glow={glow} focused={Boolean(activeId)} />
      <Synapses
        activeId={activeId}
        edges={edges}
        heroPosById={heroPosById}
        adjacency={adjacency}
        toolById={toolById}
      />
      <SynapsePulses
        glow={glow}
        activeId={activeId}
        edges={edges}
        heroPosById={heroPosById}
        edgesByNode={edgesByNode}
        toolById={toolById}
      />

      {heroNodes.map((node) => {
        const computed = stateOf(node.tool.id);
        // hovering a non-dimmed node previews it as a neighbor glow
        const state =
          hoverId === node.tool.id && !activeId && computed !== 'dimmed'
            ? 'neighbor'
            : computed;
        return (
          <HeroNeuron
            key={node.tool.id}
            node={node}
            state={state}
            onSelect={onSelect}
            onHover={onHover}
            glow={glow}
          />
        );
      })}
    </>
  );
}

/* ------------------------------------------------------------------ *
 * Public component
 * ------------------------------------------------------------------ */
const STAGE_LABEL: Record<AITool['stage'], string> = {
  research: 'Research',
  planning: 'Planning',
  execution: 'Execution',
  approval: 'Approval',
  review: 'Review',
};

export function NeuralUniverse() {
  const { openInApp } = useInAppBrowser();
  const { tools, toolById } = useToolStore();
  const graph = useMemo(() => buildGraph(tools, new Map()), [tools]);
  const categoryCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const tool of tools) counts.set(tool.category, (counts.get(tool.category) ?? 0) + 1);
    return counts;
  }, [tools]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  // category ids that are currently emphasised; null = all on
  const [activeCats, setActiveCats] = useState<Set<string> | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  const activeTool = activeId ? (toolById.get(activeId) ?? null) : null;
  const activeCat = activeTool ? categoryById.get(activeTool.category) : null;
  const neighborIds = useMemo(
    () => (activeId ? Array.from(graph.adjacency.get(activeId) ?? []) : []),
    [activeId, graph.adjacency],
  );

  // live search → matched ids (name / summary / category), ranked name-first
  const trimmed = query.trim().toLowerCase();
  const matches = useMemo(() => {
    if (!trimmed) return [];
    const starts: AITool[] = [];
    const contains: AITool[] = [];
    for (const tool of tools) {
      const name = tool.name.toLowerCase();
      if (name.startsWith(trimmed)) starts.push(tool);
      else if (
        name.includes(trimmed) ||
        tool.summary.toLowerCase().includes(trimmed) ||
        (categoryById.get(tool.category)?.name.toLowerCase().includes(trimmed) ?? false)
      )
        contains.push(tool);
    }
    return [...starts, ...contains];
  }, [tools, trimmed]);

  // null = no active search highlight (also when a query yields no matches,
  // so the brain stays alive rather than fully dimming out)
  const searchIds = useMemo(
    () => (trimmed && matches.length > 0 ? new Set(matches.map((t) => t.id)) : null),
    [trimmed, matches],
  );

  const handleSelect = useCallback((id: string) => {
    setActiveId((prev) => (prev === id ? null : id));
  }, []);

  const resetView = useCallback(() => {
    setActiveId(null);
    setQuery('');
    setActiveCats(null);
  }, []);

  const toggleCategory = useCallback((catId: string) => {
    setActiveCats((prev) => {
      const next = new Set(prev ?? []);
      if (next.has(catId)) next.delete(catId);
      else next.add(catId);
      // empty set means "no filter" — show everything
      return next.size === 0 ? null : next;
    });
  }, []);

  // Esc: clear search first, then back out of the sub-world / filters
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      if (trimmed) {
        setQuery('');
        searchRef.current?.blur();
      } else if (activeId) {
        setActiveId(null);
      } else if (activeCats) {
        setActiveCats(null);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [trimmed, activeId, activeCats]);

  // Enter in the search field → fly to the first match
  const onSearchKeyDown = useCallback(
    (e: ReactKeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter' && matches.length > 0) {
        e.preventDefault();
        setActiveId(matches[0].id);
        searchRef.current?.blur();
      }
    },
    [matches],
  );

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#04060f]">
      <Canvas
        camera={{ position: [0, 12, 78], fov: 52, near: 0.1, far: 420 }}
        gl={{
          antialias: !IS_SMALL,
          alpha: false,
          powerPreference: 'high-performance',
          toneMapping: THREE.ACESFilmicToneMapping,
        }}
        dpr={[1, 2]}
        onPointerMissed={() => setActiveId(null)}
      >
        <Scene
          activeId={activeId}
          hoverId={hoverId}
          searchIds={searchIds}
          activeCats={activeCats}
          onSelect={handleSelect}
          onHover={setHoverId}
          heroNodes={graph.heroNodes}
          heroById={graph.heroById}
          heroPosById={graph.heroPosById}
          edges={graph.edges}
          adjacency={graph.adjacency}
          edgesByNode={graph.edgesByNode}
          toolById={toolById}
        />
      </Canvas>

      {/* top chrome-safe heading + search */}
      <div className="absolute inset-x-0 top-0 px-5 pt-32 sm:px-8">
        <div className="pointer-events-none">
          <p className="text-[11px] font-medium uppercase tracking-[0.32em] text-cyan-200/70">
            Neural Universe
          </p>
          <h2 className="nu-fade mt-1 text-xl font-semibold text-white/95 sm:text-2xl" key={activeTool?.id ?? 'home'}>
            {activeTool ? activeTool.name : 'Flying inside the living AI brain'}
          </h2>
          <p className="mt-1 max-w-md text-[13px] text-white/45 sm:text-sm">
            {activeTool
              ? `Inside ${activeTool.name}'s sub-world — its connected tools are lit up around it.`
              : trimmed
                ? matches.length > 0
                  ? `${matches.length} ${matches.length === 1 ? 'tool' : 'tools'} match — press Enter to fly to the first.`
                  : `No tools match “${query.trim()}”.`
                : 'Tap a glowing neuron to dive into its world of connected tools.'}
          </p>
        </div>

        {/* liquid-glass search field (hidden inside a sub-world) */}
        {!activeTool && (
          <div className="nu-fade pointer-events-auto mt-3 flex max-w-md items-center gap-2 rounded-full border border-white/10 bg-white/[0.07] px-4 py-2.5 shadow-lg shadow-black/30 backdrop-blur-2xl focus-within:border-cyan-300/40">
            <svg
              aria-hidden
              viewBox="0 0 24 24"
              className="h-4 w-4 shrink-0 text-white/45"
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
              onKeyDown={onSearchKeyDown}
              placeholder="Search tools, categories…"
              aria-label="Search AI tools"
              className="min-w-0 flex-1 bg-transparent text-[14px] text-white/90 outline-none placeholder:text-white/35"
            />
            {trimmed && (
              <button
                type="button"
                onClick={() => {
                  setQuery('');
                  searchRef.current?.focus();
                }}
                aria-label="Clear search"
                className="shrink-0 rounded-full px-1.5 text-base leading-none text-white/45 transition-colors hover:text-white/80"
              >
                ×
              </button>
            )}
          </div>
        )}
      </div>

      {/* back-out button (only inside a sub-world) */}
      {activeTool && (
        <button
          type="button"
          onClick={() => setActiveId(null)}
          className="nu-fade absolute left-5 top-[136px] flex min-h-11 items-center gap-2 rounded-full border border-white/10 bg-white/[0.08] px-4 py-2 text-[13px] font-medium text-white/85 shadow-lg shadow-black/30 backdrop-blur-2xl transition-colors duration-300 hover:border-white/25 hover:bg-white/[0.14] active:bg-white/[0.16] sm:left-8"
        >
          <span aria-hidden className="text-base leading-none">←</span>
          Back to the brain
          <span className="ml-1 rounded border border-white/15 px-1.5 py-0.5 text-[10px] text-white/45">
            Esc
          </span>
        </button>
      )}

      {/* interactive category legend + filter (hidden inside a sub-world) */}
      {!activeTool && (
        <div className="nu-fade absolute bottom-5 left-5 right-5 rounded-2xl border border-white/10 bg-white/[0.06] p-3 shadow-lg shadow-black/30 backdrop-blur-2xl sm:left-8 sm:right-auto sm:max-w-md">
          <div className="mb-2 flex items-center justify-between px-1">
            <span className="text-[10px] font-medium uppercase tracking-[0.22em] text-white/40">
              {activeCats ? `Filtering ${activeCats.size}` : 'Categories'}
            </span>
            {(activeCats || trimmed) && (
              <button
                type="button"
                onClick={resetView}
                className="rounded-full border border-white/10 px-2.5 py-1 text-[10px] font-medium uppercase tracking-[0.14em] text-white/55 transition-colors hover:border-white/25 hover:text-white/85"
              >
                Reset
              </button>
            )}
          </div>
          <div className="flex flex-wrap gap-1.5">
            {categories.map((c) => {
              const on = !activeCats || activeCats.has(c.id);
              return (
                <button
                  key={c.id}
                  type="button"
                  onClick={() => toggleCategory(c.id)}
                  aria-pressed={activeCats ? activeCats.has(c.id) : true}
                  className="flex min-h-9 items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] transition-all duration-300 active:scale-[0.97]"
                  style={{
                    borderColor: on ? `${c.color}66` : 'rgba(255,255,255,0.06)',
                    backgroundColor: on ? `${c.color}1f` : 'rgba(255,255,255,0.02)',
                    opacity: on ? 1 : 0.45,
                  }}
                >
                  <span
                    className="h-2 w-2 rounded-full"
                    style={{
                      backgroundColor: c.color,
                      boxShadow: on ? `0 0 8px ${c.color}` : 'none',
                    }}
                  />
                  <span className={on ? 'text-white/80' : 'text-white/55'}>
                    {c.shortName}
                  </span>
                  <span className="text-white/35">{categoryCounts.get(c.id) ?? 0}</span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* selected-tool detail card */}
      {activeTool && activeCat && (
        <div
          key={activeTool.id}
          className="nu-fade absolute inset-x-5 bottom-5 max-h-[58vh] overflow-y-auto rounded-2xl border border-white/10 bg-white/[0.07] p-5 shadow-xl shadow-black/40 backdrop-blur-2xl sm:inset-x-auto sm:bottom-6 sm:right-6 sm:w-80"
        >
          <div className="flex items-center gap-2">
            <span
              className="h-2.5 w-2.5 rounded-full"
              style={{ backgroundColor: activeCat.color, boxShadow: `0 0 10px ${activeCat.color}` }}
            />
            <span className="text-[11px] font-medium uppercase tracking-[0.2em] text-white/55">
              {activeCat.name}
            </span>
          </div>
          <h3 className="mt-2 text-lg font-semibold text-white">{activeTool.name}</h3>

          {/* workflow stage pill */}
          <div className="mt-2 flex flex-wrap items-center gap-1.5">
            <span
              className="rounded-full border border-white/15 bg-white/[0.05] px-2.5 py-1 text-[10px] font-medium uppercase tracking-[0.14em] text-white/65"
            >
              {STAGE_LABEL[activeTool.stage]} stage
            </span>
          </div>

          <p className="mt-3 text-[10px] font-medium uppercase tracking-[0.2em] text-white/40">
            What it does
          </p>
          <p className="mt-1 text-sm leading-relaxed text-white/65">{activeTool.summary}</p>

          {neighborIds.length > 0 && (
            <div className="mt-4">
              <p className="text-[10px] font-medium uppercase tracking-[0.2em] text-white/40">
                Connected to · {neighborIds.length}
              </p>
              <div className="mt-2 flex flex-wrap gap-1.5">
                {neighborIds.map((id) => {
                  const nb = graph.heroById.get(id);
                  if (!nb) return null;
                  return (
                    <button
                      key={id}
                      type="button"
                      onClick={() => setActiveId(id)}
                      className="flex min-h-9 items-center gap-1.5 rounded-full border px-3 py-1.5 text-[12px] text-white/80 transition-all duration-200 hover:text-white active:scale-[0.97]"
                      style={{
                        borderColor: `${nb.category.color}55`,
                        backgroundColor: `${nb.category.color}1a`,
                      }}
                    >
                      <span
                        className="h-1.5 w-1.5 rounded-full"
                        style={{ backgroundColor: nb.category.color }}
                      />
                      {nb.tool.name}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          <div className="mt-4 flex items-center justify-between gap-3">
            <span className="text-[11px] text-white/40">
              {neighborIds.length} {neighborIds.length === 1 ? 'synapse' : 'synapses'}
            </span>
            {activeTool.url && (
              <button
                type="button"
                onClick={() => openInApp(activeTool.url!, activeTool.name)}
                className="flex min-h-9 items-center gap-1.5 rounded-full border border-white/15 bg-white/[0.08] px-3.5 py-1.5 text-[12px] font-medium text-white/85 transition-colors hover:border-white/30 hover:bg-white/[0.14] active:opacity-80"
              >
                Open
                <span aria-hidden className="text-[13px] leading-none">↗</span>
              </button>
            )}
          </div>
        </div>
      )}

      {/* eased glass entrance (calmed under reduced-motion) */}
      <style>{`
        .nu-fade { animation: nuFade 360ms cubic-bezier(0.22, 1, 0.36, 1) both; }
        @keyframes nuFade {
          from { opacity: 0; transform: translateY(8px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-reduced-motion: reduce) {
          .nu-fade { animation-duration: 1ms; transform: none; }
        }
      `}</style>
    </div>
  );
}
