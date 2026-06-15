import { useMemo, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  categoryById,
  toolById,
  type AITool,
} from '../../data/ai-tool-universe';

/**
 * Direction L — "Firefly"
 *
 * A Firefly / Northwestern-style particle explorer. One THREE.Points cloud
 * holds ~14k deterministic ambient motes plus the 49 REAL AI-tool stars. A
 * custom ShaderMaterial does size-attenuation LOD (far = dim dust, near =
 * bright stars), depth fog and twinkle. The 49 tools are the heroes: visibly
 * larger, category-coloured, ringed with a halo, and labelled when close.
 *
 * The four product goals are made explicit:
 *  1. REAL tools dominate — large glowing stars + near-always-on labels.
 *  2. Ambient field is clearly SECONDARY — small, dim, slow twinkle, fog.
 *  3. Filtering is OBVIOUS — a smoothly animated mix dramatically fades
 *     non-matching stars, re-emphasises matches, and shows a live count.
 *  4. LOD reads as a data-cloud — zoom out = constellation of tool-stars,
 *     zoom in = labels, summaries and relation lines.
 *
 * No Math.random at render/module time — a seeded mulberry32 PRNG drives every
 * particle. No per-frame allocation — geometry is built once in useMemo and we
 * mutate uniforms / refs in useFrame. hash routing uses history.replaceState.
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
const AMBIENT_COUNT = 14000;
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

interface RealStar {
  tool: AITool;
  pos: THREE.Vector3;
  catIndex: number;
  stageIndex: number;
  color: string;
}

interface CloudData {
  geometry: THREE.BufferGeometry;
  realPositions: Float32Array;
  realStars: RealStar[];
  // index of a real-tool id -> slot in realStars (for relation lines)
  realIndexById: Map<string, number>;
}

// Build the entire point cloud once. Real tools occupy the final REAL_COUNT slots.
function buildCloud(): CloudData {
  const rng = mulberry32(0xf17e_f1a7);
  const positions = new Float32Array(TOTAL * 3);
  const colors = new Float32Array(TOTAL * 3);
  const sizes = new Float32Array(TOTAL);
  const seeds = new Float32Array(TOTAL); // per-point phase for twinkle
  const catIndex = new Float32Array(TOTAL);
  const stageIndex = new Float32Array(TOTAL);
  const isReal = new Float32Array(TOTAL);

  const catList = categories;

  // --- ambient particles: a flattened galactic disk + a softer halo sphere ---
  for (let i = 0; i < AMBIENT_COUNT; i++) {
    const disk = rng() < 0.62;
    const r = Math.pow(rng(), 0.55) * CLOUD_RADIUS;
    const theta = rng() * Math.PI * 2;
    let x: number;
    let y: number;
    let z: number;
    if (disk) {
      const flat = 0.14 + rng() * 0.1;
      const arm = theta + r * 0.05; // loose spiral arms
      x = Math.cos(arm) * r;
      z = Math.sin(arm) * r;
      y = (rng() - 0.5) * 2 * r * flat;
    } else {
      const phi = Math.acos(2 * rng() - 1);
      x = r * Math.sin(phi) * Math.cos(theta);
      y = r * Math.sin(phi) * Math.sin(theta) * 0.62;
      z = r * Math.cos(phi);
    }
    positions[i * 3] = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = z;

    // tint ambient particles by the nearest category angle so the cloud carries
    // the universe palette, heavily dimmed so it never competes with the heroes.
    const angle = Math.atan2(z, x);
    const cat = catList[Math.floor(((angle + Math.PI) / (Math.PI * 2)) * catList.length) % catList.length];
    tmpColor.set(cat.color);
    // lift toward a cool white so dust feels atmospheric, then dim hard.
    const dim = 0.1 + rng() * 0.16;
    colors[i * 3] = (tmpColor.r * 0.6 + 0.4) * dim;
    colors[i * 3 + 1] = (tmpColor.g * 0.6 + 0.45) * dim;
    colors[i * 3 + 2] = (tmpColor.b * 0.6 + 0.55) * dim;

    // varied sizes: mostly tiny dust, a few brighter background sparks.
    sizes[i] = rng() < 0.06 ? 1.4 + rng() * 1.4 : 0.35 + rng() * 0.9;
    seeds[i] = rng() * Math.PI * 2;
    catIndex[i] = catList.indexOf(cat);
    stageIndex[i] = Math.floor(rng() * STAGES.length);
    isReal[i] = 0;
  }

  // --- real tool stars: bright, color = category, on a structured shell ---
  const realPositions = new Float32Array(REAL_COUNT * 3);
  const realStars: RealStar[] = [];
  const realIndexById = new Map<string, number>();
  for (let j = 0; j < REAL_COUNT; j++) {
    const t = tools[j];
    const i = AMBIENT_COUNT + j;
    const cat = categoryById.get(t.category);
    // orbit drives radius, angle drives azimuth, deterministic jitter for life
    const jit = mulberry32(t.id.length * 2654435761 + j * 9176);
    const radius = t.orbit === 0 ? 0 : 13 + t.orbit * 15 + (jit() - 0.5) * 5;
    const az = (t.angle * Math.PI) / 180;
    const catAngle = ((cat?.angle ?? 0) * Math.PI) / 180;
    const a = az * 0.45 + catAngle * 0.55;
    const tilt = (jit() - 0.5) * 0.85;
    const x = Math.cos(a) * radius;
    const z = Math.sin(a) * radius;
    const y = Math.sin(tilt) * radius * 0.42;
    positions[i * 3] = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = z;
    realPositions[j * 3] = x;
    realPositions[j * 3 + 1] = y;
    realPositions[j * 3 + 2] = z;

    const colorHex = cat?.color ?? '#d8faff';
    tmpColor.set(colorHex);
    colors[i * 3] = tmpColor.r;
    colors[i * 3 + 1] = tmpColor.g;
    colors[i * 3 + 2] = tmpColor.b;

    // Founder OS is the bright core; the rest are clearly larger than dust.
    sizes[i] = t.id === 'founder-os' ? 14 : 7.5;
    seeds[i] = (j % 17) * 0.37;
    const cIdx = categories.findIndex((c) => c.id === t.category);
    const sIdx = STAGES.indexOf(t.stage as Stage);
    catIndex[i] = cIdx;
    stageIndex[i] = sIdx;
    isReal[i] = 1;

    realIndexById.set(t.id, j);
    realStars.push({
      tool: t,
      pos: new THREE.Vector3(x, y, z),
      catIndex: cIdx,
      stageIndex: sIdx,
      color: colorHex,
    });
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

  return { geometry, realPositions, realStars, realIndexById };
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
  uniform float uFilterMix;   // 0 = no filter active, 1 = fully filtered

  varying vec3 vColor;
  varying float vMatch;
  varying float vReal;
  varying float vFog;
  varying float vTwinkle;

  void main() {
    vColor = aColor;
    vReal = aReal;

    float catOk = (uFilterCat < 0.0) ? 1.0 : step(abs(aCat - uFilterCat), 0.5);
    float stageOk = (uFilterStage < 0.0) ? 1.0 : step(abs(aStage - uFilterStage), 0.5);
    // 1 = matches, 0 = does not. Blended by uFilterMix so transitions are smooth.
    vMatch = mix(1.0, catOk * stageOk, uFilterMix);

    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    float dist = -mv.z;

    // gentle twinkle; real stars pulse a touch stronger / faster.
    float tw = 0.72 + 0.28 * sin(uTime * (aReal > 0.5 ? 1.7 : 0.5) + aSeed * 6.2831);
    vTwinkle = tw;

    // size-attenuation LOD: distant points shrink toward sub-pixel dust.
    // Matched (and unfiltered) real stars get a size boost so they pop forward;
    // filtered-out points additionally shrink so the cloud visibly re-weights.
    float emphasize = aReal > 0.5 ? (1.0 + vMatch * 0.45) : 1.0;
    float shrink = mix(1.0, 0.35, (1.0 - vMatch) * uFilterMix);
    float size = aSize * tw * emphasize * shrink * (320.0 / max(dist, 1.0)) * uPixelRatio * 0.2;
    gl_PointSize = clamp(size, aReal > 0.5 ? 2.5 : 0.55, 120.0);

    // exponential depth fog
    vFog = 1.0 - clamp(exp(-pow(dist * 0.0055, 1.6)), 0.0, 1.0);

    gl_Position = projectionMatrix * mv;
  }
`;

const FRAG = /* glsl */ `
  precision highp float;
  varying vec3 vColor;
  varying float vMatch;
  varying float vReal;
  varying float vFog;
  varying float vTwinkle;
  uniform vec3 uFogColor;

  void main() {
    vec2 uv = gl_PointCoord - 0.5;
    float d = length(uv);

    // Real stars: hot core + bright halo + a faint diffraction ring.
    // Ambient dust: soft round mote.
    float core = smoothstep(0.5, 0.0, d);
    float glow = smoothstep(0.5, 0.06, d);

    float ring = vReal > 0.5
      ? smoothstep(0.34, 0.30, abs(d - 0.40)) * 0.5
      : 0.0;

    float baseAlpha = vReal > 0.5
      ? core * 0.95 + glow * 0.55 + ring
      : core * 0.7 + glow * 0.35;
    if (baseAlpha < 0.01) discard;

    vec3 col = vColor;
    // real stars get a white-hot center; dust stays tinted.
    col = mix(col, vec3(1.0), core * core * (vReal > 0.5 ? 0.6 : 0.12));
    // slight chromatic lift on twinkle peak for sparkle.
    col += vColor * (vTwinkle - 0.72) * (vReal > 0.5 ? 0.6 : 0.25);

    // fade non-matching points strongly (Firefly-style filter).
    float matchFade = mix(0.05, 1.0, vMatch);

    // fog blends toward background but keeps a little glow.
    vec3 final = mix(col, uFogColor, vFog * 0.82);

    gl_FragColor = vec4(final, baseAlpha * matchFade * (1.0 - vFog * 0.5));
  }
`;

