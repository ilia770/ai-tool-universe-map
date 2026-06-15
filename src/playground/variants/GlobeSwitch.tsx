import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from 'react';
import { Canvas, useFrame, useThree, type ThreeEvent } from '@react-three/fiber';
import { CameraControls, Html, Stars } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  toolById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

/* ------------------------------------------------------------------ *
 * Globe Switch (Direction M)
 *
 * A spatial-zoom hierarchy through nested worlds, emulating the
 * Awwwards "globe switch" / Google-Earth dive technique:
 *
 *   ECOSYSTEM globe  -> 8 category regions plotted on its surface.
 *   CATEGORY planet  -> dive in; its surface markers become its tools.
 *   TOOL             -> click a marker to surface an info card.
 *
 * Technique emulated (from R3F globe + camera-fly references):
 *  - markers placed via lat/lng -> unit-sphere normals, scaled to radius;
 *  - billboarded Html labels so text always faces the camera;
 *  - drei CameraControls.setLookAt(..., true) with eased dolly to fly the
 *    camera along a region's surface normal on click (the Earth "zoom to
 *    pin" move), then a world-swap at the bottom of the dive (LOD);
 *  - fresnel atmosphere shell + additive star field for depth.
 * ------------------------------------------------------------------ */

type Level = 'globe' | 'planet';

const GLOBE_RADIUS = 5.2;
const PLANET_RADIUS = 3.4;
const GLOBE_CAM_DIST = 13.5;
const PLANET_CAM_DIST = 9;

/** Deterministic 0..1 PRNG (mulberry32) — no Math.random in render/module init. */
function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** lat (deg), lng (deg) -> point on a sphere of given radius. */
function latLngToVec3(latDeg: number, lngDeg: number, radius: number): THREE.Vector3 {
  const phi = (90 - latDeg) * (Math.PI / 180);
  const theta = (lngDeg + 180) * (Math.PI / 180);
  return new THREE.Vector3(
    -radius * Math.sin(phi) * Math.cos(theta),
    radius * Math.cos(phi),
    radius * Math.sin(phi) * Math.sin(theta),
  );
}

/** Spread N items into a stable lat/lng spiral so markers never collide. */
function spiralLatLng(index: number, count: number, rng: () => number): [number, number] {
  const y = count <= 1 ? 0 : 1 - (index / (count - 1)) * 2; // 1 .. -1
  const lat = Math.asin(THREE.MathUtils.clamp(y, -1, 1)) * (180 / Math.PI);
  const golden = index * 137.508;
  const lng = ((golden + rng() * 24) % 360) - 180;
  return [lat * 0.82, lng];
}

interface MarkerPlacement {
  pos: THREE.Vector3;
  normal: THREE.Vector3;
}

/* ---------------------------- atmosphere --------------------------- */

const ATMO_VERT = /* glsl */ `
  varying vec3 vNormal;
  varying vec3 vView;
  void main() {
    vNormal = normalize(normalMatrix * normal);
    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    vView = normalize(-mv.xyz);
    gl_Position = projectionMatrix * mv;
  }
`;

const ATMO_FRAG = /* glsl */ `
  varying vec3 vNormal;
  varying vec3 vView;
  uniform vec3 uColor;
  uniform float uPower;
  void main() {
    float fres = pow(1.0 - abs(dot(vNormal, vView)), uPower);
    gl_FragColor = vec4(uColor, fres);
  }
`;

function Atmosphere({ radius, color }: { radius: number; color: string }) {
  const uniforms = useMemo(
    () => ({
      uColor: { value: new THREE.Color(color) },
      uPower: { value: 2.6 },
    }),
    [color],
  );
  useEffect(() => {
    uniforms.uColor.value.set(color);
  }, [color, uniforms]);
  return (
    <mesh>
      <sphereGeometry args={[radius * 1.18, 64, 64]} />
      <shaderMaterial
        vertexShader={ATMO_VERT}
        fragmentShader={ATMO_FRAG}
        uniforms={uniforms}
        transparent
        side={THREE.BackSide}
        blending={THREE.AdditiveBlending}
        depthWrite={false}
      />
    </mesh>
  );
}

/* ----------------------------- the globe --------------------------- */

interface GlobeBodyProps {
  radius: number;
  color: string;
  glow: string;
}

