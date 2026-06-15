import { useMemo, useRef, useState, useCallback } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Billboard, Text } from '@react-three/drei';
import { EffectComposer, Bloom, Vignette } from '@react-three/postprocessing';
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
 * Neural Universe — Direction O (hero)
 *
 * Technique studied: Cosmograph renders huge graphs as GPU point
 * clouds with additive blending so overlapping glows accumulate into
 * a luminous field. TheBrain re-centres the camera on a clicked node
 * and lights up only its immediate relations while everything else
 * recedes. Apple Vision Pro polish = big soft emissive "glass" bodies,
 * heavy bloom, depth fog, and calm eased motion.
 *
 * Emulation on our stack: 49 hero tool-neurons + a deep field of
 * dimmer ambient neurons placed in tight per-category clusters.
 * Additive sprite halos (one instanced mesh) give the Cosmograph
 * glow. Bloom + vignette + fog give the Vision Pro depth. Clicking a
 * neuron eases the camera to centre on it (TheBrain), pulses its
 * synapse links, and dims unrelated nodes.
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
  mid: THREE.Vector3;
}

/* --- layout (precomputed once at module scope) -------------------- */
// One cluster centre per category, arranged on a tilted ring.
const clusterCenters = new Map<string, THREE.Vector3>();
categories.forEach((cat, i) => {
  const t = (i / categories.length) * Math.PI * 2;
  const r = 30;
  clusterCenters.set(
    cat.id,
    new THREE.Vector3(
      Math.cos(t) * r,
      Math.sin(t * 2) * 7,
      Math.sin(t) * r,
    ),
  );
});

const HERO_NODES: HeroNode[] = (() => {
  const rand = mulberry32(0x5eed01);
  // group tools by category so they sit close together
  const byCat = new Map<string, AITool[]>();
  for (const tool of tools) {
    const list = byCat.get(tool.category) ?? [];
    list.push(tool);
    byCat.set(tool.category, list);
  }
  const out: HeroNode[] = [];
  for (const [catId, list] of byCat) {
    const center = clusterCenters.get(catId) ?? new THREE.Vector3();
    const category = categoryById.get(tool_cat(catId)) ?? categories[0];
    list.forEach((tool, idx) => {
      // fibonacci-ish spread inside a small cluster sphere
      const golden = Math.PI * (3 - Math.sqrt(5));
      const y = list.length === 1 ? 0 : 1 - (idx / (list.length - 1)) * 2;
      const radius = Math.sqrt(Math.max(0, 1 - y * y));
      const theta = golden * idx;
      const jitter = 0.55 + rand() * 0.45;
      const spread = catId === 'core' ? 2 : 9 * jitter;
      const pos = new THREE.Vector3(
        center.x + Math.cos(theta) * radius * spread,
        center.y + y * spread * 0.7 + (rand() - 0.5) * 3,
        center.z + Math.sin(theta) * radius * spread,
      );
      out.push({
        tool,
        category,
        pos,
        color: new THREE.Color(category.color),
      });
    });
  }
  return out;
})();

const heroPosById = new Map<string, THREE.Vector3>(
  HERO_NODES.map((n) => [n.tool.id, n.pos]),
);

// helper so TS narrows the category id union without an `any`
function tool_cat(id: string): AITool['category'] {
  return id as AITool['category'];
}

