import { useMemo, useRef, useState, useCallback, useEffect } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Billboard, Text } from '@react-three/drei';
import {
  EffectComposer,
  Bloom,
  Vignette,
  DepthOfField,
  ChromaticAberration,
} from '@react-three/postprocessing';
import * as THREE from 'three';
import {
  tools,
  categories,
  toolById,
  categoryById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

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

/* --- types -------------------------------------------------------- */
interface HeroNode {
  tool: AITool;
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

const HERO_NODES: HeroNode[] = (() => {
  const rand = mulberry32(0x5eed01);
  const byCat = new Map<string, AITool[]>();
  for (const tool of tools) {
    const list = byCat.get(tool.category) ?? [];
    list.push(tool);
    byCat.set(tool.category, list);
  }
  const out: HeroNode[] = [];
  for (const [catId, list] of byCat) {
    const center = clusterCenters.get(catId) ?? new THREE.Vector3();
    const category = categoryById.get(asCatId(catId)) ?? categories[0];
    const golden = Math.PI * (3 - Math.sqrt(5));
    list.forEach((tool, idx) => {
      const isHero = tool.id === HERO_ID;
      const y = list.length === 1 ? 0 : 1 - (idx / (list.length - 1)) * 2;
      const radius = Math.sqrt(Math.max(0, 1 - y * y));
      const theta = golden * idx;
      const jitter = 0.6 + rand() * 0.5;
      const spread = catId === 'core' ? 3 : 10 * jitter;
      const pos = isHero
        ? new THREE.Vector3(0, 0, 0)
        : new THREE.Vector3(
            center.x + Math.cos(theta) * radius * spread,
            center.y + y * spread * 0.7 + (rand() - 0.5) * 3.5,
            center.z + Math.sin(theta) * radius * spread,
          );
      // organic size variety; relation-rich nodes read as bigger hubs
      const hubBonus = Math.min(tool.relationIds.length, 6) * 0.06;
      const size = isHero ? 2.4 : 0.9 + rand() * 0.5 + hubBonus;
      out.push({
        tool,
        category,
        pos,
        color: new THREE.Color(category.color),
        size,
        phase: rand() * Math.PI * 2,
      });
    });
  }
  return out;
})();

const heroById = new Map<string, HeroNode>(HERO_NODES.map((n) => [n.tool.id, n]));
const heroPosById = new Map<string, THREE.Vector3>(
  HERO_NODES.map((n) => [n.tool.id, n.pos]),
);

const AMBIENT_NODES: AmbientNode[] = (() => {
  const rand = mulberry32(0x1d0e77);
  const out: AmbientNode[] = [];
  const deep = new THREE.Color('#070d24');
  // dense glial tissue clustered around each category centre
  for (const cat of categories) {
    const center = clusterCenters.get(cat.id) ?? new THREE.Vector3();
    const base = new THREE.Color(cat.color);
    const count = cat.id === 'core' ? 60 : 40;
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
  for (let i = 0; i < 340; i++) {
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

// hero-to-hero edges from relationIds (deduped)
const EDGES: Edge[] = (() => {
  const seen = new Set<string>();
  const out: Edge[] = [];
  for (const node of HERO_NODES) {
    for (const relId of node.tool.relationIds) {
      if (!heroPosById.has(relId)) continue;
      const key = [node.tool.id, relId].sort().join('|');
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({ a: node.tool.id, b: relId });
    }
  }
  return out;
})();

const adjacency = new Map<string, Set<string>>();
for (const e of EDGES) {
  (adjacency.get(e.a) ?? adjacency.set(e.a, new Set()).get(e.a)!).add(e.b);
  (adjacency.get(e.b) ?? adjacency.set(e.b, new Set()).get(e.b)!).add(e.a);
}

// flat list of edge index per endpoint, for fast active-edge lookups
const edgesByNode = new Map<string, number[]>();
EDGES.forEach((e, i) => {
  (edgesByNode.get(e.a) ?? edgesByNode.set(e.a, []).get(e.a)!).push(i);
  (edgesByNode.get(e.b) ?? edgesByNode.set(e.b, []).get(e.b)!).push(i);
});

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
    const t = state.clock.elapsedTime;
    dimRef.current = THREE.MathUtils.lerp(
      dimRef.current,
      focused ? 0.22 : 1,
      1 - Math.pow(0.02, delta),
    );
    const dim = dimRef.current;
    for (let i = 0; i < AMBIENT_NODES.length; i++) {
      const n = AMBIENT_NODES[i];
      dummy.position.copy(n.pos);
      dummy.quaternion.copy(camera.quaternion);
      const pulse = 0.82 + Math.sin(t * 0.7 + n.phase) * 0.18;
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
const PULSES_PER_EDGE = 2;
function SynapsePulses({
  glow,
  activeId,
}: {
  glow: THREE.Texture;
  activeId: string | null;
}) {
  const ref = useRef<THREE.InstancedMesh>(null);
  const dummy = useMemo(() => new THREE.Object3D(), []);
  const { camera } = useThree();
  const total = EDGES.length * PULSES_PER_EDGE;

  // per-pulse static params + scratch endpoints (precomputed once)
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
    EDGES.forEach((e, ei) => {
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
  }, [total]);

  // edge "hot" factor: 1 when edge touches the active node, else 0
  const hotByEdge = useMemo(() => {
    const arr = new Float32Array(EDGES.length);
    if (activeId) {
      const idxs = edgesByNode.get(activeId);
      if (idxs) for (const i of idxs) arr[i] = 1;
    }
    return arr;
  }, [activeId]);

  const colorArray = useMemo(() => {
    const arr = new Float32Array(total * 3);
    EDGES.forEach((e, ei) => {
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
  }, [total]);

  useFrame((state) => {
    const mesh = ref.current;
    if (!mesh) return;
    const t = state.clock.elapsedTime;
    const hasActive = activeId != null;
    for (let ei = 0; ei < EDGES.length; ei++) {
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

function HeroNeuron({
  node,
  state,
  onSelect,
  onHover,
  glow,
}: {
  node: HeroNode;
  state: 'idle' | 'active' | 'neighbor' | 'dimmed';
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
  const baseScale = node.size;
  const sCur = useRef(baseScale);
  const haloCur = useRef(1);
  const emisCur = useRef(1.1);
  const opCur = useRef(1);

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

  useFrame((s) => {
    const g = groupRef.current;
    if (!g) return;
    const t = s.clock.elapsedTime;
    const breathe = 1 + Math.sin(t * 1.2 + node.phase) * 0.05;

    let s2 = baseScale;
    let haloOn = isHero ? 1.4 : 1;
    let emis = isHero ? 1.6 : 1.1;
    let opacity = 1;
    if (state === 'active') {
      s2 = baseScale * 1.5;
      haloOn = 2.8;
      emis = 3.2;
    } else if (state === 'neighbor') {
      s2 = baseScale * 1.22;
      haloOn = 2;
      emis = 2.2;
    } else if (state === 'dimmed') {
      haloOn = 0.28;
      emis = 0.35;
      opacity = 0.32;
    }
    if (hovered && state !== 'active') {
      s2 *= 1.2;
      haloOn = Math.max(haloOn, 2.1);
      emis = Math.max(emis, 2.4);
    }
    sCur.current = THREE.MathUtils.lerp(sCur.current, s2 * breathe, 0.12);
    haloCur.current = THREE.MathUtils.lerp(haloCur.current, haloOn, 0.1);
    emisCur.current = THREE.MathUtils.lerp(emisCur.current, emis, 0.1);
    opCur.current = THREE.MathUtils.lerp(opCur.current, opacity, 0.1);
    g.scale.setScalar(sCur.current);
    // slow majestic self-rotation
    g.rotation.y = t * 0.12 + node.phase;

    const activePulse =
      state === 'active' || state === 'neighbor'
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

  const labelVisible = state === 'active' || state === 'neighbor' || hovered;
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
function Synapses({ activeId }: { activeId: string | null }) {
  const baseRef = useRef<THREE.LineSegments>(null);
  const activeRef = useRef<THREE.LineSegments>(null);
  const activeMat = useRef<THREE.LineBasicMaterial>(null);

  const baseGeo = useMemo(() => {
    const positions = new Float32Array(EDGES.length * 6);
    const colors = new Float32Array(EDGES.length * 6);
    EDGES.forEach((e, i) => {
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
  }, []);

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
  }, [activeId]);

  useFrame((s, delta) => {
    if (baseRef.current) {
      const m = baseRef.current.material as THREE.LineBasicMaterial;
      m.opacity = THREE.MathUtils.lerp(m.opacity, activeId ? 0.04 : 0.2, 1 - Math.pow(0.02, delta));
    }
    if (activeMat.current) {
      activeMat.current.opacity = 0.6 + Math.sin(s.clock.elapsedTime * 4) * 0.3;
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

function CameraRig({ activeId }: { activeId: string | null }) {
  const { camera } = useThree();
  const targetPos = useRef(new THREE.Vector3(0, 12, 78));
  const lookTarget = useRef(HOME_TARGET.clone());
  const current = useRef(HOME_TARGET.clone());
  const angle = useRef(0);

  useFrame((s, delta) => {
    angle.current += delta * 0.05;
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
    const posK = 1 - Math.pow(activeId ? 0.0009 : 0.004, delta);
    const lookK = 1 - Math.pow(0.0015, delta);
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
  onSelect,
  onHover,
}: {
  activeId: string | null;
  hoverId: string | null;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}) {
  const glow = useMemo(() => makeGlowTexture(), []);
  const caOffset = useMemo(() => new THREE.Vector2(0.0006, 0.0009), []);
  const neighbors = activeId ? adjacency.get(activeId) : undefined;

  const stateOf = useCallback(
    (id: string): 'idle' | 'active' | 'neighbor' | 'dimmed' => {
      if (!activeId) return 'idle';
      if (id === activeId) return 'active';
      if (neighbors?.has(id)) return 'neighbor';
      return 'dimmed';
    },
    [activeId, neighbors],
  );

  return (
    <>
      <color attach="background" args={['#04060f']} />
      <fog attach="fog" args={['#04060f', 48, 165]} />
      <ambientLight intensity={0.45} />
      <pointLight position={[0, 30, 30]} intensity={1.3} color="#9bd9ff" />
      <pointLight position={[-40, -20, -20]} intensity={0.6} color="#ff8bd2" />

      <CameraRig activeId={activeId} />
      <AmbientField glow={glow} focused={Boolean(activeId)} />
      <Synapses activeId={activeId} />
      <SynapsePulses glow={glow} activeId={activeId} />

      {HERO_NODES.map((node) => (
        <HeroNeuron
          key={node.tool.id}
          node={node}
          state={hoverId === node.tool.id && !activeId ? 'neighbor' : stateOf(node.tool.id)}
          onSelect={onSelect}
          onHover={onHover}
          glow={glow}
        />
      ))}

      <EffectComposer>
        <Bloom
          intensity={1.7}
          luminanceThreshold={0.12}
          luminanceSmoothing={0.9}
          mipmapBlur
          radius={0.88}
        />
        <DepthOfField
          focusDistance={0.02}
          focalLength={0.12}
          bokehScale={2.4}
        />
        <ChromaticAberration
          offset={caOffset}
          radialModulation={false}
          modulationOffset={0}
        />
        <Vignette eskil={false} offset={0.22} darkness={0.9} />
      </EffectComposer>
    </>
  );
}

/* ------------------------------------------------------------------ *
 * Public component
 * ------------------------------------------------------------------ */
export function NeuralUniverse() {
  const [activeId, setActiveId] = useState<string | null>(null);
  const [hoverId, setHoverId] = useState<string | null>(null);

  const activeTool = activeId ? toolById.get(activeId) : null;
  const activeCat = activeTool ? categoryById.get(activeTool.category) : null;
  const neighborIds = useMemo(
    () => (activeId ? Array.from(adjacency.get(activeId) ?? []) : []),
    [activeId],
  );

  const handleSelect = useCallback((id: string) => {
    setActiveId((prev) => (prev === id ? null : id));
  }, []);

  // Esc backs out of the focused sub-world
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setActiveId(null);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#04060f]">
      <Canvas
        camera={{ position: [0, 12, 78], fov: 52, near: 0.1, far: 420 }}
        gl={{ antialias: true, alpha: false }}
        dpr={[1, 2]}
        onPointerMissed={() => setActiveId(null)}
      >
        <Scene
          activeId={activeId}
          hoverId={hoverId}
          onSelect={handleSelect}
          onHover={setHoverId}
        />
      </Canvas>

      {/* top chrome-safe heading */}
      <div className="pointer-events-none absolute inset-x-0 top-0 px-8 pt-16">
        <p className="text-[11px] font-medium uppercase tracking-[0.32em] text-cyan-200/70">
          Neural Universe
        </p>
        <h2 className="mt-1 text-2xl font-semibold text-white/95">
          {activeTool ? activeTool.name : 'Flying inside the living AI brain'}
        </h2>
        <p className="mt-1 max-w-md text-sm text-white/45">
          {activeTool
            ? `Inside ${activeTool.name}'s sub-world — its connected tools are lit up around it.`
            : 'Tap a glowing neuron to dive into its world of connected tools.'}
        </p>
      </div>

      {/* back-out button (only inside a sub-world) */}
      {activeTool && (
        <button
          type="button"
          onClick={() => setActiveId(null)}
          className="absolute left-8 top-[136px] flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.07] px-4 py-2 text-[13px] font-medium text-white/80 backdrop-blur-xl transition hover:border-white/30 hover:bg-white/[0.12]"
        >
          <span aria-hidden className="text-base leading-none">←</span>
          Back to the brain
          <span className="ml-1 rounded border border-white/15 px-1.5 py-0.5 text-[10px] text-white/45">
            Esc
          </span>
        </button>
      )}

      {/* legend (hidden inside a sub-world to keep focus) */}
      {!activeTool && (
        <div className="pointer-events-none absolute bottom-6 left-8 flex flex-wrap gap-x-4 gap-y-2">
          {categories.map((c) => (
            <div key={c.id} className="flex items-center gap-1.5">
              <span
                className="h-2 w-2 rounded-full"
                style={{ backgroundColor: c.color, boxShadow: `0 0 8px ${c.color}` }}
              />
              <span className="text-[11px] text-white/55">{c.shortName}</span>
            </div>
          ))}
        </div>
      )}

      {/* selected-tool detail card */}
      {activeTool && activeCat && (
        <div className="absolute bottom-6 right-6 w-80 rounded-2xl border border-white/10 bg-white/[0.06] p-5 backdrop-blur-xl">
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
          <p className="mt-1.5 text-sm leading-relaxed text-white/60">{activeTool.summary}</p>

          {neighborIds.length > 0 && (
            <div className="mt-3.5">
              <p className="text-[10px] font-medium uppercase tracking-[0.2em] text-white/40">
                Connected tools
              </p>
              <div className="mt-2 flex flex-wrap gap-1.5">
                {neighborIds.slice(0, 8).map((id) => {
                  const nb = heroById.get(id);
                  if (!nb) return null;
                  return (
                    <button
                      key={id}
                      type="button"
                      onClick={() => setActiveId(id)}
                      className="rounded-full border px-2.5 py-1 text-[11px] text-white/75 transition hover:text-white"
                      style={{
                        borderColor: `${nb.category.color}55`,
                        backgroundColor: `${nb.category.color}1a`,
                      }}
                    >
                      {nb.tool.name}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          <div className="mt-3 flex items-center gap-4 text-[11px] text-white/45">
            <span className="capitalize">Stage: {activeTool.stage}</span>
            <span>{neighborIds.length} synapses</span>
          </div>
        </div>
      )}
    </div>
  );
}