function GlobeBody({ radius, color, glow }: GlobeBodyProps) {
  const group = useRef<THREE.Group>(null);
  const wire = useMemo(() => new THREE.Color(color).multiplyScalar(1.35), [color]);
  const coreColor = useMemo(() => new THREE.Color(color).multiplyScalar(0.12), [color]);
  const emissive = useMemo(() => new THREE.Color(glow), [glow]);

  useFrame((_, delta) => {
    if (group.current) group.current.rotation.y += delta * 0.045;
  });

  return (
    <group ref={group}>
      <mesh>
        <sphereGeometry args={[radius * 0.995, 64, 64]} />
        <meshStandardMaterial
          color={coreColor}
          emissive={emissive}
          emissiveIntensity={0.35}
          roughness={0.55}
          metalness={0.2}
        />
      </mesh>
      <mesh>
        <sphereGeometry args={[radius, 36, 24]} />
        <meshBasicMaterial color={wire} wireframe transparent opacity={0.16} />
      </mesh>
    </group>
  );
}

/* --------------------------- surface marker ------------------------ */

interface MarkerProps {
  placement: MarkerPlacement;
  color: string;
  label: string;
  sub?: string;
  active: boolean;
  big: boolean;
  onClick: () => void;
  onHover: (h: boolean) => void;
}

function SurfaceMarker({
  placement,
  color,
  label,
  sub,
  active,
  big,
  onClick,
  onHover,
}: MarkerProps) {
  const haloRef = useRef<THREE.Mesh>(null);
  const baseScale = big ? 1 : 0.74;

  useFrame((state) => {
    const t = state.clock.elapsedTime;
    if (haloRef.current) {
      const pulse = active ? 1.25 + Math.sin(t * 3) * 0.18 : 1 + Math.sin(t * 1.6) * 0.06;
      haloRef.current.scale.setScalar(pulse * baseScale);
    }
  });

  return (
    <group
      position={placement.pos}
      onClick={(e: ThreeEvent<MouseEvent>) => {
        e.stopPropagation();
        onClick();
      }}
      onPointerOver={(e: ThreeEvent<PointerEvent>) => {
        e.stopPropagation();
        onHover(true);
      }}
      onPointerOut={() => onHover(false)}
    >
      <mesh ref={haloRef}>
        <sphereGeometry args={[big ? 0.3 : 0.2, 24, 24]} />
        <meshBasicMaterial
          color={color}
          transparent
          opacity={active ? 0.9 : 0.55}
          blending={THREE.AdditiveBlending}
          depthWrite={false}
        />
      </mesh>
      <mesh scale={baseScale}>
        <sphereGeometry args={[big ? 0.13 : 0.085, 20, 20]} />
        <meshStandardMaterial
          color="#ffffff"
          emissive={new THREE.Color(color)}
          emissiveIntensity={active ? 2.4 : 1.3}
          roughness={0.3}
        />
      </mesh>
      <Html
        center
        distanceFactor={big ? 13 : 10}
        position={[0, big ? 0.5 : 0.34, 0]}
        style={{ pointerEvents: 'none' }}
      >
        <div
          style={{
            transform: `scale(${active ? 1.08 : 1})`,
            transition: 'transform 220ms ease, opacity 220ms ease',
            opacity: active ? 1 : 0.92,
            whiteSpace: 'nowrap',
            textAlign: 'center',
          }}
        >
          <div
            style={{
              fontSize: big ? 13 : 11,
              fontWeight: 600,
              letterSpacing: '0.01em',
              color: '#f5fbff',
              textShadow: `0 0 12px ${color}, 0 1px 3px rgba(0,0,0,0.85)`,
            }}
          >
            {label}
          </div>
          {sub ? (
            <div
              style={{
                fontSize: 8.5,
                marginTop: 1,
                color: 'rgba(220,235,245,0.62)',
                textTransform: 'uppercase',
                letterSpacing: '0.14em',
              }}
            >
              {sub}
            </div>
          ) : null}
        </div>
      </Html>
    </group>
  );
}

/* --------------------------- camera director ----------------------- */

interface DirectorProps {
  level: Level;
  diveTarget: THREE.Vector3 | null;
  controls: React.RefObject<CameraControls | null>;
}

