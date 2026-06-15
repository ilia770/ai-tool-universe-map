import { useMemo, useRef, useState, useCallback, useEffect } from 'react';
import { Canvas, useFrame, extend, type ThreeElement } from '@react-three/fiber';
import { shaderMaterial, OrbitControls } from '@react-three/drei';
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
 * A wet, glowing, bioluminescent AI organism. Tools are translucent
 * metaball cell-bodies (a bright nucleus wrapped in a breathing
 * membrane halo); relationIds are synapse filaments that visibly
 * TRANSPORT travelling calcium/light pulses; everything drifts on
 * smooth multi-octave trig "noise" so the motion reads as alive, not
 * scripted. Two parallaxing plankton fields add volumetric depth, a
 * soft core nebula glows behind the body, and a Bloom + Vignette pass
 * makes the whole volume look cinematic and submerged.
 *
 * Clicking a cell makes the organism gravitate/curl around it, dims
 * the unrelated body, and lights the cell's synapse subtree with
 * faster, brighter cascading pulses.
 *
 * Research notes: organic networks (physarum / slime-mold WebGL art,
 * after Jeff Jones 2010 & Sage Jensen) read as alive when (a) motion
 * is noise-driven, (b) veins transport a travelling wave, and (c)
 * nodes glow additively with a soft falloff so the volume looks wet.
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

/* ----------------------- environment hooks ------------------------ */
// Lightweight, SSR-safe reads of viewport + accessibility prefs so we
// can scale the scene down on phones and calm motion when requested.
function readIsPhone(): boolean {
  return typeof window !== 'undefined' && window.innerWidth < 768;
}
function readReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

// Reactively track phone width + reduced-motion. Listener-based, no
// per-frame polling, cleaned up on unmount.
function useEnvironment(): { isPhone: boolean; reducedMotion: boolean } {
  const [env, setEnv] = useState(() => ({
    isPhone: readIsPhone(),
    reducedMotion: readReducedMotion(),
  }));
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const update = () =>
      setEnv({ isPhone: readIsPhone(), reducedMotion: readReducedMotion() });
    const motionMq = window.matchMedia('(prefers-reduced-motion: reduce)');
    window.addEventListener('resize', update);
    motionMq.addEventListener('change', update);
    return () => {
      window.removeEventListener('resize', update);
      motionMq.removeEventListener('change', update);
    };
  }, []);
  return env;
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
  freq: THREE.Vector3;
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
function buildOrganism(): {
  cells: Cell[];
  synapses: Synapse[];
  indexOf: Map<string, number>;
} {
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
        Math.cos(a) * 3.5,
        tilt * 2.3,
        Math.sin(a) * 3.5,
      ),
    );
  });

  tools.forEach((tool, i) => {
    indexOf.set(tool.id, i);
    const cat = categoryById.get(tool.category);
    const center = catCenters.get(tool.category) ?? new THREE.Vector3();
    // orbit 0 (core) sits dead-centre; outer orbits spread further out.
    const spread = tool.orbit === 0 ? 0 : 0.9 + tool.orbit * 0.78;
    const u = rand() * Math.PI * 2;
    const v = Math.acos(2 * rand() - 1);
    const r = spread * (0.55 + rand() * 0.6);
    const pos =
      tool.orbit === 0
        ? new THREE.Vector3(0, 0, 0)
        : new THREE.Vector3(
            center.x + r * Math.sin(v) * Math.cos(u),
            center.y * 0.6 + r * Math.cos(v) * 0.85,
            center.z + r * Math.sin(v) * Math.sin(u),
          );

    const color = new THREE.Color(cat?.color ?? '#9fd8ff');
    const radius =
      tool.orbit === 0 ? 0.7 : 0.22 + (3 - tool.orbit) * 0.07 + rand() * 0.05;

    cells.push({
      tool,
      base: pos,
      color,
      radius,
      phase: rand() * Math.PI * 2,
      drift: new THREE.Vector3(
        0.2 + rand() * 0.24,
        0.16 + rand() * 0.22,
        0.2 + rand() * 0.24,
      ),
      freq: new THREE.Vector3(
        0.28 + rand() * 0.18,
        0.24 + rand() * 0.16,
        0.27 + rand() * 0.18,
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
            (rand() - 0.5) * 1.5,
            (rand() - 0.5) * 1.5 + 0.35,
            (rand() - 0.5) * 1.5,
          ),
        );
      synapses.push({
        a: ai,
        b: bi,
        mid,
        color: ca.color.clone().lerp(cb.color, 0.5),
        speed: 0.32 + rand() * 0.6,
        offset: rand(),
      });
    });
  });

  return { cells, synapses, indexOf };
}

