import { useEffect, useMemo, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import type { OrbitControls as OrbitControlsImpl } from 'three-stdlib';
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
 * holds a bounded field of deterministic ambient motes plus the 49 REAL
 * AI-tool stars. A custom ShaderMaterial does size-attenuation LOD (far = dim
 * dust, near = bright stars), depth fog and twinkle. The 49 tools are the
 * heroes: visibly larger, category-coloured, ringed with a halo, labelled.
 *
 * iOS App-Store pass:
 *  - Ambient mote count is BOUNDED and scaled hard on small viewports so the
 *    field never tanks phone fps. Geometry + materials are built once / shared.
 *  - Tap selects a star and the camera EASES to focus it; drag orbits; pinch
 *    zooms (OrbitControls). No popping — selection, focus and filter fades are
 *    all smoothly interpolated.
 *  - All HUD / cards / controls are liquid-glass (frosted, rounded-2xl) with
 *    eased show/hide and phone-width reflow.
 *  - prefers-reduced-motion calms autorotate, drift and twinkle.
 *
 * No Math.random at render/module time — a seeded mulberry32 PRNG drives every
 * particle. No per-frame allocation — geometry is built once in useMemo and we
 * mutate uniforms / refs in useFrame.
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

// ---- viewport-aware ambient budget (mobile-first weight control) -------------
// Bounded counts, scaled HARD on small viewports so the field stays light.
function pickAmbientCount(width: number): number {
  if (width < 480) return 2600; // small phones
  if (width < 768) return 4200; // large phones
  if (width < 1280) return 8000; // tablets / small laptops
  return 12000; // desktop ceiling (bounded)
}

// ---- constants ----------------------------------------------------------------
const REAL_COUNT = tools.length;
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
function buildCloud(ambientCount: number): CloudData {
  const total = ambientCount + REAL_COUNT;
  const rng = mulberry32(0xf17e_f1a7);
  const positions = new Float32Array(total * 3);
  const colors = new Float32Array(total * 3);
  const sizes = new Float32Array(total);
  const seeds = new Float32Array(total); // per-point phase for twinkle
  const catIndex = new Float32Array(total);
  const stageIndex = new Float32Array(total);
  const isReal = new Float32Array(total);

  const catList = categories;

  // --- ambient particles: a flattened galactic disk + a softer halo sphere ---
  for (let i = 0; i < ambientCount; i++) {
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
    const i = ambientCount + j;
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
  uniform float uTwinkleAmt;  // 0 = calm (reduced motion), 1 = lively

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

    // gentle twinkle; real stars pulse a touch stronger / faster. Amplitude is
    // scaled by uTwinkleAmt so reduced-motion users get a near-static field.
    float twBase = aReal > 0.5 ? 0.28 : 0.18;
    float tw = (1.0 - twBase * uTwinkleAmt)
      + twBase * uTwinkleAmt * (0.5 + 0.5 * sin(uTime * (aReal > 0.5 ? 1.7 : 0.5) + aSeed * 6.2831));
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
    col += vColor * max(vTwinkle - 0.82, 0.0) * (vReal > 0.5 ? 0.6 : 0.25);

    // fade non-matching points strongly (Firefly-style filter).
    float matchFade = mix(0.05, 1.0, vMatch);

    // fog blends toward background but keeps a little glow.
    vec3 final = mix(col, uFogColor, vFog * 0.82);

    gl_FragColor = vec4(final, baseAlpha * matchFade * (1.0 - vFog * 0.5));
  }
`;

// ---- relation lines for the active (hovered / selected) star -----------------
function RelationLines({
  active,
  realStars,
  realIndexById,
}: {
  active: number | null;
  realStars: RealStar[];
  realIndexById: Map<string, number>;
}) {
  const matRef = useRef<THREE.LineBasicMaterial>(null);
  const geo = useMemo(() => {
    if (active == null) return null;
    const src = realStars[active];
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
  }, [active, realStars, realIndexById]);

  // ease the line opacity in so relations never pop on.
  useFrame((_, delta) => {
    const m = matRef.current;
    if (!m) return;
    const k = 1 - Math.exp(-delta * 7);
    m.opacity += (0.5 - m.opacity) * k;
  });

  // free the previous geometry to avoid GPU buffer leaks across selections.
  useEffect(() => {
    return () => {
      geo?.dispose();
    };
  }, [geo]);

  if (!geo) return null;
  const color = realStars[active ?? 0]?.color ?? '#ffffff';
  return (
    <lineSegments geometry={geo}>
      <lineBasicMaterial
        ref={matRef}
        color={color}
        transparent
        opacity={0}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </lineSegments>
  );
}

// ---- labels for nearby / active real tools -----------------------------------
interface LabelsProps {
  realStars: RealStar[];
  active: number | null;
  filterCat: number;
  filterStage: number;
  reducedMotion: boolean;
}

function ProximityLabels({ realStars, active, filterCat, filterStage, reducedMotion }: LabelsProps) {
  // Each entry: index + a "detail" flag (close enough to show the summary).
  const [near, setNear] = useState<{ j: number; detail: boolean }[]>([]);
  const nearRef = useRef<{ j: number; detail: boolean }[]>([]);
  const tickRef = useRef(0);

  useFrame((state, delta) => {
    // throttle the proximity scan to ~12Hz — labels don't need per-frame churn
    // and this keeps phone CPU cool.
    tickRef.current += delta;
    if (tickRef.current < 0.08) return;
    tickRef.current = 0;

    const cam = state.camera;
    const out: { j: number; detail: boolean }[] = [];
    for (let j = 0; j < realStars.length; j++) {
      const d = realStars[j].pos.distanceTo(cam.position);
      // Always-on labels for the closest ring of stars; detail when really close.
      if (d < 88 || j === active) {
        out.push({ j, detail: d < 48 || j === active });
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
        const isActive = j === active;
        return (
          <Html
            key={t.id}
            position={[star.pos.x, star.pos.y + 2.6, star.pos.z]}
            center
            distanceFactor={44}
            style={{ pointerEvents: 'none' }}
            zIndexRange={[isActive ? 60 : 20, 0]}
          >
            <div
              style={{
                opacity: dim ? 0.18 : 1,
                transform: isActive ? 'scale(1.1)' : 'scale(1)',
                transition: reducedMotion
                  ? 'opacity .25s linear'
                  : 'opacity .45s ease, transform .3s cubic-bezier(0.22,1,0.36,1)',
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
                  fontSize: isActive ? 14 : 11.5,
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
                    width: isActive ? 7 : 5,
                    height: isActive ? 7 : 5,
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
                    color: '#cdd9f2',
                    background: 'rgba(255,255,255,0.06)',
                    padding: '5px 9px',
                    borderRadius: 12,
                    border: '1px solid rgba(255,255,255,0.1)',
                    backdropFilter: 'blur(16px)',
                    WebkitBackdropFilter: 'blur(16px)',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
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
function CameraDrift({ reducedMotion }: { reducedMotion: boolean }) {
  useFrame((state) => {
    if (reducedMotion) return;
    const t = state.clock.elapsedTime;
    // subtle parallax breathing layered on top of OrbitControls
    state.camera.position.y += Math.sin(t * 0.16) * 0.01;
  });
  return null;
}

// ---- eased camera focus: smoothly drives OrbitControls target + dolly --------
// Mutates persistent vectors only — zero per-frame allocation.
function CameraFocus({
  target,
  controlsRef,
}: {
  target: THREE.Vector3 | null;
  controlsRef: React.RefObject<OrbitControlsImpl | null>;
}) {
  const { camera } = useThree();
  const desiredTarget = useRef(new THREE.Vector3());
  const desiredPos = useRef(new THREE.Vector3());
  const offset = useRef(new THREE.Vector3());
  const active = useRef(false);

  useEffect(() => {
    const ctrl = controlsRef.current;
    if (!target || !ctrl) {
      active.current = false;
      return;
    }
    desiredTarget.current.copy(target);
    // keep the current viewing direction; pull the camera to a comfortable
    // framing distance from the chosen star.
    offset.current.copy(camera.position).sub(ctrl.target);
    const dist = THREE.MathUtils.clamp(offset.current.length(), 16, 200);
    const framing = THREE.MathUtils.clamp(dist, 30, 52);
    offset.current.setLength(framing);
    desiredPos.current.copy(target).add(offset.current);
    active.current = true;
  }, [target, camera, controlsRef]);

  useFrame((_, delta) => {
    if (!active.current) return;
    const ctrl = controlsRef.current;
    if (!ctrl) return;
    // critically-damped ease toward the framing — buttery, no overshoot.
    const k = 1 - Math.exp(-delta * 4.5);
    ctrl.target.lerp(desiredTarget.current, k);
    camera.position.lerp(desiredPos.current, k);
    ctrl.update();
    if (
      ctrl.target.distanceToSquared(desiredTarget.current) < 0.01 &&
      camera.position.distanceToSquared(desiredPos.current) < 0.01
    ) {
      active.current = false;
    }
  });

  return null;
}

// ---- scene shell --------------------------------------------------------------
function Scene({
  ambientCount,
  filterCat,
  filterStage,
  selectedId,
  reducedMotion,
  onPickTool,
}: {
  ambientCount: number;
  filterCat: number;
  filterStage: number;
  selectedId: string | null;
  reducedMotion: boolean;
  onPickTool: (id: string | null) => void;
}) {
  const [hovered, setHovered] = useState<number | null>(null);
  const cloud = useMemo(() => buildCloud(ambientCount), [ambientCount]);
  const controlsRef = useRef<OrbitControlsImpl | null>(null);

  // dispose the GPU geometry when the cloud is rebuilt (e.g. viewport tier change).
  useEffect(() => {
    const g = cloud.geometry;
    return () => g.dispose();
  }, [cloud]);

  const selectedIdx = selectedId ? cloud.realIndexById.get(selectedId) ?? null : null;
  const active = hovered ?? selectedIdx;
  const focusTarget = selectedIdx != null ? cloud.realStars[selectedIdx]?.pos ?? null : null;

  // stop the gentle auto-rotate while a tool is focused so the framing holds.
  const autoRotate = !reducedMotion && selectedIdx == null;

  return (
    <>
      <color attach="background" args={['#04050d']} />
      <fog attach="fog" args={['#04050d', 70, 230]} />

      <PointCloudInner
        geometry={cloud.geometry}
        realPositions={cloud.realPositions}
        filterCat={filterCat}
        filterStage={filterStage}
        reducedMotion={reducedMotion}
        onHover={setHovered}
        onPick={(idx) => onPickTool(idx == null ? null : cloud.realStars[idx]?.tool.id ?? null)}
      />

      <RelationLines
        active={active}
        realStars={cloud.realStars}
        realIndexById={cloud.realIndexById}
      />

      <ProximityLabels
        realStars={cloud.realStars}
        active={active}
        filterCat={filterCat}
        filterStage={filterStage}
        reducedMotion={reducedMotion}
      />

      <CameraDrift reducedMotion={reducedMotion} />
      <CameraFocus target={focusTarget} controlsRef={controlsRef} />
      <OrbitControls
        ref={controlsRef}
        enablePan={false}
        enableDamping
        dampingFactor={0.08}
        rotateSpeed={0.5}
        zoomSpeed={0.85}
        minDistance={16}
        maxDistance={200}
        autoRotate={autoRotate}
        autoRotateSpeed={0.16}
      />
    </>
  );
}

// Inner cloud that owns the shader material + tap picking. Geometry is passed
// in from the parent so labels and picking share the same world positions.
interface InnerProps {
  geometry: THREE.BufferGeometry;
  realPositions: Float32Array;
  filterCat: number;
  filterStage: number;
  reducedMotion: boolean;
  onHover: (idx: number | null) => void;
  onPick: (idx: number | null) => void;
}

function PointCloudInner({
  geometry,
  realPositions,
  filterCat,
  filterStage,
  reducedMotion,
  onHover,
  onPick,
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
      uTwinkleAmt: { value: reducedMotion ? 0 : 1 },
      uFogColor: { value: new THREE.Color('#04050d') },
    }),
    [pixelRatio, reducedMotion],
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

  // touch/tap picking: distinguish a tap from a drag so orbiting never selects.
  const downRef = useRef<{ x: number; y: number; t: number } | null>(null);

  const pickGeo = useMemo(() => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(realPositions, 3));
    return g;
  }, [realPositions]);

  useEffect(() => () => pickGeo.dispose(), [pickGeo]);

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

      {/* invisible larger picking points: hover (desktop) + tap (touch) select */}
      <points
        geometry={pickGeo}
        onPointerMove={(e) => {
          if (e.pointerType === 'mouse') {
            e.stopPropagation();
            onHover(e.index ?? null);
          }
        }}
        onPointerOut={(e) => {
          if (e.pointerType === 'mouse') onHover(null);
        }}
        onPointerDown={(e) => {
          downRef.current = { x: e.clientX, y: e.clientY, t: performance.now() };
        }}
        onPointerUp={(e) => {
          const d = downRef.current;
          downRef.current = null;
          if (!d) return;
          // a tap = small travel + short duration; a drag = orbit (ignored).
          const moved = Math.hypot(e.clientX - d.x, e.clientY - d.y);
          if (moved < 10 && performance.now() - d.t < 500) {
            e.stopPropagation();
            onPick(e.index ?? null);
          }
        }}
      >
        <pointsMaterial
          size={reducedMotion ? 8 : 7}
          transparent
          opacity={0}
          depthWrite={false}
          sizeAttenuation
        />
      </points>
    </group>
  );
}

// ---- filter overlay (liquid glass, Firefly-style) -----------------------------
interface OverlayProps {
  ambientCount: number;
  filterCat: number;
  setFilterCat: (n: number) => void;
  filterStage: number;
  setFilterStage: (n: number) => void;
  matchCount: number;
  selectedTool: AITool | null;
  onClearSelection: () => void;
  isPhone: boolean;
}

function FilterOverlay({
  ambientCount,
  filterCat,
  setFilterCat,
  filterStage,
  setFilterStage,
  matchCount,
  selectedTool,
  onClearSelection,
  isPhone,
}: OverlayProps) {
  const filtering = filterCat >= 0 || filterStage >= 0;
  return (
    <div className="pointer-events-none absolute inset-0" style={{ paddingTop: 64 }}>
      {/* header — liquid glass card */}
      <div
        className="pointer-events-none absolute left-4 top-[72px] select-none rounded-2xl border border-white/10 bg-white/[0.06] px-4 py-3 shadow-[0_10px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl"
        style={{ maxWidth: isPhone ? 'calc(100vw - 32px)' : 320 }}
      >
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
        <div style={{ fontSize: 12, color: '#9fb0d0', marginTop: 3, lineHeight: 1.4 }}>
          {REAL_COUNT} AI tools as glowing stars in a {ambientCount.toLocaleString()}-mote field.
          {isPhone ? ' Drag to fly · pinch to zoom · tap a star.' : ' Drag to fly · scroll to zoom · click a star.'}
        </div>

        {/* legend */}
        <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          <LegendDot label="Tool star" big />
          <LegendDot label="Ambient dust" />
        </div>
      </div>

      {/* live match readout — frosted pill */}
      <div
        className="pointer-events-none absolute left-1/2 top-[76px] -translate-x-1/2 select-none rounded-full border backdrop-blur-xl"
        style={{
          fontSize: 12,
          fontWeight: 600,
          letterSpacing: 0.3,
          whiteSpace: 'nowrap',
          color: filtering ? '#06080f' : '#cdd9f2',
          background: filtering ? 'rgba(110,231,255,0.9)' : 'rgba(255,255,255,0.07)',
          borderColor: filtering ? 'rgba(110,231,255,0.9)' : 'rgba(255,255,255,0.12)',
          padding: '6px 14px',
          boxShadow: filtering ? '0 0 18px rgba(110,231,255,0.45)' : '0 6px 20px rgba(0,0,0,0.35)',
          transition: 'all .35s cubic-bezier(0.22,1,0.36,1)',
        }}
      >
        {filtering
          ? `${matchCount} of ${REAL_COUNT} tools match`
          : `${REAL_COUNT} tools · all visible`}
      </div>

      {/* selected tool readout (bottom-left) — liquid glass, eased show/hide */}
      <div
        className="pointer-events-auto absolute bottom-24 left-4 select-none rounded-2xl border border-white/10 bg-white/[0.07] p-3 shadow-[0_12px_40px_rgba(0,0,0,0.5)] backdrop-blur-2xl"
        style={{
          maxWidth: isPhone ? 'calc(100vw - 32px)' : 300,
          opacity: selectedTool ? 1 : 0,
          transform: selectedTool ? 'translateY(0) scale(1)' : 'translateY(12px) scale(0.98)',
          transition: 'opacity .35s ease, transform .35s cubic-bezier(0.22,1,0.36,1)',
          pointerEvents: selectedTool ? 'auto' : 'none',
        }}
      >
        {selectedTool && (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <span
                style={{
                  width: 9,
                  height: 9,
                  borderRadius: 99,
                  flex: '0 0 auto',
                  background: categoryById.get(selectedTool.category)?.color ?? '#fff',
                  boxShadow: `0 0 10px ${categoryById.get(selectedTool.category)?.color ?? '#fff'}`,
                }}
              />
              <span style={{ fontSize: 14, fontWeight: 700, color: '#f4f9ff' }}>
                {selectedTool.name}
              </span>
              <button
                onClick={onClearSelection}
                aria-label="Clear selection"
                className="ml-auto flex h-7 w-7 items-center justify-center rounded-full border border-white/10 bg-white/[0.06] text-[#9fb0d0] transition hover:bg-white/[0.12]"
                style={{ flex: '0 0 auto', fontSize: 15, lineHeight: 1 }}
              >
                ×
              </button>
            </div>
            <div
              style={{
                fontSize: 10,
                textTransform: 'uppercase',
                letterSpacing: 0.6,
                color: '#8ea0c4',
                marginTop: 4,
              }}
            >
              {categoryById.get(selectedTool.category)?.shortName} · {selectedTool.stage}
            </div>
            <div style={{ fontSize: 11.5, color: '#cdd9f2', marginTop: 6, lineHeight: 1.45 }}>
              {selectedTool.summary}
            </div>
          </>
        )}
      </div>

      {/* category toggles — liquid-glass panel, touch-friendly chips */}
      <div
        className="pointer-events-auto absolute right-3 top-[72px] flex flex-col gap-1.5 rounded-2xl border border-white/10 bg-white/[0.06] p-2.5 shadow-[0_10px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl"
        style={{ width: isPhone ? 150 : 190 }}
      >
        <div
          style={{
            fontSize: 10,
            textTransform: 'uppercase',
            letterSpacing: 1.4,
            color: '#8294b8',
            margin: '2px 2px 2px',
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
                flex: '0 0 auto',
                background: c.color,
                boxShadow: `0 0 8px ${c.color}`,
                display: 'inline-block',
                marginRight: 8,
              }}
            />
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {c.shortName ?? c.name}
            </span>
          </button>
        ))}
      </div>

      {/* stage filter — frosted pill rail */}
      <div
        className="pointer-events-auto absolute bottom-5 left-1/2 flex -translate-x-1/2 flex-wrap justify-center gap-1.5 rounded-full border border-white/10 bg-white/[0.06] p-1.5 shadow-[0_10px_40px_rgba(0,0,0,0.45)] backdrop-blur-xl"
        style={{ maxWidth: 'calc(100vw - 24px)' }}
      >
        <button onClick={() => setFilterStage(-1)} style={pillStyle(filterStage === -1, '#d8faff')}>
          All
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
      className="rounded-full border border-white/10 bg-white/[0.05]"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        fontSize: 10.5,
        color: '#9fb0d0',
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
    padding: '8px 10px', // comfortable tap target
    borderRadius: 12,
    textAlign: 'left',
    color: active ? '#06080f' : '#cdd9f2',
    background: active ? color : 'rgba(255,255,255,0.05)',
    border: `1px solid ${active ? color : 'rgba(255,255,255,0.1)'}`,
    cursor: 'pointer',
    transition: 'background .2s, color .2s, border-color .2s',
    textTransform: 'capitalize',
    minWidth: 0,
  };
}

function pillStyle(active: boolean, color: string): CSSProperties {
  return {
    fontSize: 11,
    fontWeight: 600,
    padding: '7px 13px', // comfortable tap target
    borderRadius: 99,
    color: active ? '#06080f' : '#c5d2ec',
    background: active ? color : 'transparent',
    border: `1px solid ${active ? color : 'rgba(255,255,255,0.1)'}`,
    cursor: 'pointer',
    textTransform: 'capitalize',
    boxShadow: active ? `0 0 14px ${color}66` : 'none',
    transition: 'all .2s',
    whiteSpace: 'nowrap',
  };
}

// ---- viewport + reduced-motion hooks (mobile weight + calm motion) -----------
function useViewport() {
  const [width, setWidth] = useState(() =>
    typeof window !== 'undefined' ? window.innerWidth : 1280,
  );
  useEffect(() => {
    let raf = 0;
    const onResize = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => setWidth(window.innerWidth));
    };
    window.addEventListener('resize', onResize);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', onResize);
    };
  }, []);
  return width;
}

function useReducedMotion() {
  const [reduced, setReduced] = useState(() =>
    typeof window !== 'undefined'
      ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
      : false,
  );
  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);
  return reduced;
}

// ---- root ---------------------------------------------------------------------
export function Firefly() {
  const width = useViewport();
  const reducedMotion = useReducedMotion();
  const isPhone = width < 768;

  // bucket the ambient count to a viewport tier so the cloud only rebuilds when
  // the tier actually changes (not on every resize pixel).
  const ambientCount = useMemo(() => pickAmbientCount(width), [width]);

  const [filterCat, setFilterCat] = useState(-1);
  const [filterStage, setFilterStage] = useState(-1);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // live count of real tools matching the active filters.
  const matchCount = useMemo(() => {
    if (filterCat < 0 && filterStage < 0) return REAL_COUNT;
    return tools.reduce((n, t) => {
      const cOk = filterCat < 0 || categories[filterCat]?.id === t.category;
      const sOk = filterStage < 0 || STAGES[filterStage] === t.stage;
      return n + (cOk && sOk ? 1 : 0);
    }, 0);
  }, [filterCat, filterStage]);

  const selectedTool = selectedId ? toolById.get(selectedId) ?? null : null;

  return (
    <div className="absolute inset-0" style={{ background: '#04050d' }}>
      <Canvas
        camera={{ position: [0, 24, 98], fov: 58, near: 0.1, far: 600 }}
        gl={{ antialias: !isPhone, alpha: false, powerPreference: 'high-performance' }}
        dpr={[1, 2]}
        frameloop="always"
      >
        <Scene
          ambientCount={ambientCount}
          filterCat={filterCat}
          filterStage={filterStage}
          selectedId={selectedId}
          reducedMotion={reducedMotion}
          onPickTool={setSelectedId}
        />
      </Canvas>

      <FilterOverlay
        ambientCount={ambientCount}
        filterCat={filterCat}
        setFilterCat={setFilterCat}
        filterStage={filterStage}
        setFilterStage={setFilterStage}
        matchCount={matchCount}
        selectedTool={selectedTool}
        onClearSelection={() => setSelectedId(null)}
        isPhone={isPhone}
      />
    </div>
  );
}