// ---- relation lines for the hovered star -------------------------------------
function RelationLines({
  hovered,
  realStars,
  realIndexById,
}: {
  hovered: number | null;
  realStars: RealStar[];
  realIndexById: Map<string, number>;
}) {
  const geo = useMemo(() => {
    if (hovered == null) return null;
    const src = realStars[hovered];
    if (!src) return null;
    const pts: number[] = [];
    for (const rid of src.tool.relationIds) {
      const tIdx = realIndexById.get(rid);
      if (tIdx == null) continue;
      const dst = realStars[tIdx];
      pts.push(src.pos.x, src.pos.y, src.pos.z, dst.pos.x, dst.pos.y, dst.pos.z);
    }
    if (pts.length === 0) return null;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(pts), 3));
    return g;
  }, [hovered, realStars, realIndexById]);

  if (!geo) return null;
  const color = realStars[hovered ?? 0]?.color ?? '#ffffff';
  return (
    <lineSegments geometry={geo}>
      <lineBasicMaterial
        color={color}
        transparent
        opacity={0.5}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </lineSegments>
  );
}

// ---- labels for nearby / hovered real tools ----------------------------------
interface LabelsProps {
  realStars: RealStar[];
  hovered: number | null;
  filterCat: number;
  filterStage: number;
}

