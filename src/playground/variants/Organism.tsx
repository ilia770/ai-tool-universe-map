import { useMemo, useRef, useState, useCallback } from 'react';
import { Canvas, useFrame, extend, type ThreeElement } from '@react-three/fiber';
import { Sparkles } from '@react-three/drei';
import { shaderMaterial } from '@react-three/drei';
import { EffectComposer, Bloom } from '@react-three/postprocessing';
import * as THREE from 'three';
import {
  tools,
  categoryById,
  toolById,
  type AITool,
} from '../../data/ai-tool-universe';

/* ------------------------------------------------------------------ *
 * Direction H — "Living Organism"
 *
 * Research (physarum / slime-mold WebGL art, after Jeff Jones 2010 &
 * Sage Jensen): organic networks read as alive when (a) motion is
 * driven by smooth noise/oscillation rather than rigid layout, (b)
 * connective veins visibly TRANSPORT something — calcium/light waves
 * travelling along the filament, and (c) nodes glow additively with a
 * soft falloff so the whole volume looks wet and bioluminescent.
 *
 * We emulate that with our stack + data: tools become bioluminescent
 * cell nuclei (category-coloured), relationIds become curved synapse
 * filaments carrying travelling light pulses, the camera + every cell
 * breathe via trig "noise", and a Bloom pass makes it glow. Clicking a
 * cell makes the organism gravitate around it (soft attraction).
 * ------------------------------------------------------------------ */

/* ----------------------------- PRNG ------------------------------- */
// Seeded mulberry32 — deterministic, so no Math.random() during render
// or module init (eslint react-hooks/purity).
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

/* --------------------------- geometry ----------------------------- */

interface Cell {
  tool: AITool;
  base: THREE.Vector3;
  color: THREE.Color;
  radius: number;
  phase: number;
  drift: THREE.Vector3;
  seed: number;
}

interface Synapse {
  a: number; // cell index
  b: number; // cell index
  mid: THREE.Vector3;
  color: THREE.Color;
  speed: number;
  offset: number;
}

// Suspend cells in a soft ellipsoidal volume. Category drives the
// hemisphere/cluster so related cells aggregate organically.
function buildOrganism(): { cells: Cell[]; synapses: Synapse[]; indexOf: Map<string, number> } {
  const rand = mulberry32(0x5eed1a7);
  const indexOf = new Map<string, number>();
  const cells: Cell[] = [];

  const catCenters = new Map<string, THREE.Vector3>();
  categoryById.forEach((cat, id) => {
    const a = (cat.angle * Math.PI) / 180;
    const tilt = (rand() - 0.5) * 0.9;
    catCenters.set(
      id,
      new THREE.Vector3(
        Math.cos(a) * 3.4,
        tilt * 2.2,
        Math.sin(a) * 3.4,
      ),
    );
  });

  tools.forEach((tool, i) => {
    indexOf.set(tool.id, i);
    const cat = categoryById.get(tool.category);
    const center = catCenters.get(tool.category) ?? new THREE.Vector3();
    // orbit 0 (core) sits dead-centre; outer orbits spread further out.
    const spread = tool.orbit === 0 ? 0 : 0.9 + tool.orbit * 0.75;
    const u = rand() * Math.PI * 2;
    const v = Math.acos(2 * rand() - 1);
    const r = spread * (0.55 + rand() * 0.6);
    const pos =
      tool.orbit === 0
        ? new THREE.Vector3(0, 0, 0)
        : new THREE.Vector3(
            center.x + r * Math.sin(v) * Math.cos(u),
            center.y * 0.6 + r * Math.cos(v) * 0.8,
            center.z + r * Math.sin(v) * Math.sin(u),
          );

    const color = new THREE.Color(cat?.color ?? '#9fd8ff');
    const radius =
      tool.orbit === 0 ? 0.62 : 0.2 + (3 - tool.orbit) * 0.06 + rand() * 0.05;

    cells.push({
      tool,
      base: pos,
      color,
      radius,
      phase: rand() * Math.PI * 2,
      drift: new THREE.Vector3(
        0.18 + rand() * 0.22,
        0.14 + rand() * 0.2,
        0.18 + rand() * 0.22,
      ),
      seed: rand() * 1000,
    });
  });

  // Synapse filaments from relationIds (dedup undirected pairs).
  const seen = new Set<string>();
  const synapses: Synapse[] = [];
  tools.forEach((tool) => {
    const ai = indexOf.get(tool.id);
    if (ai === undefined) return;
    tool.relationIds.forEach((rid) => {
      const bi = indexOf.get(rid);
      if (bi === undefined || bi === ai) return;
      const key = ai < bi ? `${ai}:${bi}` : `${bi}:${ai}`;
      if (seen.has(key)) return;
      seen.add(key);
      const ca = cells[ai];
      const cb = cells[bi];
      // organic bowed midpoint — never a straight rigid line.
      const mid = ca.base
        .clone()
        .add(cb.base)
        .multiplyScalar(0.5)
        .add(
          new THREE.Vector3(
            (rand() - 0.5) * 1.4,
            (rand() - 0.5) * 1.4 + 0.3,
            (rand() - 0.5) * 1.4,
          ),
        );
      synapses.push({
        a: ai,
        b: bi,
        mid,
        color: ca.color.clone().lerp(cb.color, 0.5),
        speed: 0.4 + rand() * 0.7,
        offset: rand(),
      });
    });
  });

  return { cells, synapses, indexOf };
}

