import { useMemo, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  categoryById,
  type AITool,
} from '../../data/ai-tool-universe';

/**
 * Direction L — "Firefly"
 *
 * Emulates the Firefly / Northwestern particle explorer technique: a single
 * THREE.Points BufferGeometry holding tens of thousands of particles, rendered
 * by a custom ShaderMaterial that does size-attenuation LOD (distant = tiny
 * dim motes, near = bright stars) plus a per-point "match" attribute that fades
 * filtered-out points. Depth fog + slow camera drift give parallax. The 49 real
 * AI tools are seeded as bright, labelled stars inside a vast deterministic
 * ambient cloud. Filtering is a procedural Html overlay (category + stage),
 * mirroring Firefly's d3-generated filter UI.
 *
 * No Math.random at render/module time — a seeded mulberry32 PRNG drives every
 * particle. No per-frame allocation — geometry is built once in useMemo and we
 * only mutate uniforms in useFrame.
 */

// ---- seeded PRNG (mulberry32) -------------------------------------------------
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

// ---- constants ----------------------------------------------------------------
const AMBIENT_COUNT = 16000;
const REAL_COUNT = tools.length;
const TOTAL = AMBIENT_COUNT + REAL_COUNT;
const CLOUD_RADIUS = 120;
const STAGES = ['research', 'planning', 'execution', 'approval', 'review'] as const;
type Stage = (typeof STAGES)[number];

const STAGE_COLOR: Record<Stage, string> = {
  research: '#7fffd4',
  planning: '#6ee7ff',
  execution: '#ffd166',
  approval: '#9bff8a',
  review: '#f0abfc',
};

const tmpColor = new THREE.Color();

interface CloudData {
  geometry: THREE.BufferGeometry;
  realPositions: Float32Array;
  realTools: AITool[];
}