const AMBIENT_NODES: AmbientNode[] = (() => {
  const rand = mulberry32(0x1d0e77);
  const out: AmbientNode[] = [];
  // dim filler neurons clustered around each category centre
  for (const cat of categories) {
    const center = clusterCenters.get(cat.id) ?? new THREE.Vector3();
    const base = new THREE.Color(cat.color);
    const count = 34;
    for (let i = 0; i < count; i++) {
      const dir = new THREE.Vector3(
        rand() - 0.5,
        rand() - 0.5,
        rand() - 0.5,
      ).normalize();
      const dist = 4 + Math.pow(rand(), 1.6) * 16;
      const pos = center.clone().addScaledVector(dir, dist);
      const c = base.clone().lerp(new THREE.Color('#0a1230'), 0.45);
      out.push({
        pos,
        color: c,
        scale: 0.18 + rand() * 0.4,
        phase: rand() * Math.PI * 2,
      });
    }
  }
  // far ambient haze
  for (let i = 0; i < 280; i++) {
    const dir = new THREE.Vector3(
      rand() - 0.5,
      rand() - 0.5,
      rand() - 0.5,
    ).normalize();
    const dist = 55 + rand() * 90;
    out.push({
      pos: dir.multiplyScalar(dist),
      color: new THREE.Color('#243a6b').lerp(new THREE.Color('#5cc8ff'), rand() * 0.5),
      scale: 0.1 + rand() * 0.22,
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
      const other = heroPosById.get(relId);
      if (!other) continue;
      const key = [node.tool.id, relId].sort().join('|');
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({
        a: node.tool.id,
        b: relId,
        mid: node.pos.clone().add(other).multiplyScalar(0.5),
      });
    }
  }
  return out;
})();

const adjacency = new Map<string, Set<string>>();
for (const e of EDGES) {
  (adjacency.get(e.a) ?? adjacency.set(e.a, new Set()).get(e.a)!).add(e.b);
  (adjacency.get(e.b) ?? adjacency.set(e.b, new Set()).get(e.b)!).add(e.a);
}

/* --- shared geometry / material at module scope ------------------- */
function makeGlowTexture(): THREE.Texture {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.25, 'rgba(255,255,255,0.65)');
  g.addColorStop(0.55, 'rgba(255,255,255,0.18)');
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

  useFrame((state) => {
    const mesh = ref.current;
    if (!mesh) return;
    const t = state.clock.elapsedTime;
    const dim = focused ? 0.32 : 1;
    for (let i = 0; i < AMBIENT_NODES.length; i++) {
      const n = AMBIENT_NODES[i];
      dummy.position.copy(n.pos);
      dummy.quaternion.copy(camera.quaternion);
      const pulse = 0.85 + Math.sin(t * 0.8 + n.phase) * 0.15;
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
 * Hero neuron — soft emissive glass body + additive halo + label
 * ------------------------------------------------------------------ */
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
  const coreRef = useRef<THREE.MeshStandardMaterial>(null);
  const [hovered, setHovered] = useState(false);

  const baseScale = node.tool.id === 'founder-os' ? 1.9 : 1.15;
  const sCur = useRef(baseScale);
  const haloCur = useRef(1);
  const emisCur = useRef(1.1);

  useFrame((s) => {
    const g = groupRef.current;
    if (!g) return;
    const t = s.clock.elapsedTime;
    const breathe = 1 + Math.sin(t * 1.3 + node.pos.x) * 0.04;

    let s2 = baseScale;
    let haloOn = 1;
    let emis = 1.1;
    let opacity = 1;
    if (state === 'active') {
      s2 = baseScale * 1.45;
      haloOn = 2.4;
      emis = 2.6;
    } else if (state === 'neighbor') {
      s2 = baseScale * 1.15;
      haloOn = 1.7;
      emis = 1.9;
    } else if (state === 'dimmed') {
      haloOn = 0.35;
      emis = 0.45;
      opacity = 0.5;
    }
    if (hovered && state !== 'active') {
      s2 *= 1.18;
      haloOn = Math.max(haloOn, 1.8);
    }
    sCur.current = THREE.MathUtils.lerp(sCur.current, s2 * breathe, 0.12);
    haloCur.current = THREE.MathUtils.lerp(haloCur.current, haloOn, 0.12);
    emisCur.current = THREE.MathUtils.lerp(emisCur.current, emis, 0.12);
    g.scale.setScalar(sCur.current);

    if (haloRef.current) {
      const h = haloRef.current;
      const pulse = state === 'active' || state === 'neighbor'
        ? 1 + Math.sin(t * 3.2) * 0.16
        : 1;
      h.scale.setScalar(haloCur.current * pulse);
      h.quaternion.copy(s.camera.quaternion);
    }
    if (coreRef.current) {
      coreRef.current.emissiveIntensity = emisCur.current;
      coreRef.current.opacity = THREE.MathUtils.lerp(coreRef.current.opacity, opacity, 0.12);
    }
  });

  const labelVisible = state === 'active' || state === 'neighbor' || hovered;

  return (
    <group ref={groupRef} position={node.pos}>
      {/* additive halo */}
      <mesh ref={haloRef} scale={1}>
        <planeGeometry args={[5.2, 5.2]} />
        <meshBasicMaterial
          map={glow}
          color={node.color}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
          opacity={0.85}
        />
      </mesh>

      {/* glass / emissive body */}
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
        <icosahedronGeometry args={[1, 4]} />
        <meshStandardMaterial
          ref={coreRef}
          color={node.color}
          emissive={node.color}
          emissiveIntensity={1.1}
          roughness={0.18}
          metalness={0.1}
          transparent
          opacity={1}
        />
      </mesh>

      {/* inner specular highlight */}
      <mesh scale={0.55}>
        <icosahedronGeometry args={[1, 2]} />
        <meshBasicMaterial color="#ffffff" transparent opacity={0.18} />
      </mesh>

      {labelVisible && (
        <Billboard position={[0, node.tool.id === 'founder-os' ? 3.4 : 2.4, 0]}>
          <Text
            fontSize={node.tool.id === 'founder-os' ? 1.5 : 1.05}
            color="#ffffff"
            anchorX="center"
            anchorY="bottom"
            outlineWidth={0.04}
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
 * Synapse links — line segments, pulsing when active
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
      const ca = toolById.get(e.a);
      const cb = toolById.get(e.b);
      const colA = new THREE.Color(categoryById.get(ca!.category)!.color).multiplyScalar(0.5);
      const colB = new THREE.Color(categoryById.get(cb!.category)!.color).multiplyScalar(0.5);
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

  useFrame((s) => {
    if (baseRef.current) {
      const m = baseRef.current.material as THREE.LineBasicMaterial;
      m.opacity = THREE.MathUtils.lerp(m.opacity, activeId ? 0.06 : 0.22, 0.12);
    }
    if (activeMat.current) {
      activeMat.current.opacity = 0.55 + Math.sin(s.clock.elapsedTime * 4) * 0.35;
    }
  });

  return (
    <group>
      <lineSegments ref={baseRef} geometry={baseGeo}>
        <lineBasicMaterial
          vertexColors
          transparent
          opacity={0.22}
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
 * Camera rig — eased fly-to on selection (TheBrain re-centre)
 * ------------------------------------------------------------------ */
const HOME_POS = new THREE.Vector3(0, 8, 70);
const HOME_TARGET = new THREE.Vector3(0, 0, 0);

function CameraRig({ activeId }: { activeId: string | null }) {
  const { camera } = useThree();
  const targetPos = useRef(HOME_POS.clone());
  const lookTarget = useRef(HOME_TARGET.clone());
  const current = useRef(HOME_TARGET.clone());
  const angle = useRef(0);

  useFrame((s, delta) => {
    angle.current += delta * 0.04;
    if (activeId) {
      const focus = heroPosById.get(activeId);
      if (focus) {
        const orbit = new THREE.Vector3(
          Math.cos(angle.current) * 16,
          7,
          Math.sin(angle.current) * 16,
        );
        targetPos.current.copy(focus).add(orbit);
        lookTarget.current.copy(focus);
      }
    } else {
      // slow idle drift around the whole brain
      targetPos.current.set(
        Math.cos(angle.current * 0.6) * 70,
        10,
        Math.sin(angle.current * 0.6) * 70,
      );
      lookTarget.current.copy(HOME_TARGET);
    }
    camera.position.lerp(targetPos.current, 1 - Math.pow(0.0015, delta));
    current.current.lerp(lookTarget.current, 1 - Math.pow(0.0015, delta));
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
      <fog attach="fog" args={['#04060f', 60, 160]} />
      <ambientLight intensity={0.4} />
      <pointLight position={[0, 30, 30]} intensity={1.2} color="#9bd9ff" />

      <CameraRig activeId={activeId} />
      <AmbientField glow={glow} focused={Boolean(activeId)} />
      <Synapses activeId={activeId} />

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
          intensity={1.5}
          luminanceThreshold={0.15}
          luminanceSmoothing={0.9}
          mipmapBlur
          radius={0.85}
        />
        <Vignette eskil={false} offset={0.25} darkness={0.85} />
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
  const relatedCount = activeId ? adjacency.get(activeId)?.size ?? 0 : 0;

  const handleSelect = useCallback((id: string) => {
    setActiveId((prev) => (prev === id ? null : id));
  }, []);

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#04060f]">
      <Canvas
        camera={{ position: [0, 8, 70], fov: 52, near: 0.1, far: 400 }}
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
          Flying inside the living AI brain
        </h2>
        <p className="mt-1 max-w-md text-sm text-white/45">
          {activeTool
            ? 'Tap empty space to pull back out to the full field.'
            : 'Tap a glowing neuron to dive into its world of connected tools.'}
        </p>
      </div>

      {/* legend */}
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
          <div className="mt-3 flex items-center gap-4 text-[11px] text-white/45">
            <span className="capitalize">Stage: {activeTool.stage}</span>
            <span>{relatedCount} synapses</span>
          </div>
        </div>
      )}
    </div>
  );
}