/* ------------------------- cell material -------------------------- */
// Wet bioluminescent cell-body: a hot inner core, a fresnel rim that
// rolls light around the silhouette, animated surface "protoplasm"
// flecks, and a breathing pulse. Additive so overlapping cells melt
// into one glowing metaball-ish volume.
const NucleusMaterial = shaderMaterial(
  {
    uColor: new THREE.Color('#9fd8ff'),
    uTime: 0,
    uPulse: 0,
    uActive: 0,
    uDim: 0,
  },
  /* glsl */ `
    varying vec3 vNormal;
    varying vec3 vView;
    varying vec3 vPos;
    void main() {
      vNormal = normalize(normalMatrix * normal);
      vec4 mv = modelViewMatrix * vec4(position, 1.0);
      vView = normalize(-mv.xyz);
      vPos = position;
      gl_Position = projectionMatrix * mv;
    }
  `,
  /* glsl */ `
    uniform vec3 uColor;
    uniform float uTime;
    uniform float uPulse;
    uniform float uActive;
    uniform float uDim;
    varying vec3 vNormal;
    varying vec3 vView;
    varying vec3 vPos;

    // cheap value-ish noise for protoplasm shimmer
    float hash(vec3 p){ return fract(sin(dot(p, vec3(27.16, 113.5, 57.7))) * 43758.5453); }
    float noise(vec3 p){
      vec3 i = floor(p); vec3 f = fract(p);
      f = f*f*(3.0-2.0*f);
      float n = mix(
        mix(mix(hash(i+vec3(0,0,0)),hash(i+vec3(1,0,0)),f.x),
            mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
        mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),
            mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
      return n;
    }

    void main() {
      float ndv = max(dot(vNormal, vView), 0.0);
      float fres = pow(1.0 - ndv, 2.4);
      float core = pow(ndv, 1.3);
      float breathe = 0.5 + 0.5 * sin(uTime + uPulse);

      // travelling protoplasm shimmer over the surface
      float proto = noise(vPos * 3.2 + vec3(0.0, uTime * 0.5, uPulse));
      proto = smoothstep(0.45, 0.95, proto);

      vec3 col = uColor * (0.32 + core * 1.45 + fres * 1.0);
      col += uColor * breathe * (0.3 + uActive * 1.1);
      col += uColor * proto * (0.35 + uActive * 0.6);

      float alpha = core * 0.95 + fres * 0.8 + proto * 0.18;
      alpha *= 0.5 + 0.5 * breathe;
      alpha *= 1.0 - uDim * 0.78;
      col *= 1.0 - uDim * 0.6;

      gl_FragColor = vec4(col, clamp(alpha, 0.0, 1.0));
    }
  `,
);