// Build the entire point cloud once. Real tools occupy the final REAL_COUNT slots.
function buildCloud(): CloudData {
  const rng = mulberry32(0xf17e_f1a7);
  const positions = new Float32Array(TOTAL * 3);
  const colors = new Float32Array(TOTAL * 3);
  const sizes = new Float32Array(TOTAL);
  const seeds = new Float32Array(TOTAL); // per-point phase for twinkle
  // category index encoded as float; -1 for ambient assigned to nearest cat hue
  const catIndex = new Float32Array(TOTAL);
  const stageIndex = new Float32Array(TOTAL);
  const isReal = new Float32Array(TOTAL);

  const catList = categories;

  // --- ambient particles: a fractal-ish cloud of nebular shells ---
  for (let i = 0; i < AMBIENT_COUNT; i++) {
    // mix of a broad sphere and a flattened galactic disk
    const disk = rng() < 0.55;
    const r = Math.pow(rng(), 0.6) * CLOUD_RADIUS;
    const theta = rng() * Math.PI * 2;
    let x: number;
    let y: number;
    let z: number;
    if (disk) {
      const flat = 0.18 + rng() * 0.12;
      const arm = theta + r * 0.045; // loose spiral
      x = Math.cos(arm) * r;
      z = Math.sin(arm) * r;
      y = (rng() - 0.5) * 2 * r * flat;
    } else {
      const phi = Math.acos(2 * rng() - 1);
      x = r * Math.sin(phi) * Math.cos(theta);
      y = r * Math.sin(phi) * Math.sin(theta) * 0.7;
      z = r * Math.cos(phi);
    }
    positions[i * 3] = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = z;

    // tint ambient particles by the nearest category angle so the cloud carries
    // the universe palette, dimmed.
    const angle = Math.atan2(z, x);
    const cat = catList[Math.floor(((angle + Math.PI) / (Math.PI * 2)) * catList.length) % catList.length];
    tmpColor.set(cat.color);
    const dim = 0.18 + rng() * 0.22;
    colors[i * 3] = tmpColor.r * dim;
    colors[i * 3 + 1] = tmpColor.g * dim;
    colors[i * 3 + 2] = tmpColor.b * dim;

    sizes[i] = 0.5 + rng() * 1.6;
    seeds[i] = rng() * Math.PI * 2;
    catIndex[i] = catList.indexOf(cat);
    stageIndex[i] = Math.floor(rng() * STAGES.length);
    isReal[i] = 0;
  }

  // --- real tool stars: bright, color = category, placed on a structured shell ---
  const realPositions = new Float32Array(REAL_COUNT * 3);
  const realTools: AITool[] = [];
  for (let j = 0; j < REAL_COUNT; j++) {
    const t = tools[j];
    const i = AMBIENT_COUNT + j;
    const cat = categoryById.get(t.category);
    // orbit drives radius, angle drives azimuth, a little jitter for organic feel
    const radius = 14 + t.orbit * 16 + (mulberry32(t.id.length * 2654435761 + j)() - 0.5) * 6;
    const az = (t.angle * Math.PI) / 180;
    const catAngle = ((cat?.angle ?? 0) * Math.PI) / 180;
    const a = az * 0.4 + catAngle * 0.6;
    const tilt = ((mulberry32(j * 40503 + 7)() - 0.5) * 0.9);
    const x = Math.cos(a) * radius;
    const z = Math.sin(a) * radius;
    const y = Math.sin(tilt) * radius * 0.5;
    positions[i * 3] = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = z;
    realPositions[j * 3] = x;
    realPositions[j * 3 + 1] = y;
    realPositions[j * 3 + 2] = z;

    tmpColor.set(cat?.color ?? '#d8faff');
    colors[i * 3] = tmpColor.r;
    colors[i * 3 + 1] = tmpColor.g;
    colors[i * 3 + 2] = tmpColor.b;

    sizes[i] = t.id === 'founder-os' ? 9 : 5.2;
    seeds[i] = (j % 17) * 0.37;
    catIndex[i] = categories.findIndex((c) => c.id === t.category);
    stageIndex[i] = STAGES.indexOf(t.stage as Stage);
    isReal[i] = 1;
    realTools.push(t);
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('aColor', new THREE.BufferAttribute(colors, 3));
  geometry.setAttribute('aSize', new THREE.BufferAttribute(sizes, 1));
  geometry.setAttribute('aSeed', new THREE.BufferAttribute(seeds, 1));
  geometry.setAttribute('aCat', new THREE.BufferAttribute(catIndex, 1));
  geometry.setAttribute('aStage', new THREE.BufferAttribute(stageIndex, 1));
  geometry.setAttribute('aReal', new THREE.BufferAttribute(isReal, 1));
  geometry.computeBoundingSphere();

  return { geometry, realPositions, realTools };
}

// ---- shaders ------------------------------------------------------------------
const VERT = /* glsl */ `
  attribute vec3 aColor;
  attribute float aSize;
  attribute float aSeed;
  attribute float aCat;
  attribute float aStage;
  attribute float aReal;

  uniform float uTime;
  uniform float uPixelRatio;
  uniform float uFilterCat;   // -1 = all
  uniform float uFilterStage; // -1 = all

  varying vec3 vColor;
  varying float vMatch;
  varying float vReal;
  varying float vFog;

  void main() {
    vColor = aColor;
    vReal = aReal;

    float catOk = (uFilterCat < 0.0) ? 1.0 : step(abs(aCat - uFilterCat), 0.5);
    float stageOk = (uFilterStage < 0.0) ? 1.0 : step(abs(aStage - uFilterStage), 0.5);
    vMatch = catOk * stageOk;

    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    float dist = -mv.z;

    // gentle twinkle; real stars pulse stronger on approach
    float tw = 0.7 + 0.3 * sin(uTime * (aReal > 0.5 ? 2.0 : 0.6) + aSeed * 6.2831);

    // size-attenuation LOD: distant points shrink toward 1px
    float size = aSize * tw * (300.0 / max(dist, 1.0)) * uPixelRatio * 0.18;
    gl_PointSize = clamp(size, aReal > 0.5 ? 2.0 : 0.6, 64.0);

    // exponential depth fog
    vFog = 1.0 - clamp(exp(-pow(dist * 0.006, 1.6)), 0.0, 1.0);

    gl_Position = projectionMatrix * mv;
  }
`;

const FRAG = /* glsl */ `
  precision highp float;
  varying vec3 vColor;
  varying float vMatch;
  varying float vReal;
  varying float vFog;
  uniform vec3 uFogColor;

  void main() {
    vec2 uv = gl_PointCoord - 0.5;
    float d = length(uv);
    // soft round sprite with a hot core
    float core = smoothstep(0.5, 0.0, d);
    float glow = smoothstep(0.5, 0.15, d);
    float alpha = core * 0.85 + glow * 0.5;
    if (alpha < 0.01) discard;

    vec3 col = vColor;
    // real stars get a white-hot center
    col = mix(col, vec3(1.0), core * core * (vReal > 0.5 ? 0.55 : 0.18));

    // fade non-matching points (Firefly-style filter)
    float matchFade = mix(0.06, 1.0, vMatch);
    // fog blends toward background, but keeps a little glow
    vec3 final = mix(col, uFogColor, vFog * 0.85);

    gl_FragColor = vec4(final, alpha * matchFade * (1.0 - vFog * 0.55));
  }
`;

// ---- labels for nearby real tools --------------------------------------------
interface LabelsProps {
  realPositions: Float32Array;
  realTools: AITool[];
  hovered: number | null;
  filterCat: number;
  filterStage: number;
}

function ProximityLabels({
  realPositions,
  realTools,
  hovered,
  filterCat,
  filterStage,
}: LabelsProps) {
  const groupRef = useRef<THREE.Group>(null);
  const [near, setNear] = useState<number[]>([]);
  const v = useRef(new THREE.Vector3());

  useFrame((state) => {
    const cam = state.camera;
    const out: number[] = [];
    for (let j = 0; j < realTools.length; j++) {
      v.current.set(
        realPositions[j * 3],
        realPositions[j * 3 + 1],
        realPositions[j * 3 + 2],
      );
      const d = v.current.distanceTo(cam.position);
      if (d < 70 || j === hovered) out.push(j);
    }
    // only update state if the set changed (cheap stringify of small array)
    if (out.length !== near.length || out.some((x, i) => x !== near[i])) {
      setNear(out);
    }
  });

  return (
    <group ref={groupRef}>
      {near.map((j) => {
        const t = realTools[j];
        const cat = categoryById.get(t.category);
        const matchCat = filterCat < 0 || categories.findIndex((c) => c.id === t.category) === filterCat;
        const matchStage = filterStage < 0 || STAGES.indexOf(t.stage as Stage) === filterStage;
        const dim = !(matchCat && matchStage);
        const isHover = j === hovered;
        return (
          <Html
            key={t.id}
            position={[
              realPositions[j * 3],
              realPositions[j * 3 + 1] + 2.4,
              realPositions[j * 3 + 2],
            ]}
            center
            distanceFactor={42}
            style={{ pointerEvents: 'none' }}
            zIndexRange={[20, 0]}
          >
            <div
              style={{
                opacity: dim ? 0.25 : 1,
                transform: isHover ? 'scale(1.08)' : 'scale(1)',
                transition: 'opacity .4s, transform .2s',
                whiteSpace: 'nowrap',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 2,
              }}
            >
              <span
                style={{
                  fontSize: isHover ? 13 : 11,
                  fontWeight: 600,
                  letterSpacing: 0.2,
                  color: '#f4f9ff',
                  textShadow: `0 0 10px ${cat?.color ?? '#fff'}, 0 1px 2px #000`,
                  fontFamily:
                    'ui-sans-serif, -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
                }}
              >
                {t.name}
              </span>
              {isHover && (
                <span
                  style={{
                    fontSize: 10,
                    maxWidth: 220,
                    whiteSpace: 'normal',
                    textAlign: 'center',
                    color: '#aab8d4',
                    background: 'rgba(8,11,24,0.72)',
                    padding: '3px 7px',
                    borderRadius: 7,
                    border: `1px solid ${cat?.glow ?? 'rgba(255,255,255,0.15)'}`,
                    backdropFilter: 'blur(6px)',
                  }}
                >
                  {t.summary}
                </span>
              )}
            </div>
          </Html>
        );
      })}
    </group>
  );
}

// ---- slow cinematic drift -----------------------------------------------------
function CameraDrift() {
  useFrame((state) => {
    const t = state.clock.elapsedTime;
    // subtle parallax breathing layered on top of OrbitControls
    state.camera.position.y += Math.sin(t * 0.18) * 0.012;
  });
  return null;
}

// ---- scene shell --------------------------------------------------------------
function Scene({
  filterCat,
  filterStage,
}: {
  filterCat: number;
  filterStage: number;
}) {
  const [hovered, setHovered] = useState<number | null>(null);
  const cloud = useMemo(() => buildCloud(), []);

  return (
    <>
      <color attach="background" args={['#05060f']} />
      <fog attach="fog" args={['#05060f', 60, 220]} />

      <PointCloudInner
        geometry={cloud.geometry}
        realPositions={cloud.realPositions}
        filterCat={filterCat}
        filterStage={filterStage}
        onHover={setHovered}
      />

      <ProximityLabels
        realPositions={cloud.realPositions}
        realTools={cloud.realTools}
        hovered={hovered}
        filterCat={filterCat}
        filterStage={filterStage}
      />

      <CameraDrift />
      <OrbitControls
        enablePan={false}
        enableDamping
        dampingFactor={0.06}
        rotateSpeed={0.5}
        zoomSpeed={0.8}
        minDistance={18}
        maxDistance={200}
        autoRotate
        autoRotateSpeed={0.18}
      />
    </>
  );
}

// Inner cloud that owns the shader material + hover picking. Geometry is passed
// in from the parent so labels and picking share the same world positions.
interface InnerProps {
  geometry: THREE.BufferGeometry;
  realPositions: Float32Array;
  filterCat: number;
  filterStage: number;
  onHover: (idx: number | null) => void;
}

function PointCloudInner({
  geometry,
  realPositions,
  filterCat,
  filterStage,
  onHover,
}: InnerProps) {
  const matRef = useRef<THREE.ShaderMaterial>(null);
  const pixelRatio = useMemo(
    () => (typeof window !== 'undefined' ? Math.min(window.devicePixelRatio, 2) : 1),
    [],
  );

  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uPixelRatio: { value: pixelRatio },
      uFilterCat: { value: -1 },
      uFilterStage: { value: -1 },
      uFogColor: { value: new THREE.Color('#05060f') },
    }),
    [pixelRatio],
  );

  useFrame((state) => {
    if (matRef.current) {
      matRef.current.uniforms.uTime.value = state.clock.elapsedTime;
      matRef.current.uniforms.uFilterCat.value = filterCat;
      matRef.current.uniforms.uFilterStage.value = filterStage;
    }
  });

  const pickGeo = useMemo(() => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(realPositions, 3));
    return g;
  }, [realPositions]);

  return (
    <group>
      <points geometry={geometry}>
        <shaderMaterial
          ref={matRef}
          uniforms={uniforms}
          vertexShader={VERT}
          fragmentShader={FRAG}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </points>

      <points
        geometry={pickGeo}
        onPointerMove={(e) => onHover(e.index ?? null)}
        onPointerOut={() => onHover(null)}
      >
        <pointsMaterial size={4} transparent opacity={0} depthWrite={false} sizeAttenuation />
      </points>
    </group>
  );
}