/* ------------------------- cell material -------------------------- */
// Soft bioluminescent nucleus: bright wet core, fresnel rim, breathing
// pulse. Additive so overlapping cells bloom into one glowing volume.
const NucleusMaterial = shaderMaterial(
  {
    uColor: new THREE.Color('#9fd8ff'),
    uTime: 0,
    uPulse: 0,
    uActive: 0,
  },
  /* glsl */ `
    varying vec3 vNormal;
    varying vec3 vView;
    void main() {
      vNormal = normalize(normalMatrix * normal);
      vec4 mv = modelViewMatrix * vec4(position, 1.0);
      vView = normalize(-mv.xyz);
      gl_Position = projectionMatrix * mv;
    }
  `,
  /* glsl */ `
    uniform vec3 uColor;
    uniform float uTime;
    uniform float uPulse;
    uniform float uActive;
    varying vec3 vNormal;
    varying vec3 vView;
    void main() {
      float fres = pow(1.0 - max(dot(vNormal, vView), 0.0), 2.0);
      float core = pow(max(dot(vNormal, vView), 0.0), 1.4);
      float breathe = 0.55 + 0.45 * sin(uTime + uPulse);
      vec3 col = uColor * (0.35 + core * 1.3 + fres * 0.9);
      col += uColor * breathe * (0.35 + uActive * 0.9);
      float alpha = core * 0.9 + fres * 0.75;
      alpha *= 0.5 + 0.5 * breathe;
      gl_FragColor = vec4(col, clamp(alpha, 0.0, 1.0));
    }
  `,
);