function ProximityLabels({ realStars, hovered, filterCat, filterStage }: LabelsProps) {
  // Each entry: index + a "detail" flag (close enough to show the summary).
  const [near, setNear] = useState<{ j: number; detail: boolean }[]>([]);
  const nearRef = useRef<{ j: number; detail: boolean }[]>([]);

  useFrame((state) => {
    const cam = state.camera;
    const out: { j: number; detail: boolean }[] = [];
    for (let j = 0; j < realStars.length; j++) {
      const d = realStars[j].pos.distanceTo(cam.position);
      // Always-on labels for the closest ring of stars; detail when really close.
      if (d < 88 || j === hovered) {
        out.push({ j, detail: d < 48 || j === hovered });
      }
    }
    const prev = nearRef.current;
    const changed =
      out.length !== prev.length ||
      out.some((x, i) => x.j !== prev[i]?.j || x.detail !== prev[i]?.detail);
    if (changed) {
      nearRef.current = out;
      setNear(out);
    }
  });

  return (
    <group>
      {near.map(({ j, detail }) => {
        const star = realStars[j];
        const t = star.tool;
        const cat = categoryById.get(t.category);
        const matchCat = filterCat < 0 || star.catIndex === filterCat;
        const matchStage = filterStage < 0 || star.stageIndex === filterStage;
        const dim = !(matchCat && matchStage);
        const isHover = j === hovered;
        return (
          <Html
            key={t.id}
            position={[star.pos.x, star.pos.y + 2.6, star.pos.z]}
            center
            distanceFactor={44}
            style={{ pointerEvents: 'none' }}
            zIndexRange={[isHover ? 60 : 20, 0]}
          >
            <div
              style={{
                opacity: dim ? 0.18 : 1,
                transform: isHover ? 'scale(1.1)' : 'scale(1)',
                transition: 'opacity .45s ease, transform .22s ease',
                whiteSpace: 'nowrap',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 3,
                filter: dim ? 'saturate(0.5)' : 'none',
              }}
            >
              <span
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 5,
                  fontSize: isHover ? 14 : 11.5,
                  fontWeight: 600,
                  letterSpacing: 0.2,
                  color: '#f4f9ff',
                  textShadow: `0 0 12px ${cat?.color ?? '#fff'}, 0 1px 3px #000`,
                  fontFamily:
                    'ui-sans-serif, -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
                }}
              >
                <span
                  style={{
                    width: isHover ? 7 : 5,
                    height: isHover ? 7 : 5,
                    borderRadius: 99,
                    background: star.color,
                    boxShadow: `0 0 8px ${star.color}, 0 0 14px ${star.color}`,
                    display: 'inline-block',
                  }}
                />
                {t.name}
              </span>
              {detail && (
                <span
                  style={{
                    fontSize: 10,
                    maxWidth: 230,
                    whiteSpace: 'normal',
                    textAlign: 'center',
                    color: '#b6c4e0',
                    background: 'rgba(8,11,24,0.78)',
                    padding: '4px 8px',
                    borderRadius: 8,
                    border: `1px solid ${cat?.glow ?? 'rgba(255,255,255,0.15)'}`,
                    backdropFilter: 'blur(8px)',
                    boxShadow: '0 6px 20px rgba(0,0,0,0.4)',
                    lineHeight: 1.35,
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
    state.camera.position.y += Math.sin(t * 0.16) * 0.01;
  });
  return null;
}

// ---- scene shell --------------------------------------------------------------
function Scene({
  filterCat,
  filterStage,
  onHoverTool,
}: {
  filterCat: number;
  filterStage: number;
  onHoverTool: (id: string | null) => void;
}) {
  const [hovered, setHovered] = useState<number | null>(null);
  const cloud = useMemo(() => buildCloud(), []);

  const handleHover = (idx: number | null) => {
    setHovered(idx);
    onHoverTool(idx == null ? null : cloud.realStars[idx]?.tool.id ?? null);
  };

  return (
    <>
      <color attach="background" args={['#04050d']} />
      <fog attach="fog" args={['#04050d', 70, 230]} />

      <PointCloudInner
        geometry={cloud.geometry}
        realPositions={cloud.realPositions}
        filterCat={filterCat}
        filterStage={filterStage}
        onHover={handleHover}
      />

      <RelationLines
        hovered={hovered}
        realStars={cloud.realStars}
        realIndexById={cloud.realIndexById}
      />

      <ProximityLabels
        realStars={cloud.realStars}
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
        zoomSpeed={0.85}
        minDistance={16}
        maxDistance={200}
        autoRotate
        autoRotateSpeed={0.16}
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
      uFilterMix: { value: 0 },
      uFogColor: { value: new THREE.Color('#04050d') },
    }),
    [pixelRatio],
  );

  useFrame((state, delta) => {
    if (!matRef.current) return;
    const u = matRef.current.uniforms;
    u.uTime.value = state.clock.elapsedTime;
    u.uFilterCat.value = filterCat;
    u.uFilterStage.value = filterStage;
    // smoothly ease the filter mix toward its target so fades are buttery.
    const target = filterCat >= 0 || filterStage >= 0 ? 1 : 0;
    const k = 1 - Math.exp(-delta * 6);
    u.uFilterMix.value += (target - u.uFilterMix.value) * k;
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

      {/* invisible larger picking points so hover targets the real stars */}
      <points
        geometry={pickGeo}
        onPointerMove={(e) => {
          e.stopPropagation();
          onHover(e.index ?? null);
        }}
        onPointerOut={() => onHover(null)}
      >
        <pointsMaterial size={6} transparent opacity={0} depthWrite={false} sizeAttenuation />
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
  matchCount: number;
  hoveredTool: AITool | null;
}

function FilterOverlay({
  filterCat,
  setFilterCat,
  filterStage,
  setFilterStage,
  matchCount,
  hoveredTool,
}: OverlayProps) {
  const filtering = filterCat >= 0 || filterStage >= 0;
  return (
    <div className="pointer-events-none absolute inset-0" style={{ paddingTop: 64 }}>
      {/* header */}
      <div className="pointer-events-none absolute left-6 top-[72px] select-none">
        <div
          style={{
            fontFamily: 'ui-sans-serif, -apple-system, "SF Pro Display", sans-serif',
            fontSize: 23,
            fontWeight: 700,
            letterSpacing: -0.3,
            color: '#eaf2ff',
            textShadow: '0 0 18px rgba(110,231,255,0.35)',
          }}
        >
          Firefly
        </div>
        <div style={{ fontSize: 12, color: '#8493b6', marginTop: 2, maxWidth: 280 }}>
          {REAL_COUNT} AI tools as glowing stars in a {(AMBIENT_COUNT).toLocaleString()}-mote
          field. Drag to fly · scroll to zoom in for labels.
        </div>

        {/* legend */}
        <div
          className="pointer-events-none"
          style={{
            marginTop: 12,
            display: 'flex',
            flexWrap: 'wrap',
            gap: 6,
            maxWidth: 300,
          }}
        >
          <LegendDot label="Tool star" big />
          <LegendDot label="Ambient dust" />
        </div>
      </div>

      {/* live match readout */}
      <div
        className="pointer-events-none absolute left-1/2 top-[78px] -translate-x-1/2 select-none"
        style={{
          fontSize: 12,
          fontWeight: 600,
          letterSpacing: 0.3,
          color: filtering ? '#06080f' : '#bccbe8',
          background: filtering ? 'rgba(110,231,255,0.9)' : 'rgba(12,16,30,0.6)',
          border: `1px solid ${filtering ? 'rgba(110,231,255,0.9)' : 'rgba(120,140,180,0.2)'}`,
          padding: '5px 12px',
          borderRadius: 99,
          backdropFilter: 'blur(8px)',
          boxShadow: filtering ? '0 0 18px rgba(110,231,255,0.45)' : 'none',
          transition: 'all .3s ease',
        }}
      >
        {filtering
          ? `${matchCount} of ${REAL_COUNT} tools match`
          : `${REAL_COUNT} tools · all visible`}
      </div>

      {/* hovered tool readout (bottom-left), reinforces "these are real tools" */}
      {hoveredTool && (
        <div
          className="pointer-events-none absolute bottom-6 left-6 select-none"
          style={{
            maxWidth: 280,
            background: 'rgba(8,11,24,0.82)',
            border: `1px solid ${categoryById.get(hoveredTool.category)?.glow ?? 'rgba(255,255,255,0.15)'}`,
            borderRadius: 12,
            padding: '10px 12px',
            backdropFilter: 'blur(10px)',
            boxShadow: '0 10px 30px rgba(0,0,0,0.45)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
            <span
              style={{
                width: 9,
                height: 9,
                borderRadius: 99,
                background: categoryById.get(hoveredTool.category)?.color ?? '#fff',
                boxShadow: `0 0 10px ${categoryById.get(hoveredTool.category)?.color ?? '#fff'}`,
              }}
            />
            <span style={{ fontSize: 14, fontWeight: 700, color: '#f4f9ff' }}>
              {hoveredTool.name}
            </span>
            <span
              style={{
                fontSize: 10,
                textTransform: 'uppercase',
                letterSpacing: 0.6,
                color: '#7e8db0',
                marginLeft: 'auto',
              }}
            >
              {categoryById.get(hoveredTool.category)?.shortName} · {hoveredTool.stage}
            </span>
          </div>
          <div style={{ fontSize: 11.5, color: '#b6c4e0', marginTop: 5, lineHeight: 1.4 }}>
            {hoveredTool.summary}
          </div>
        </div>
      )}

      {/* category toggles */}
      <div
        className="pointer-events-auto absolute right-5 top-[72px] flex flex-col gap-1.5"
        style={{ width: 186 }}
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
        <button onClick={() => setFilterCat(-1)} style={chipStyle(filterCat === -1, '#d8faff')}>
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
      <div className="pointer-events-auto absolute bottom-6 left-1/2 flex -translate-x-1/2 flex-wrap justify-center gap-1.5">
        <button onClick={() => setFilterStage(-1)} style={pillStyle(filterStage === -1, '#d8faff')}>
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

function LegendDot({ label, big }: { label: string; big?: boolean }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        fontSize: 10.5,
        color: '#8493b6',
        background: 'rgba(12,16,30,0.5)',
        border: '1px solid rgba(120,140,180,0.16)',
        borderRadius: 99,
        padding: '3px 9px 3px 7px',
      }}
    >
      <span
        style={{
          width: big ? 9 : 4,
          height: big ? 9 : 4,
          borderRadius: 99,
          background: big ? '#9fe9ff' : '#5d6a8a',
          boxShadow: big ? '0 0 10px #6ee7ff, 0 0 4px #fff' : 'none',
          display: 'inline-block',
        }}
      />
      {label}
    </span>
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
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  // live count of real tools matching the active filters.
  const matchCount = useMemo(() => {
    if (filterCat < 0 && filterStage < 0) return REAL_COUNT;
    return tools.reduce((n, t) => {
      const cOk = filterCat < 0 || categories[filterCat]?.id === t.category;
      const sOk = filterStage < 0 || STAGES[filterStage] === t.stage;
      return n + (cOk && sOk ? 1 : 0);
    }, 0);
  }, [filterCat, filterStage]);

  const hoveredTool = hoveredId ? toolById.get(hoveredId) ?? null : null;

  return (
    <div className="absolute inset-0" style={{ background: '#04050d' }}>
      <Canvas
        camera={{ position: [0, 24, 98], fov: 58, near: 0.1, far: 600 }}
        gl={{ antialias: true, alpha: false }}
        dpr={[1, 2]}
        frameloop="always"
      >
        <Scene filterCat={filterCat} filterStage={filterStage} onHoverTool={setHoveredId} />
      </Canvas>

      <FilterOverlay
        filterCat={filterCat}
        setFilterCat={setFilterCat}
        filterStage={filterStage}
        setFilterStage={setFilterStage}
        matchCount={matchCount}
        hoveredTool={hoveredTool}
      />
    </div>
  );
}