// ---- filter overlay (procedural, Firefly-style) -------------------------------
interface OverlayProps {
  filterCat: number;
  setFilterCat: (n: number) => void;
  filterStage: number;
  setFilterStage: (n: number) => void;
}

function FilterOverlay({
  filterCat,
  setFilterCat,
  filterStage,
  setFilterStage,
}: OverlayProps) {
  return (
    <div
      className="pointer-events-none absolute inset-0"
      style={{ paddingTop: 64 }}
    >
      {/* header */}
      <div className="pointer-events-none absolute left-6 top-[72px] select-none">
        <div
          style={{
            fontFamily: 'ui-sans-serif, -apple-system, "SF Pro Display", sans-serif',
            fontSize: 22,
            fontWeight: 700,
            letterSpacing: -0.3,
            color: '#eaf2ff',
            textShadow: '0 0 18px rgba(110,231,255,0.35)',
          }}
        >
          Firefly
        </div>
        <div style={{ fontSize: 12, color: '#7e8db0', marginTop: 2 }}>
          {(AMBIENT_COUNT + REAL_COUNT).toLocaleString()} points · {REAL_COUNT} AI tools · drag to fly
        </div>
      </div>

      {/* category toggles */}
      <div
        className="pointer-events-auto absolute right-5 top-[72px] flex flex-col gap-1.5"
        style={{ width: 184 }}
      >
        <div
          style={{
            fontSize: 10,
            textTransform: 'uppercase',
            letterSpacing: 1.4,
            color: '#6c7b9e',
            marginBottom: 2,
          }}
        >
          Category
        </div>
        <button
          onClick={() => setFilterCat(-1)}
          style={chipStyle(filterCat === -1, '#d8faff')}
        >
          All categories
        </button>
        {categories.map((c, i) => (
          <button
            key={c.id}
            onClick={() => setFilterCat(filterCat === i ? -1 : i)}
            style={chipStyle(filterCat === i, c.color)}
          >
            <span
              style={{
                width: 8,
                height: 8,
                borderRadius: 99,
                background: c.color,
                boxShadow: `0 0 8px ${c.color}`,
                display: 'inline-block',
                marginRight: 8,
              }}
            />
            {c.shortName ?? c.name}
          </button>
        ))}
      </div>

      {/* stage filter */}
      <div className="pointer-events-auto absolute bottom-6 left-1/2 flex -translate-x-1/2 gap-1.5">
        <button
          onClick={() => setFilterStage(-1)}
          style={pillStyle(filterStage === -1, '#d8faff')}
        >
          All stages
        </button>
        {STAGES.map((s, i) => (
          <button
            key={s}
            onClick={() => setFilterStage(filterStage === i ? -1 : i)}
            style={pillStyle(filterStage === i, STAGE_COLOR[s])}
          >
            {s}
          </button>
        ))}
      </div>
    </div>
  );
}