// Soft outer membrane halo — a large, very translucent shell that
// makes each cell feel volumetric and wet, fusing neighbours into
// blobs under bloom.
const MembraneMaterial = shaderMaterial(
  {
    uColor: new THREE.Color('#9fd8ff'),
    uTime: 0,
    uPulse: 0,
    uActive: 0,
    uDim: 0,
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
    uniform float uDim;
    varying vec3 vNormal;
    varying vec3 vView;
    void main() {
      float ndv = max(dot(vNormal, vView), 0.0);
      // inverse fresnel: brightest at the rim, hollow centre -> bubble
      float rim = pow(1.0 - ndv, 3.0);
      float breathe = 0.5 + 0.5 * sin(uTime * 0.8 + uPulse);
      float glow = rim * (0.5 + breathe * 0.5) * (0.6 + uActive * 1.2);
      glow *= 1.0 - uDim * 0.85;
      gl_FragColor = vec4(uColor * glow, clamp(glow * 0.9, 0.0, 1.0));
    }
  `,
);

/* ------------------------ synapse material ------------------------ */
// Faint resting vein carrying TWO travelling light pulses with soft
// comet tails — the "calcium wave" that makes the network read as
// alive. Active subtrees pulse brighter and faster.
const SynapseMaterial = shaderMaterial(
  {
    uColor: new THREE.Color('#9fd8ff'),
    uTime: 0,
    uSpeed: 0.5,
    uOffset: 0.0,
    uActive: 0,
    uDim: 0,
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
    uniform float uDim;
    varying float vT;

    // travelling pulse with a soft trailing comet tail
    float pulseAt(float head, float t){
      float d = t - head;            // signed distance behind the head
      d = d - floor(d + 0.5);        // wrap to [-0.5, 0.5]
      float ahead = smoothstep(0.05, 0.0, abs(d));      // sharp head
      float tail = d < 0.0 ? smoothstep(0.28, 0.0, -d) * 0.6 : 0.0; // tail
      return max(ahead, tail);
    }

    void main() {
      float spd = uSpeed * (1.0 + uActive * 1.4);
      float h1 = fract(uTime * spd + uOffset);
      float h2 = fract(uTime * spd + uOffset + 0.5);
      float pulse = max(pulseAt(h1, vT), pulseAt(h2, vT) * (0.5 + uActive * 0.5));

      float rest = 0.07 + 0.12 * uActive;
      float glow = rest + pulse * (1.1 + uActive * 1.8);
      glow *= 1.0 - uDim * 0.82;
      vec3 col = uColor * glow;
      gl_FragColor = vec4(col, clamp(glow, 0.0, 1.0));
    }
  `,
);

extend({ NucleusMaterial, MembraneMaterial, SynapseMaterial });

declare module '@react-three/fiber' {
  interface ThreeElements {
    nucleusMaterial: ThreeElement<typeof NucleusMaterial>;
    membraneMaterial: ThreeElement<typeof MembraneMaterial>;
    synapseMaterial: ThreeElement<typeof SynapseMaterial>;
  }
}

/* ----------------------- shared module geo ------------------------ */
// Synapse vein tessellation: fewer segments on phones keeps the buffer
// updates light. Shared cell geometries (created once at module scope)
// so every nucleus/halo reuses the same GPU buffers.
const SEG_DESKTOP = 48;
const SEG_PHONE = 26;
const sphereGeo = new THREE.SphereGeometry(1, 28, 28);
const haloGeo = new THREE.SphereGeometry(1, 20, 20);

type ShaderUniformRef = THREE.ShaderMaterial & {
  uTime: number;
  uActive: number;
  uDim: number;
  uPulse: number;
};

/* ------------------------ shared motion --------------------------- */
// Noise-driven organic drift (layered trig "noise"). Writes into out.
function cellPosition(cell: Cell, t: number, out: THREE.Vector3): void {
  const s = cell.seed;
  const f = cell.freq;
  out.set(
    cell.base.x +
      Math.sin(t * f.x + s) * cell.drift.x +
      Math.sin(t * f.x * 2.3 + s * 1.3) * cell.drift.x * 0.35,
    cell.base.y +
      Math.sin(t * f.y + s * 1.7) * cell.drift.y +
      Math.cos(t * f.y * 1.9 + s * 0.7) * cell.drift.y * 0.3,
    cell.base.z +
      Math.cos(t * f.z + s * 0.6) * cell.drift.z +
      Math.sin(t * f.z * 2.1 + s * 1.1) * cell.drift.z * 0.32,
  );
}

/* ---------------------------- synapse ----------------------------- */
function SynapseLine({
  syn,
  cells,
  active,
  dim,
  seg,
  motion,
}: {
  syn: Synapse;
  cells: Cell[];
  active: number;
  dim: number;
  seg: number;
  motion: number;
}) {
  const matRef = useRef<ShaderUniformRef>(null);
  const posRef = useRef<THREE.BufferAttribute>(null);
  const ca = cells[syn.a];
  const cb = cells[syn.b];

  // Rebuild the vein buffer when the segment budget changes (e.g. on a
  // viewport rotate between phone / tablet widths).
  const geom = useMemo(() => {
    const g = new THREE.BufferGeometry();
    const positions = new Float32Array((seg + 1) * 3);
    const ts = new Float32Array(seg + 1);
    for (let i = 0; i <= seg; i++) ts[i] = i / seg;
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    g.setAttribute('aT', new THREE.BufferAttribute(ts, 1));
    return g;
  }, [seg]);

  // Dispose the previous geometry when seg changes / on unmount so we
  // don't leak GPU buffers.
  useEffect(() => () => geom.dispose(), [geom]);

  // scratch vectors (allocated once, mutated in frame loop)
  const tmp = useMemo(() => new THREE.Vector3(), []);
  const a0 = useMemo(() => new THREE.Vector3(), []);
  const b0 = useMemo(() => new THREE.Vector3(), []);

  // eased active / dim so subtree lighting fades in smoothly
  const actRef = useRef(active);
  const dimRef = useRef(dim);

  useFrame((state, delta) => {
    // scaled clock so veins, cells and pulses all share one motion basis
    const t = state.clock.elapsedTime * motion;
    const k = Math.min(1, delta * 4);
    actRef.current += (active - actRef.current) * k;
    dimRef.current += (dim - dimRef.current) * k;
    if (matRef.current) {
      matRef.current.uTime = t;
      matRef.current.uActive = actRef.current;
      matRef.current.uDim = dimRef.current;
    }
    const attr = posRef.current;
    if (!attr) return;
    // live endpoints follow each cell's breathing position (same time basis)
    cellPosition(ca, t, a0);
    cellPosition(cb, t, b0);
    const arr = attr.array as Float32Array;
    for (let i = 0; i <= seg; i++) {
      const u = i / seg;
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
        <bufferAttribute
          ref={posRef}
          attach="attributes-position"
          args={[geom.getAttribute('position').array as Float32Array, 3]}
        />
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

/* ------------------------------ cell ------------------------------ */
function CellNucleus({
  cell,
  active,
  hovered,
  dim,
  motion,
  allowHover,
  onClick,
  onOver,
  onOut,
}: {
  cell: Cell;
  active: boolean;
  hovered: boolean;
  dim: boolean;
  motion: number;
  allowHover: boolean;
  onClick: () => void;
  onOver: () => void;
  onOut: () => void;
}) {
  const groupRef = useRef<THREE.Group>(null);
  const coreRef = useRef<THREE.Mesh>(null);
  const haloRef = useRef<THREE.Mesh>(null);
  const hitRef = useRef<THREE.Mesh>(null);
  const nucRef = useRef<ShaderUniformRef>(null);
  const memRef = useRef<ShaderUniformRef>(null);
  const pos = useMemo(() => new THREE.Vector3(), []);
  // comfortable minimum tap radius so small cells stay easy to hit on touch
  const hitRadius = useMemo(() => Math.max(cell.radius * 1.9, 0.55), [cell.radius]);
  const emphRef = useRef(1);
  const dimRef = useRef(0);
  const actRef = useRef(0);

  useFrame((state, delta) => {
    const raw = state.clock.elapsedTime;
    const t = raw * motion;
    cellPosition(cell, t, pos);
    const g = groupRef.current;
    if (g) g.position.copy(pos);

    // eased emphasis + dim + active so selection feels liquid, not snappy
    const targetEmph = (active ? 1.5 : 1) * (hovered ? 1.18 : 1);
    emphRef.current += (targetEmph - emphRef.current) * Math.min(1, delta * 6);
    const targetDim = dim ? 1 : 0;
    dimRef.current += (targetDim - dimRef.current) * Math.min(1, delta * 5);
    const targetAct = active ? 1 : hovered ? 0.5 : 0;
    actRef.current += (targetAct - actRef.current) * Math.min(1, delta * 6);

    const breathe = 1 + Math.sin(t * 0.9 + cell.phase) * 0.07;
    const baseS = cell.radius * breathe * emphRef.current;
    if (coreRef.current) coreRef.current.scale.setScalar(baseS);
    if (haloRef.current) haloRef.current.scale.setScalar(baseS * 2.2);
    // keep the invisible hit-proxy at least the comfortable tap size
    if (hitRef.current) hitRef.current.scale.setScalar(Math.max(baseS, hitRadius));

    const act = actRef.current;
    if (nucRef.current) {
      nucRef.current.uTime = t * 1.6;
      nucRef.current.uPulse = cell.phase;
      nucRef.current.uActive = act;
      nucRef.current.uDim = dimRef.current;
    }
    if (memRef.current) {
      memRef.current.uTime = t;
      memRef.current.uPulse = cell.phase;
      memRef.current.uActive = act;
      memRef.current.uDim = dimRef.current;
    }
  });

  return (
    <group ref={groupRef}>
      {/* soft volumetric membrane halo */}
      <mesh ref={haloRef} geometry={haloGeo} raycast={() => null}>
        <membraneMaterial
          ref={memRef}
          uColor={cell.color}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      {/* wet glowing core (visual only — hit handled by the proxy below) */}
      <mesh ref={coreRef} geometry={sphereGeo} raycast={() => null}>
        <nucleusMaterial
          ref={nucRef}
          uColor={cell.color}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      {/* invisible comfortable-size tap / hit target */}
      <mesh
        ref={hitRef}
        geometry={haloGeo}
        onClick={(e) => {
          e.stopPropagation();
          onClick();
        }}
        onPointerOver={(e) => {
          if (!allowHover) return;
          e.stopPropagation();
          onOver();
        }}
        onPointerOut={allowHover ? onOut : undefined}
      >
        <meshBasicMaterial transparent opacity={0} depthWrite={false} />
      </mesh>
    </group>
  );
}

/* ----------------------- breathing membrane ----------------------- */
// Outer cytoplasm shell — the skin of the whole organism.
function OuterMembrane({ motion }: { motion: number }) {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((state) => {
    const t = state.clock.elapsedTime * motion;
    if (ref.current) {
      const s = 1 + Math.sin(t * 0.4) * 0.045;
      ref.current.scale.set(s, s * 0.92, s);
      ref.current.rotation.y = t * 0.02;
    }
  });
  return (
    <mesh ref={ref} raycast={() => null}>
      <sphereGeometry args={[7.6, 48, 48]} />
      <meshBasicMaterial
        color="#1d4863"
        transparent
        opacity={0.06}
        side={THREE.BackSide}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </mesh>
  );
}

/* --------------------------- core nebula -------------------------- */
// Soft glowing heart behind the core cell — gives the body a centre of
// light and depth.
function CoreNebula({ motion }: { motion: number }) {
  const ref = useRef<THREE.Mesh>(null);
  const matRef = useRef<THREE.MeshBasicMaterial>(null);
  useFrame((state) => {
    const t = state.clock.elapsedTime * motion;
    if (ref.current) {
      const s = 1 + Math.sin(t * 0.6) * 0.12;
      ref.current.scale.setScalar(s);
    }
    if (matRef.current) {
      matRef.current.opacity = 0.1 + Math.sin(t * 0.6) * 0.03;
    }
  });
  return (
    <mesh ref={ref} raycast={() => null}>
      <sphereGeometry args={[2.4, 32, 32]} />
      <meshBasicMaterial
        ref={matRef}
        color="#8fe6ff"
        transparent
        opacity={0.1}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </mesh>
  );
}

/* --------------------------- plankton ----------------------------- */
// Floating particle dust at a given depth band, drifting on noise.
// Parallax comes from running two of these at different scales/speeds.
function Plankton({
  count,
  radius,
  size,
  color,
  speed,
  seed,
  motion,
}: {
  count: number;
  radius: number;
  size: number;
  color: string;
  speed: number;
  seed: number;
  motion: number;
}) {
  const ref = useRef<THREE.Points>(null);

  const { geometry, bases, phases } = useMemo(() => {
    const rand = mulberry32(seed);
    const positions = new Float32Array(count * 3);
    const basesArr = new Float32Array(count * 3);
    const phasesArr = new Float32Array(count);
    for (let i = 0; i < count; i++) {
      const u = rand() * Math.PI * 2;
      const v = Math.acos(2 * rand() - 1);
      const r = radius * (0.4 + rand() * 0.6);
      const x = r * Math.sin(v) * Math.cos(u);
      const y = r * Math.cos(v);
      const z = r * Math.sin(v) * Math.sin(u);
      positions[i * 3] = x;
      positions[i * 3 + 1] = y;
      positions[i * 3 + 2] = z;
      basesArr[i * 3] = x;
      basesArr[i * 3 + 1] = y;
      basesArr[i * 3 + 2] = z;
      phasesArr[i] = rand() * Math.PI * 2;
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    return { geometry: g, bases: basesArr, phases: phasesArr };
  }, [count, radius, seed]);

  // dispose the points buffer when the count changes / on unmount
  useEffect(() => () => geometry.dispose(), [geometry]);

  useFrame((state) => {
    const pts = ref.current;
    if (!pts) return;
    const t = state.clock.elapsedTime * speed * motion;
    const attr = pts.geometry.getAttribute('position') as THREE.BufferAttribute;
    const arr = attr.array as Float32Array;
    for (let i = 0; i < count; i++) {
      const ph = phases[i];
      arr[i * 3] = bases[i * 3] + Math.sin(t + ph) * 0.3;
      arr[i * 3 + 1] = bases[i * 3 + 1] + Math.cos(t * 0.8 + ph) * 0.3;
      arr[i * 3 + 2] = bases[i * 3 + 2] + Math.sin(t * 0.6 + ph * 1.3) * 0.3;
    }
    attr.needsUpdate = true;
  });

  return (
    <points ref={ref} geometry={geometry} raycast={() => null}>
      <pointsMaterial
        color={color}
        size={size}
        sizeAttenuation
        transparent
        opacity={0.55}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  );
}

/* --------------------------- the organism ------------------------- */
function OrganismBody({
  activeId,
  hoveredId,
  setActiveId,
  setHoveredId,
  pointer,
  isPhone,
  reducedMotion,
}: {
  activeId: string | null;
  hoveredId: string | null;
  setActiveId: (id: string | null) => void;
  setHoveredId: (id: string | null) => void;
  pointer: React.RefObject<{ x: number; y: number }>;
  isPhone: boolean;
  reducedMotion: boolean;
}) {
  const { cells, synapses, indexOf } = useMemo(() => buildOrganism(), []);
  const groupRef = useRef<THREE.Group>(null);
  const targetCenter = useMemo(() => new THREE.Vector3(), []);
  const tmpPos = useMemo(() => new THREE.Vector3(), []);

  // global motion scalar: 1 = lively, ~0.35 = calmed for reduced-motion.
  const motion = reducedMotion ? 0.35 : 1;
  const seg = isPhone ? SEG_PHONE : SEG_DESKTOP;
  // hover only matters with a precise pointer; touch uses tap-to-select.
  const allowHover = !isPhone;

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

  // smooth scalar that goes 1 -> 0 while a cell is focused, so the body's
  // auto-rotation & parallax ease to a near-stop instead of snapping.
  const liveRef = useRef(1);

  useFrame((state, delta) => {
    const g = groupRef.current;
    if (!g) return;
    const t = state.clock.elapsedTime * motion;
    const k = Math.min(1, delta * 2.2);

    const liveTarget = activeIdx !== null ? 0 : 1;
    liveRef.current += (liveTarget - liveRef.current) * Math.min(1, delta * 3);
    const live = liveRef.current;

    // organism gravitates around the clicked cell: translate the whole
    // body so that cell drifts toward origin (camera focus).
    if (activeIdx !== null) {
      cellPosition(cells[activeIdx], t, tmpPos);
      targetCenter.lerp(tmpPos, k * 0.7);
    } else {
      targetCenter.lerp(tmpPos.set(0, 0, 0), k * 0.7);
    }
    // gentle pointer parallax (faded out while focusing) on top of centring
    const px = (pointer.current ? pointer.current.x : 0) * live;
    const py = (pointer.current ? pointer.current.y : 0) * live;
    g.position.lerp(
      tmpPos.set(
        -targetCenter.x + px * 0.6,
        -targetCenter.y - py * 0.5,
        -targetCenter.z,
      ),
      k,
    );
    // slow living rotation eases toward a stop while focused; faint tilt
    g.rotation.y += delta * 0.045 * live * motion;
    g.rotation.x += (py * 0.18 - g.rotation.x) * Math.min(1, delta * 1.5);
    const sway = 1 + Math.sin(t * 0.5) * 0.02;
    g.scale.setScalar(sway);
  });

  // scale ambient particle budgets down on phones to keep it light
  const farCount = isPhone ? 70 : 150;
  const nearCount = isPhone ? 42 : 90;

  return (
    <group ref={groupRef}>
      <OuterMembrane motion={motion} />
      <CoreNebula motion={motion} />
      {synapses.map((syn, i) => {
        const aId = cells[syn.a].tool.id;
        const bId = cells[syn.b].tool.id;
        const inTree =
          relatedActive.has(aId) && relatedActive.has(bId);
        const act = activeId === null ? 0 : inTree ? 1 : 0;
        const dim = activeId === null ? 0 : inTree ? 0 : 1;
        return (
          <SynapseLine
            key={i}
            syn={syn}
            cells={cells}
            active={act}
            dim={dim}
            seg={seg}
            motion={motion}
          />
        );
      })}
      {cells.map((cell) => {
        const isActive = activeId === cell.tool.id;
        const isHover = hoveredId === cell.tool.id;
        const isDim =
          activeId !== null && !relatedActive.has(cell.tool.id);
        return (
          <CellNucleus
            key={cell.tool.id}
            cell={cell}
            active={isActive}
            hovered={isHover}
            dim={isDim}
            motion={motion}
            allowHover={allowHover}
            onClick={() => setActiveId(isActive ? null : cell.tool.id)}
            onOver={() => setHoveredId(cell.tool.id)}
            onOut={() => setHoveredId(null)}
          />
        );
      })}
      <Plankton
        count={farCount}
        radius={11}
        size={0.09}
        color="#bfefff"
        speed={0.14}
        seed={0xa11ce}
        motion={motion}
      />
      <Plankton
        count={nearCount}
        radius={6.5}
        size={0.05}
        color="#7fffd4"
        speed={0.22}
        seed={0xb0b}
        motion={motion}
      />
    </group>
  );
}

/* ----------------------------- HUD -------------------------------- */
// Liquid-glass detail card. Always mounted; `show` drives a smooth eased
// fade + rise. `tool` is held during fade-out so the text never blanks
// mid-transition.
function CellLabel({ tool, show }: { tool: AITool | undefined; show: boolean }) {
  const cat = tool ? categoryById.get(tool.category) : undefined;
  return (
    <div
      className={`pointer-events-none absolute bottom-[max(1.5rem,env(safe-area-inset-bottom))] left-1/2 z-10 w-[min(92vw,560px)] -translate-x-1/2 transition-all duration-500 ease-out ${
        show
          ? 'translate-y-0 opacity-100'
          : 'pointer-events-none translate-y-3 opacity-0'
      }`}
    >
      <div className="rounded-2xl border border-white/10 bg-white/[0.07] px-5 py-4 shadow-[0_8px_40px_-12px_rgba(0,0,0,0.7)] backdrop-blur-2xl">
        <div className="flex items-center gap-2">
          <span
            className="h-2.5 w-2.5 shrink-0 rounded-full"
            style={{
              background: cat?.color ?? '#fff',
              boxShadow: `0 0 12px ${cat?.color ?? '#fff'}`,
            }}
          />
          <span className="truncate text-sm font-semibold tracking-tight text-white">
            {tool?.name ?? ''}
          </span>
          <span className="ml-auto shrink-0 text-[11px] uppercase tracking-wide text-white/45">
            {cat?.shortName ?? tool?.category ?? ''}
          </span>
        </div>
        <p className="mt-1.5 text-xs leading-relaxed text-white/65">
          {tool?.summary ?? ''}
        </p>
        <p className="mt-1 text-[11px] text-white/35">
          {tool ? tool.relationIds.length : 0} synapse
          {tool && tool.relationIds.length === 1 ? '' : 's'} · stage:{' '}
          {tool?.stage ?? ''}
        </p>
      </div>
    </div>
  );
}

/* --------------------------- component ---------------------------- */
export function Organism() {
  const [activeId, setActiveId] = useState<string | null>('founder-os');
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const pointer = useRef({ x: 0, y: 0 });
  const { isPhone, reducedMotion } = useEnvironment();

  const focusTool = useMemo(
    () =>
      hoveredId
        ? toolById.get(hoveredId)
        : activeId
          ? toolById.get(activeId)
          : undefined,
    [hoveredId, activeId],
  );

  // Hold the last shown tool so the glass card can fade OUT smoothly with
  // its content intact instead of blanking the moment selection clears.
  // React-sanctioned "adjust state during render": when a new tool comes
  // in we store it; on clear we keep the previous value for the fade-out.
  const [heldTool, setHeldTool] = useState<AITool | undefined>(focusTool);
  if (focusTool && focusTool !== heldTool) setHeldTool(focusTool);

  const clearActive = useCallback(() => setActiveId(null), []);
  const onPointerMove = useCallback((e: React.PointerEvent) => {
    // skip on touch — drag should orbit the body, not parallax-jitter it.
    if (e.pointerType === 'touch') return;
    pointer.current.x = (e.clientX / window.innerWidth) * 2 - 1;
    pointer.current.y = (e.clientY / window.innerHeight) * 2 - 1;
  }, []);

  return (
    <div
      className="absolute inset-0 touch-none select-none bg-[radial-gradient(ellipse_at_50%_38%,#082031_0%,#040912_52%,#010207_100%)]"
      onPointerMove={onPointerMove}
    >
      <div className="absolute inset-x-0 top-0 z-10 h-16" />
      <Canvas
        camera={{ position: [0, 1.6, 13], fov: 52 }}
        gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }}
        dpr={[1, 2]}
        onPointerMissed={clearActive}
        style={{ paddingTop: 64 }}
      >
        <color attach="background" args={['#03060e']} />
        <fog attach="fog" args={['#03060e', 13, 27]} />
        <ambientLight intensity={0.4} />
        <OrganismBody
          activeId={activeId}
          hoveredId={hoveredId}
          setActiveId={setActiveId}
          setHoveredId={setHoveredId}
          pointer={pointer}
          isPhone={isPhone}
          reducedMotion={reducedMotion}
        />
        {/* Touch-friendly orbit: drag = rotate, pinch = zoom. No pan so the
            body stays framed; damping makes every gesture glide to a stop. */}
        <OrbitControls
          makeDefault
          enablePan={false}
          enableDamping
          dampingFactor={0.08}
          rotateSpeed={0.55}
          zoomSpeed={0.6}
          minDistance={7}
          maxDistance={20}
          autoRotate={false}
        />
        {/* No full-screen post-processing: the cells' own fresnel + emissive
            glow already reads as bioluminescent, and skipping the composer
            keeps it light for mobile / App-Store framerates. */}
      </Canvas>

      <CellLabel tool={heldTool} show={!!focusTool} />
      <div
        className={`pointer-events-none absolute bottom-[max(1.5rem,env(safe-area-inset-bottom))] left-1/2 z-10 -translate-x-1/2 rounded-full border border-white/10 bg-white/[0.06] px-4 py-2 text-xs text-white/55 backdrop-blur-xl transition-opacity duration-500 ease-out ${
          focusTool ? 'opacity-0' : 'opacity-100'
        }`}
      >
        Tap a cell · drag to orbit
      </div>
    </div>
  );
}