/**
 * Drives eased camera flights. On a category dive we fly along the region's
 * surface normal toward it (the Google-Earth "zoom to pin"), then settle on
 * the planet. On pull-back we frame the whole globe.
 */
function CameraDirector({ level, diveTarget, controls }: DirectorProps) {
  useEffect(() => {
    const c = controls.current;
    if (!c) return;
    if (level === 'globe') {
      void c.setLookAt(
        GLOBE_CAM_DIST * 0.22,
        GLOBE_CAM_DIST * 0.28,
        GLOBE_CAM_DIST,
        0,
        0,
        0,
        true,
      );
    } else if (level === 'planet' && diveTarget) {
      const dir = diveTarget.clone().normalize();
      const camPos = dir.multiplyScalar(PLANET_CAM_DIST);
      void c.setLookAt(camPos.x, camPos.y * 0.7 + 1.2, camPos.z, 0, 0, 0, true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [level, diveTarget]);

  return null;
}

/* ------------------------------ scene ------------------------------ */

interface SceneProps {
  level: Level;
  activeCategory: ToolCategory | null;
  activeTool: AITool | null;
  diveTarget: THREE.Vector3 | null;
  onSelectCategory: (cat: ToolCategory, pos: THREE.Vector3) => void;
  onSelectTool: (tool: AITool) => void;
  setHovered: (id: string | null) => void;
}

function GlobeScene({
  level,
  activeCategory,
  activeTool,
  diveTarget,
  onSelectCategory,
  onSelectTool,
  setHovered,
}: SceneProps) {
  const controls = useRef<CameraControls | null>(null);
  const { camera } = useThree();

  useEffect(() => {
    camera.position.set(
      GLOBE_CAM_DIST * 0.22,
      GLOBE_CAM_DIST * 0.28,
      GLOBE_CAM_DIST,
    );
  }, [camera]);

  // Category region placements on the ecosystem globe (stable).
  const categoryPlacements = useMemo(() => {
    const rng = makeRng(0xa17e);
    return categories.map((cat, i) => {
      const [lat, lng] = spiralLatLng(i, categories.length, rng);
      const pos = latLngToVec3(lat, lng, GLOBE_RADIUS);
      return { cat, pos, normal: pos.clone().normalize() };
    });
  }, []);

  // Tool placements for the currently open category planet (stable per cat).
  const toolPlacements = useMemo(() => {
    if (!activeCategory) return [];
    const catTools = tools.filter((t) => t.category === activeCategory.id);
    const rng = makeRng(
      Array.from(activeCategory.id).reduce((h, ch) => (h * 31 + ch.charCodeAt(0)) >>> 0, 7),
    );
    return catTools.map((tool, i) => {
      const [lat, lng] = spiralLatLng(i, catTools.length, rng);
      const pos = latLngToVec3(lat, lng, PLANET_RADIUS);
      return { tool, pos, normal: pos.clone().normalize() };
    });
  }, [activeCategory]);

  const planetColor = activeCategory?.color ?? '#6ee7ff';
  const planetGlow = activeCategory?.glow ?? 'rgba(110,231,255,0.34)';

  return (
    <>
      <color attach="background" args={['#03040b']} />
      <ambientLight intensity={0.55} />
      <directionalLight position={[6, 9, 8]} intensity={1.25} color="#cfeaff" />
      <directionalLight position={[-8, -3, -6]} intensity={0.4} color="#8a6bff" />
      <pointLight position={[0, 0, 0]} intensity={1.4} color={planetColor} distance={20} />

      <Stars radius={120} depth={60} count={3800} factor={4} saturation={0} fade speed={0.4} />

      <CameraControls
        ref={controls}
        makeDefault
        minDistance={6}
        maxDistance={26}
        smoothTime={0.55}
        draggingSmoothTime={0.18}
        dollySpeed={0.55}
      />
      <CameraDirector level={level} diveTarget={diveTarget} controls={controls} />

      {level === 'globe' ? (
        <group>
          <GlobeBody radius={GLOBE_RADIUS} color="#3a72ff" glow="#1b3a8a" />
          <Atmosphere radius={GLOBE_RADIUS} color="#5aa9ff" />
          {categoryPlacements.map(({ cat, pos, normal }) => (
            <SurfaceMarker
              key={cat.id}
              placement={{ pos, normal }}
              color={cat.color}
              label={cat.shortName}
              sub={`${tools.filter((t) => t.category === cat.id).length} tools`}
              active={activeCategory?.id === cat.id}
              big
              onClick={() => onSelectCategory(cat, pos)}
              onHover={(h) => setHovered(h ? cat.id : null)}
            />
          ))}
        </group>
      ) : (
        <group>
          <GlobeBody radius={PLANET_RADIUS} color={planetColor} glow={planetGlow} />
          <Atmosphere radius={PLANET_RADIUS} color={planetColor} />
          {toolPlacements.map(({ tool, pos, normal }) => (
            <SurfaceMarker
              key={tool.id}
              placement={{ pos, normal }}
              color={planetColor}
              label={tool.name}
              active={activeTool?.id === tool.id}
              big={false}
              onClick={() => onSelectTool(tool)}
              onHover={(h) => setHovered(h ? tool.id : null)}
            />
          ))}
        </group>
      )}
    </>
  );
}

/* ------------------------------ shell UI --------------------------- */

const PANEL_BASE: CSSProperties = {
  position: 'absolute',
  background: 'rgba(8,12,26,0.72)',
  backdropFilter: 'blur(18px) saturate(140%)',
  WebkitBackdropFilter: 'blur(18px) saturate(140%)',
  border: '1px solid rgba(255,255,255,0.1)',
  borderRadius: 18,
  color: '#eaf3ff',
};

export function GlobeSwitch() {
  const [level, setLevel] = useState<Level>('globe');
  const [activeCategory, setActiveCategory] = useState<ToolCategory | null>(null);
  const [activeTool, setActiveTool] = useState<AITool | null>(null);
  const [diveTarget, setDiveTarget] = useState<THREE.Vector3 | null>(null);
  const [, setHovered] = useState<string | null>(null);

  const handleSelectCategory = useCallback((cat: ToolCategory, pos: THREE.Vector3) => {
    setActiveCategory(cat);
    setActiveTool(null);
    setDiveTarget(pos.clone());
    setLevel('planet');
  }, []);

  const handleSelectTool = useCallback((tool: AITool) => {
    setActiveTool(tool);
  }, []);

  const flyToGlobe = useCallback(() => {
    setLevel('globe');
    setActiveTool(null);
    setActiveCategory(null);
    setDiveTarget(null);
  }, []);

  const closeTool = useCallback(() => setActiveTool(null), []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      if (activeTool) closeTool();
      else if (level === 'planet') flyToGlobe();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [activeTool, level, closeTool, flyToGlobe]);

  const related = useMemo(() => {
    if (!activeTool) return [];
    return activeTool.relationIds
      .map((id) => toolById.get(id))
      .filter((t): t is AITool => Boolean(t))
      .slice(0, 4);
  }, [activeTool]);

  const accent = activeCategory?.color ?? '#6ee7ff';

  return (
    <div className="absolute inset-0 overflow-hidden" style={{ background: '#03040b' }}>
      <Canvas
        frameloop="always"
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: false }}
        camera={{ fov: 42, near: 0.1, far: 400, position: [3, 4, 13.5] }}
      >
        <GlobeScene
          level={level}
          activeCategory={activeCategory}
          activeTool={activeTool}
          diveTarget={diveTarget}
          onSelectCategory={handleSelectCategory}
          onSelectTool={handleSelectTool}
          setHovered={setHovered}
        />
      </Canvas>

      {/* top chrome: breadcrumb + zoom-out (generous top padding) */}
      <div
        style={{
          position: 'absolute',
          top: 64,
          left: 24,
          right: 24,
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          pointerEvents: 'none',
        }}
      >
        <div
          style={{
            ...PANEL_BASE,
            position: 'relative',
            padding: '8px 14px',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            fontSize: 13,
            pointerEvents: 'auto',
          }}
        >
          <button
            onClick={flyToGlobe}
            style={{
              background: 'none',
              border: 'none',
              color: level === 'globe' ? '#fff' : 'rgba(220,235,250,0.7)',
              fontWeight: level === 'globe' ? 700 : 500,
              cursor: 'pointer',
              padding: 0,
              fontSize: 13,
            }}
          >
            AI Ecosystem
          </button>
          {activeCategory ? (
            <>
              <span style={{ color: 'rgba(180,200,220,0.45)' }}>/</span>
              <span style={{ color: accent, fontWeight: 700 }}>{activeCategory.shortName}</span>
            </>
          ) : null}
          {activeTool ? (
            <>
              <span style={{ color: 'rgba(180,200,220,0.45)' }}>/</span>
              <span style={{ color: '#fff', fontWeight: 600 }}>{activeTool.name}</span>
            </>
          ) : null}
        </div>

        {level === 'planet' ? (
          <button
            onClick={flyToGlobe}
            style={{
              ...PANEL_BASE,
              position: 'relative',
              padding: '8px 14px',
              fontSize: 12.5,
              fontWeight: 600,
              cursor: 'pointer',
              pointerEvents: 'auto',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            ← Zoom out
          </button>
        ) : null}
      </div>

      {/* level title / hint */}
      <div
        style={{
          position: 'absolute',
          top: 64,
          right: 24,
          textAlign: 'right',
          pointerEvents: 'none',
          maxWidth: 280,
        }}
      >
        <div
          style={{
            fontSize: 11,
            letterSpacing: '0.22em',
            textTransform: 'uppercase',
            color: 'rgba(150,180,210,0.6)',
          }}
        >
          {level === 'globe' ? 'Level 1 · Ecosystem' : 'Level 2 · Category Planet'}
        </div>
        <div style={{ fontSize: 22, fontWeight: 700, color: '#fff', marginTop: 2 }}>
          {level === 'globe' ? 'AI Tool Universe' : activeCategory?.name}
        </div>
        <div style={{ fontSize: 12, color: 'rgba(190,210,230,0.6)', marginTop: 4 }}>
          {level === 'globe'
            ? 'Click a region to dive into its world.'
            : activeCategory?.description}
        </div>
      </div>

      {/* tool info card */}
      {activeTool ? (
        <div
          style={{
            ...PANEL_BASE,
            left: 24,
            bottom: 28,
            width: 340,
            maxWidth: 'calc(100% - 48px)',
            padding: 18,
            boxShadow: `0 18px 60px rgba(0,0,0,0.5), 0 0 0 1px ${accent}33`,
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div
                style={{
                  fontSize: 10,
                  letterSpacing: '0.18em',
                  textTransform: 'uppercase',
                  color: accent,
                  fontWeight: 700,
                }}
              >
                {activeCategory?.shortName} · {activeTool.stage}
              </div>
              <div style={{ fontSize: 19, fontWeight: 700, color: '#fff', marginTop: 3 }}>
                {activeTool.name}
              </div>
            </div>
            <button
              onClick={closeTool}
              style={{
                background: 'rgba(255,255,255,0.08)',
                border: '1px solid rgba(255,255,255,0.12)',
                borderRadius: 999,
                width: 26,
                height: 26,
                color: '#cfe0f0',
                cursor: 'pointer',
                lineHeight: '1',
                fontSize: 14,
              }}
              aria-label="Close"
            >
              ×
            </button>
          </div>
          <p style={{ fontSize: 13, lineHeight: 1.5, color: 'rgba(214,228,242,0.85)', marginTop: 10 }}>
            {activeTool.summary}
          </p>
          {related.length ? (
            <div style={{ marginTop: 12 }}>
              <div
                style={{
                  fontSize: 10,
                  letterSpacing: '0.16em',
                  textTransform: 'uppercase',
                  color: 'rgba(160,185,210,0.6)',
                  marginBottom: 6,
                }}
              >
                Connects to
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {related.map((r) => (
                  <button
                    key={r.id}
                    onClick={() => setActiveTool(r)}
                    style={{
                      fontSize: 11.5,
                      padding: '4px 10px',
                      borderRadius: 999,
                      border: '1px solid rgba(255,255,255,0.14)',
                      background: 'rgba(255,255,255,0.05)',
                      color: '#dcebff',
                      cursor: 'pointer',
                    }}
                  >
                    {r.name}
                  </button>
                ))}
              </div>
            </div>
          ) : null}
          {activeTool.url ? (
            <a
              href={activeTool.url}
              target="_blank"
              rel="noreferrer"
              style={{
                display: 'inline-block',
                marginTop: 14,
                fontSize: 12.5,
                fontWeight: 600,
                color: accent,
                textDecoration: 'none',
              }}
            >
              Open tool ↗
            </a>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