function chipStyle(active: boolean, color: string): CSSProperties {
  return {
    display: 'flex',
    alignItems: 'center',
    fontSize: 12,
    fontWeight: 500,
    padding: '6px 10px',
    borderRadius: 9,
    textAlign: 'left',
    color: active ? '#06080f' : '#c4d0e8',
    background: active ? color : 'rgba(14,18,34,0.62)',
    border: `1px solid ${active ? color : 'rgba(120,140,180,0.18)'}`,
    backdropFilter: 'blur(8px)',
    cursor: 'pointer',
    transition: 'background .2s, color .2s, border-color .2s',
    textTransform: 'capitalize',
  };
}

function pillStyle(active: boolean, color: string): CSSProperties {
  return {
    fontSize: 11,
    fontWeight: 600,
    padding: '6px 12px',
    borderRadius: 99,
    color: active ? '#06080f' : '#b8c6e4',
    background: active ? color : 'rgba(12,16,30,0.66)',
    border: `1px solid ${active ? color : 'rgba(120,140,180,0.2)'}`,
    backdropFilter: 'blur(8px)',
    cursor: 'pointer',
    textTransform: 'capitalize',
    boxShadow: active ? `0 0 14px ${color}66` : 'none',
    transition: 'all .2s',
  };
}

// ---- root ---------------------------------------------------------------------
export function Firefly() {
  const [filterCat, setFilterCat] = useState(-1);
  const [filterStage, setFilterStage] = useState(-1);

  return (
    <div className="absolute inset-0" style={{ background: '#05060f' }}>
      <Canvas
        camera={{ position: [0, 22, 96], fov: 58, near: 0.1, far: 600 }}
        gl={{ antialias: true, alpha: false }}
        dpr={[1, 2]}
        frameloop="always"
      >
        <Scene filterCat={filterCat} filterStage={filterStage} />
      </Canvas>

      <FilterOverlay
        filterCat={filterCat}
        setFilterCat={setFilterCat}
        filterStage={filterStage}
        setFilterStage={setFilterStage}
      />
    </div>
  );
}