/* ------------------------ synapse material ------------------------ */
// Faint resting vein with a sharp travelling light pulse — the
// "calcium wave" that makes the network read as alive.
const SynapseMaterial = shaderMaterial(
  {
    uColor: new THREE.Color('#9fd8ff'),
    uTime: 0,
    uSpeed: 0.5,
    uOffset: 0.0,
    uActive: 0,
  },
  /* glsl */ `
    attribute float aT;
    varying float vT;
    void main() {
      vT = aT;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  /* glsl */ `
    uniform vec3 uColor;
    uniform float uTime;
    uniform float uSpeed;
    uniform float uOffset;
    uniform float uActive;
    varying float vT;
    void main() {
      float head = fract(uTime * uSpeed + uOffset);
      float d = abs(vT - head);
      d = min(d, 1.0 - d);
      float pulse = smoothstep(0.10, 0.0, d);
      float rest = 0.10 + 0.10 * uActive;
      float glow = rest + pulse * (1.0 + uActive * 1.5);
      vec3 col = uColor * glow;
      gl_FragColor = vec4(col, clamp(glow, 0.0, 1.0));
    }
  `,
);

extend({ NucleusMaterial, SynapseMaterial });

declare module '@react-three/fiber' {
  interface ThreeElements {
    nucleusMaterial: ThreeElement<typeof NucleusMaterial>;
    synapseMaterial: ThreeElement<typeof SynapseMaterial>;
  }
}

/* ---------------------------- synapse ----------------------------- */
const SEG = 40;
const sphereGeo = new THREE.SphereGeometry(1, 24, 24);

function SynapseLine({
  syn,
  cells,
  active,
}: {
  syn: Synapse;
  cells: Cell[];
  active: number;
}) {
  const matRef = useRef<THREE.ShaderMaterial & { uTime: number; uActive: number }>(null);
  const posRef = useRef<THREE.BufferAttribute>(null);
  const ca = cells[syn.a];
  const cb = cells[syn.b];

  const geom = useMemo(() => {
    const g = new THREE.BufferGeometry();
    const positions = new Float32Array((SEG + 1) * 3);
    const ts = new Float32Array(SEG + 1);
    for (let i = 0; i <= SEG; i++) ts[i] = i / SEG;
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    g.setAttribute('aT', new THREE.BufferAttribute(ts, 1));
    return g;
  }, []);

  // scratch vectors (module-frame reuse, allocated once)
  const tmp = useMemo(() => new THREE.Vector3(), []);
  const a0 = useMemo(() => new THREE.Vector3(), []);
  const b0 = useMemo(() => new THREE.Vector3(), []);

  useFrame((state) => {
    const t = state.clock.elapsedTime;
    if (matRef.current) {
      matRef.current.uTime = t;
      matRef.current.uActive = active;
    }
    const attr = posRef.current;
    if (!attr) return;
    // live endpoints follow each cell's breathing position
    cellPosition(ca, t, a0);
    cellPosition(cb, t, b0);
    const arr = attr.array as Float32Array;
    for (let i = 0; i <= SEG; i++) {
      const u = i / SEG;
      const omu = 1 - u;
      // quadratic bezier a0 -> mid -> b0
      tmp.set(
        omu * omu * a0.x + 2 * omu * u * syn.mid.x + u * u * b0.x,
        omu * omu * a0.y + 2 * omu * u * syn.mid.y + u * u * b0.y,
        omu * omu * a0.z + 2 * omu * u * syn.mid.z + u * u * b0.z,
      );
      arr[i * 3] = tmp.x;
      arr[i * 3 + 1] = tmp.y;
      arr[i * 3 + 2] = tmp.z;
    }
    attr.needsUpdate = true;
  });

  return (
    <line>
      <primitive object={geom} attach="geometry">
        <bufferAttribute ref={posRef} attach="attributes-position" args={[geom.getAttribute('position').array as Float32Array, 3]} />
      </primitive>
      <synapseMaterial
        ref={matRef}
        attach="material"
        uColor={syn.color}
        uSpeed={syn.speed}
        uOffset={syn.offset}
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </line>
  );
}

/* ------------------------ shared motion --------------------------- */
// Noise-driven organic drift (cheap trig "noise"). Writes into `out`.
function cellPosition(cell: Cell, t: number, out: THREE.Vector3): void {
  const s = cell.seed;
  out.set(
    cell.base.x + Math.sin(t * 0.33 + s) * cell.drift.x,
    cell.base.y + Math.sin(t * 0.27 + s * 1.7) * cell.drift.y,
    cell.base.z + Math.cos(t * 0.31 + s * 0.6) * cell.drift.z,
  );
}

/* ------------------------------ cell ------------------------------ */
function CellNucleus({
  cell,
  active,
  hovered,
  onClick,
  onOver,
  onOut,
}: {
  cell: Cell;
  active: boolean;
  hovered: boolean;
  onClick: () => void;
  onOver: () => void;
  onOut: () => void;
}) {
  const ref = useRef<THREE.Mesh>(null);
  const matRef = useRef<THREE.ShaderMaterial & { uTime: number; uPulse: number; uActive: number }>(null);
  const pos = useMemo(() => new THREE.Vector3(), []);

  useFrame((state) => {
    const t = state.clock.elapsedTime;
    cellPosition(cell, t, pos);
    const m = ref.current;
    if (m) {
      m.position.copy(pos);
      const breathe = 1 + Math.sin(t * 0.9 + cell.phase) * 0.06;
      const emphasize = (active ? 1.45 : 1) * (hovered ? 1.2 : 1);
      const s = cell.radius * breathe * emphasize;
      m.scale.setScalar(s);
    }
    if (matRef.current) {
      matRef.current.uTime = t * 1.6;
      matRef.current.uPulse = cell.phase;
      matRef.current.uActive = active ? 1 : hovered ? 0.5 : 0;
    }
  });

  return (
    <mesh
      ref={ref}
      geometry={sphereGeo}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      onPointerOver={(e) => {
        e.stopPropagation();
        onOver();
      }}
      onPointerOut={onOut}
    >
      <nucleusMaterial
        ref={matRef}
        uColor={cell.color}
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </mesh>
  );
}

/* ----------------------- breathing membrane ----------------------- */
function Membrane() {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((state) => {
    const t = state.clock.elapsedTime;
    if (ref.current) {
      const s = 1 + Math.sin(t * 0.4) * 0.04;
      ref.current.scale.set(s, s * 0.92, s);
      ref.current.rotation.y = t * 0.02;
    }
  });
  return (
    <mesh ref={ref}>
      <sphereGeometry args={[7.4, 48, 48]} />
      <meshBasicMaterial
        color="#1a3a55"
        transparent
        opacity={0.06}
        side={THREE.BackSide}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </mesh>
  );
}

/* --------------------------- the organism ------------------------- */
function OrganismBody({
  activeId,
  hoveredId,
  setActiveId,
  setHoveredId,
}: {
  activeId: string | null;
  hoveredId: string | null;
  setActiveId: (id: string | null) => void;
  setHoveredId: (id: string | null) => void;
}) {
  const { cells, synapses, indexOf } = useMemo(() => buildOrganism(), []);
  const groupRef = useRef<THREE.Group>(null);
  const targetCenter = useMemo(() => new THREE.Vector3(), []);
  const tmpPos = useMemo(() => new THREE.Vector3(), []);

  const activeIdx = activeId ? indexOf.get(activeId) ?? null : null;
  const relatedActive = useMemo(() => {
    const set = new Set<string>();
    if (activeId) {
      set.add(activeId);
      toolById.get(activeId)?.relationIds.forEach((r) => set.add(r));
      // also inbound
      tools.forEach((tl) => {
        if (tl.relationIds.includes(activeId)) set.add(tl.id);
      });
    }
    return set;
  }, [activeId]);

  useFrame((state, delta) => {
    const g = groupRef.current;
    if (!g) return;
    const t = state.clock.elapsedTime;
    // organism gravitates around the clicked cell: translate the whole
    // body so that cell drifts toward origin (camera focus).
    if (activeIdx !== null) {
      cellPosition(cells[activeIdx], t, tmpPos);
      targetCenter.lerp(tmpPos, Math.min(1, delta * 1.4));
    } else {
      targetCenter.lerp(tmpPos.set(0, 0, 0), Math.min(1, delta * 1.4));
    }
    g.position.lerp(
      tmpPos.set(-targetCenter.x, -targetCenter.y, -targetCenter.z),
      Math.min(1, delta * 2.2),
    );
    // slow living rotation + gentle breathing scale of the whole body
    g.rotation.y += delta * 0.045;
    const sway = 1 + Math.sin(t * 0.5) * 0.02;
    g.scale.setScalar(sway);
  });

  return (
    <group ref={groupRef}>
      <Membrane />
      {synapses.map((syn, i) => {
        const aId = cells[syn.a].tool.id;
        const bId = cells[syn.b].tool.id;
        const act =
          activeId === null
            ? 0
            : relatedActive.has(aId) && relatedActive.has(bId)
              ? 1
              : 0;
        return <SynapseLine key={i} syn={syn} cells={cells} active={act} />;
      })}
      {cells.map((cell) => {
        const isActive = activeId === cell.tool.id;
        const isHover = hoveredId === cell.tool.id;
        return (
          <CellNucleus
            key={cell.tool.id}
            cell={cell}
            active={isActive}
            hovered={isHover}
            onClick={() => setActiveId(isActive ? null : cell.tool.id)}
            onOver={() => setHoveredId(cell.tool.id)}
            onOut={() => setHoveredId(null)}
          />
        );
      })}
      <Sparkles
        count={140}
        scale={[12, 9, 12]}
        size={2.4}
        speed={0.18}
        opacity={0.5}
        color="#bfefff"
      />
    </group>
  );
}

/* ----------------------------- HUD -------------------------------- */
function CellLabel({ tool }: { tool: AITool }) {
  const cat = categoryById.get(tool.category);
  return (
    <div className="pointer-events-none absolute bottom-6 left-1/2 z-10 w-[min(92vw,560px)] -translate-x-1/2">
      <div className="rounded-2xl border border-white/10 bg-black/40 px-5 py-4 backdrop-blur-2xl">
        <div className="flex items-center gap-2">
          <span
            className="h-2.5 w-2.5 rounded-full"
            style={{ background: cat?.color ?? '#fff', boxShadow: `0 0 12px ${cat?.color ?? '#fff'}` }}
          />
          <span className="text-sm font-semibold tracking-tight text-white">{tool.name}</span>
          <span className="text-[11px] uppercase tracking-wide text-white/45">{cat?.shortName ?? tool.category}</span>
        </div>
        <p className="mt-1.5 text-xs leading-relaxed text-white/65">{tool.summary}</p>
        <p className="mt-1 text-[11px] text-white/35">
          {tool.relationIds.length} synapse{tool.relationIds.length === 1 ? '' : 's'} · stage: {tool.stage}
        </p>
      </div>
    </div>
  );
}

/* --------------------------- component ---------------------------- */
export function Organism() {
  const [activeId, setActiveId] = useState<string | null>('founder-os');
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const focusTool = useMemo(
    () => (hoveredId ? toolById.get(hoveredId) : activeId ? toolById.get(activeId) : undefined),
    [hoveredId, activeId],
  );

  const clearActive = useCallback(() => setActiveId(null), []);

  return (
    <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_40%,#071a26_0%,#03060e_55%,#010207_100%)]">
      <div className="absolute inset-x-0 top-0 z-10 h-16" />
      <Canvas
        camera={{ position: [0, 1.6, 13], fov: 52 }}
        gl={{ antialias: true, alpha: true }}
        dpr={[1, 2]}
        onPointerMissed={clearActive}
        style={{ paddingTop: 64 }}
      >
        <color attach="background" args={['#03060e']} />
        <fog attach="fog" args={['#03060e', 12, 26]} />
        <ambientLight intensity={0.4} />
        <OrganismBody
          activeId={activeId}
          hoveredId={hoveredId}
          setActiveId={setActiveId}
          setHoveredId={setHoveredId}
        />
        <EffectComposer>
          <Bloom
            intensity={1.5}
            luminanceThreshold={0.05}
            luminanceSmoothing={0.85}
            mipmapBlur
            radius={0.8}
          />
        </EffectComposer>
      </Canvas>

      {focusTool ? (
        <CellLabel tool={focusTool} />
      ) : (
        <div className="pointer-events-none absolute bottom-6 left-1/2 z-10 -translate-x-1/2 text-xs text-white/40">
          Click a cell — the organism gravitates around it
        </div>
      )}
    </div>
  );
}
