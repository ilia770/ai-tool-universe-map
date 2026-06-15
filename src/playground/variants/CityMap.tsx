import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from 'react';
import { Canvas, useFrame, useThree, type ThreeEvent } from '@react-three/fiber';
import { CameraControls, Text } from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  categoryById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

/* ------------------------------------------------------------------ *
 * Direction F — "AI City" (CodeCity / software-metropolis metaphor)
 *
 * Research (Wettel & Lanza, CodeCity 2008): software systems are drawn
 * as a 3D city. PACKAGES -> DISTRICTS (nested rectangular plots laid
 * out with a rectangle-packing / treemap algorithm), CLASSES ->
 * BUILDINGS whose HEIGHT and FOOTPRINT encode source metrics (methods,
 * LOC). Consistent locality keeps the viewer oriented; colour encodes
 * structure. The technique is plain rasterised 3D boxes on a ground
 * plane with an orbit/fly camera — no exotic GPU work.
 *
 * Here we emulate it with our stack: each CATEGORY is a tinted DISTRICT
 * placed by category.angle on a dark reflective ground; each TOOL is a
 * neon TOWER on its district, height driven by connectivity
 * (relationIds) + orbit, with emissive category colour + lit window
 * rows. CameraControls flies low and angled (Tron / SimCity skyline);
 * hover raises a label, click focuses the tower and opens an info card.
 * ------------------------------------------------------------------ */

const TOP_PAD = 64; // keep scene clear of the lab top chrome

const DISTRICT_RADIUS = 30; // distance of district centres from origin
const PLOT_HALF = 9; // half-extent of a district plot
const GRID = 0.9; // gap between buildings on the plot grid

/** Deterministic 0..1 PRNG (mulberry32) — no Math.random at render. */
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

interface Building {
  tool: AITool;
  category: ToolCategory;
  x: number; // world x
  z: number; // world z
  height: number;
  footprint: number; // building width/depth
  color: THREE.Color;
}

interface District {
  category: ToolCategory;
  cx: number;
  cz: number;
  buildings: Building[];
  color: THREE.Color;
}

/* Tower height from connectivity (relationIds) blended with orbit depth,
 * mirroring CodeCity's metric->height mapping. */
function towerHeight(tool: AITool): number {
  const conn = tool.relationIds.length; // 1..6
  const orbitBoost = (3 - tool.orbit) * 0.6; // inner orbit => taller
  const base = 2.2 + conn * 1.7 + orbitBoost;
  return tool.id === 'founder-os' ? base + 6 : base;
}

/* Treemap-ish row layout of a district's towers onto a square plot.
 * Deterministic, no per-frame work — all computed once at module init. */
function layoutDistrict(category: ToolCategory): District {
  const a = (category.angle * Math.PI) / 180;
  const cx = Math.cos(a) * DISTRICT_RADIUS;
  const cz = Math.sin(a) * DISTRICT_RADIUS;
  const color = new THREE.Color(category.color);

  const list = tools.filter((t) => t.category === category.id);
  const rng = makeRng(category.id.length * 9973 + list.length * 131 + 7);

  // Square-ish grid packing inside the plot.
  const cols = Math.max(1, Math.ceil(Math.sqrt(list.length)));
  const cell = (PLOT_HALF * 2 - GRID) / cols;

  const buildings: Building[] = list.map((tool, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    const rowsUsed = Math.ceil(list.length / cols);
    // jitter keeps the skyline organic but stays deterministic
    const jx = (rng() - 0.5) * cell * 0.18;
    const jz = (rng() - 0.5) * cell * 0.18;
    const lx = -PLOT_HALF + GRID / 2 + cell * (col + 0.5) + jx;
    const lz = -PLOT_HALF + GRID / 2 + cell * (row + 0.5) + jz;
    const usedSpan = cell * rowsUsed;
    const centreShift = (PLOT_HALF * 2 - usedSpan) / 2;
    return {
      tool,
      category,
      x: cx + lx,
      z: cz + lz + centreShift,
      height: towerHeight(tool),
      footprint: Math.min(cell * 0.62, 2.4),
      color,
    };
  });

  return { category, cx, cz, buildings, color };
}

const DISTRICTS: District[] = categories.map(layoutDistrict);
const ALL_BUILDINGS: Building[] = DISTRICTS.flatMap((d) => d.buildings);

/* Shared geometries / materials at module scope — never reallocated. */
const BOX = new THREE.BoxGeometry(1, 1, 1);
const PLOT_GEO = new THREE.PlaneGeometry(PLOT_HALF * 2, PLOT_HALF * 2);
const PLOT_EDGES = new THREE.EdgesGeometry(PLOT_GEO);

/* ------------------------------------------------------------------ *
 * Window texture — a tower face with a grid of lit/dark windows.
 * Built once via canvas; reused as emissive map on every tower.
 * ------------------------------------------------------------------ */
function makeWindowTexture(): THREE.Texture {
  const c = document.createElement('canvas');
  c.width = 64;
  c.height = 128;
  const ctx = c.getContext('2d');
  const tex = new THREE.CanvasTexture(c);
  if (!ctx) return tex;
  ctx.fillStyle = '#05060d';
  ctx.fillRect(0, 0, 64, 128);
  const rng = makeRng(20240611);
  const cols = 4;
  const rows = 9;
  const pad = 5;
  const cw = (64 - pad * (cols + 1)) / cols;
  const ch = (128 - pad * (rows + 1)) / rows;
  for (let r = 0; r < rows; r++) {
    for (let cc = 0; cc < cols; cc++) {
      const lit = rng() > 0.42;
      const v = lit ? 0.55 + rng() * 0.45 : 0.04;
      const g = Math.floor(255 * v);
      ctx.fillStyle = `rgb(${g},${g},${Math.min(255, g + 40)})`;
      ctx.fillRect(pad + cc * (cw + pad), pad + r * (ch + pad), cw, ch);
    }
  }
  tex.needsUpdate = true;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  return tex;
}

/* ------------------------------------------------------------------ *
 * Ground: dark reflective grid plane + neon district outlines + fog.
 * ------------------------------------------------------------------ */
function Ground() {
  const gridTex = useMemo(() => {
    const c = document.createElement('canvas');
    c.width = 256;
    c.height = 256;
    const ctx = c.getContext('2d');
    const tex = new THREE.CanvasTexture(c);
    if (!ctx) return tex;
    ctx.fillStyle = '#04060f';
    ctx.fillRect(0, 0, 256, 256);
    ctx.strokeStyle = 'rgba(90,150,220,0.22)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 256; i += 32) {
      ctx.beginPath();
      ctx.moveTo(i, 0);
      ctx.lineTo(i, 256);
      ctx.moveTo(0, i);
      ctx.lineTo(256, i);
      ctx.stroke();
    }
    tex.needsUpdate = true;
    tex.wrapS = THREE.RepeatWrapping;
    tex.wrapT = THREE.RepeatWrapping;
    tex.repeat.set(60, 60);
    return tex;
  }, []);

  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.02, 0]} receiveShadow>
      <planeGeometry args={[260, 260]} />
      <meshStandardMaterial
        color="#04060f"
        map={gridTex}
        emissive="#0a1430"
        emissiveIntensity={0.5}
        roughness={0.55}
        metalness={0.7}
      />
    </mesh>
  );
}

/* Tinted district plot + glowing edge frame. */
function DistrictPlot({
  district,
  active,
}: {
  district: District;
  active: boolean;
}) {
  return (
    <group position={[district.cx, 0, district.cz]}>
      <mesh
        rotation={[-Math.PI / 2, 0, 0]}
        position={[0, 0.015, 0]}
        geometry={PLOT_GEO}
      >
        <meshStandardMaterial
          color={district.color}
          transparent
          opacity={active ? 0.22 : 0.1}
          emissive={district.color}
          emissiveIntensity={active ? 0.5 : 0.22}
          roughness={0.4}
          metalness={0.3}
        />
      </mesh>
      {/* glowing plot frame */}
      <lineSegments position={[0, 0.05, 0]} geometry={PLOT_EDGES}>
        <lineBasicMaterial
          color={district.color}
          transparent
          opacity={active ? 0.9 : 0.45}
        />
      </lineSegments>
    </group>
  );
}

/* ------------------------------------------------------------------ *
 * Tower — a neon building with lit-window emissive faces.
 * ------------------------------------------------------------------ */
type TowerState = 'normal' | 'hovered' | 'selected' | 'dimmed';

function Tower({
  b,
  state,
  windowTex,
  onHover,
  onSelect,
}: {
  b: Building;
  state: TowerState;
  windowTex: THREE.Texture;
  onHover: (id: string | null) => void;
  onSelect: (id: string) => void;
}) {
  const matRef = useRef<THREE.MeshStandardMaterial>(null);
  const glowRef = useRef<number>(state === 'selected' ? 1 : 0);

  const baseEmissive = useMemo(() => {
    const c = b.color.clone();
    return c.multiplyScalar(0.55);
  }, [b.color]);

  // per-tower window map clone so repeat can differ slightly
  const tex = useMemo(() => {
    const t = windowTex.clone();
    t.needsUpdate = true;
    const rows = Math.max(2, Math.round(b.height / 1.6));
    t.repeat.set(1, rows);
    return t;
  }, [windowTex, b.height]);

  useFrame((_, dt) => {
    const target =
      state === 'selected' ? 1 : state === 'hovered' ? 0.7 : 0;
    glowRef.current += (target - glowRef.current) * Math.min(1, dt * 8);
    const m = matRef.current;
    if (m) {
      const lit = state === 'dimmed' ? 0.45 : 1;
      m.emissiveIntensity = (0.7 + glowRef.current * 1.8) * lit;
      m.opacity = state === 'dimmed' ? 0.35 : 1;
    }
  });

  const dim = state === 'dimmed';

  return (
    <group position={[b.x, b.height / 2, b.z]}>
      <mesh
        geometry={BOX}
        scale={[b.footprint, b.height, b.footprint]}
        onPointerOver={(e: ThreeEvent<PointerEvent>) => {
          e.stopPropagation();
          onHover(b.tool.id);
        }}
        onPointerOut={() => onHover(null)}
        onClick={(e: ThreeEvent<MouseEvent>) => {
          e.stopPropagation();
          onSelect(b.tool.id);
        }}
      >
        <meshStandardMaterial
          ref={matRef}
          color="#0b0f1c"
          emissive={baseEmissive}
          emissiveMap={tex}
          emissiveIntensity={0.8}
          roughness={0.35}
          metalness={0.6}
          transparent
          opacity={dim ? 0.35 : 1}
        />
      </mesh>
      {/* rooftop beacon */}
      <mesh position={[0, b.height / 2 + 0.18, 0]}>
        <boxGeometry args={[b.footprint * 0.25, 0.28, b.footprint * 0.25]} />
        <meshStandardMaterial
          color={b.color}
          emissive={b.color}
          emissiveIntensity={state === 'normal' ? 1.4 : 2.6}
          toneMapped={false}
        />
      </mesh>
    </group>
  );
}

/* Floating label that rises above a hovered / selected tower. */
function TowerLabel({ b }: { b: Building }) {
  return (
    <Text
      position={[b.x, b.height + 2.1, b.z]}
      fontSize={1.05}
      color="#eaf4ff"
      anchorX="center"
      anchorY="middle"
      outlineWidth={0.06}
      outlineColor="#04060f"
    >
      {b.tool.name}
    </Text>
  );
}

/* ------------------------------------------------------------------ *
 * Animated district light beams (Tron pulse) — precomputed, ref-mutated.
 * ------------------------------------------------------------------ */
function Beacons() {
  const ref = useRef<THREE.Group>(null);
  const phases = useMemo(() => DISTRICTS.map((_, i) => i * 0.9), []);
  useFrame(({ clock }) => {
    const g = ref.current;
    if (!g) return;
    const t = clock.elapsedTime;
    g.children.forEach((child, i) => {
      const s = 0.6 + Math.sin(t * 1.4 + phases[i]) * 0.4;
      child.scale.y = s;
    });
  });
  return (
    <group ref={ref}>
      {DISTRICTS.map((d) => (
        <mesh key={d.category.id} position={[d.cx, 12, d.cz]}>
          <cylinderGeometry args={[0.12, 0.12, 24, 6]} />
          <meshBasicMaterial
            color={d.color}
            transparent
            opacity={0.14}
            toneMapped={false}
          />
        </mesh>
      ))}
    </group>
  );
}

/* ------------------------------------------------------------------ *
 * Camera flythrough on first mount + click-to-focus.
 * ------------------------------------------------------------------ */
function Rig({
  controls,
  focusId,
}: {
  controls: React.RefObject<CameraControls | null>;
  focusId: string | null;
}) {
  const { camera } = useThree();
  const intro = useRef(false);

  useEffect(() => {
    if (intro.current) return;
    intro.current = true;
    const c = controls.current;
    if (!c) return;
    camera.position.set(-48, 40, 58);
    c.setLookAt(-48, 40, 58, 0, 4, 0, false);
    // glide into a low, angled skyline approach
    c.setLookAt(34, 14, 40, 0, 6, 0, true);
  }, [controls, camera]);

  useEffect(() => {
    const c = controls.current;
    if (!c || !focusId) return;
    const b = ALL_BUILDINGS.find((x) => x.tool.id === focusId);
    if (!b) return;
    const dist = 14 + b.height * 0.6;
    const dirX = b.x === 0 ? 1 : b.x;
    const dirZ = b.z === 0 ? 1 : b.z;
    const len = Math.hypot(dirX, dirZ) || 1;
    const px = b.x + (dirX / len) * dist;
    const pz = b.z + (dirZ / len) * dist;
    c.setLookAt(px, b.height * 0.7 + 6, pz, b.x, b.height * 0.5, b.z, true);
  }, [controls, focusId]);

  return null;
}

/* ------------------------------------------------------------------ *
 * Scene
 * ------------------------------------------------------------------ */
function CityScene({
  hoveredId,
  selectedId,
  onHover,
  onSelect,
  controls,
}: {
  hoveredId: string | null;
  selectedId: string | null;
  onHover: (id: string | null) => void;
  onSelect: (id: string) => void;
  controls: React.RefObject<CameraControls | null>;
}) {
  const windowTex = useMemo(() => makeWindowTexture(), []);

  const neighbours = useMemo(() => {
    if (!selectedId) return null;
    const tool = tools.find((t) => t.id === selectedId);
    const set = new Set<string>(tool?.relationIds ?? []);
    set.add(selectedId);
    return set;
  }, [selectedId]);

  const activeCat = useMemo(() => {
    const id = selectedId ?? hoveredId;
    if (!id) return null;
    return tools.find((t) => t.id === id)?.category ?? null;
  }, [selectedId, hoveredId]);

  const labelBuilding = useMemo(() => {
    const id = hoveredId ?? selectedId;
    return id ? ALL_BUILDINGS.find((b) => b.tool.id === id) ?? null : null;
  }, [hoveredId, selectedId]);

  return (
    <>
      <color attach="background" args={['#03040a']} />
      <fog attach="fog" args={['#04060f', 45, 135]} />
      <ambientLight intensity={0.4} />
      <hemisphereLight args={['#22407a', '#02030a', 0.6]} />
      <directionalLight position={[40, 60, 20]} intensity={0.5} color="#9fc4ff" />
      <pointLight position={[0, 30, 0]} intensity={1.1} color="#6ee7ff" distance={140} />

      <CameraControls
        ref={controls}
        makeDefault
        minDistance={10}
        maxDistance={140}
        maxPolarAngle={Math.PI / 2.05}
        smoothTime={0.5}
        dollySpeed={0.5}
      />
      <Rig controls={controls} focusId={selectedId} />

      <Ground />
      <Beacons />

      {DISTRICTS.map((d) => (
        <DistrictPlot
          key={d.category.id}
          district={d}
          active={activeCat === d.category.id}
        />
      ))}

      {ALL_BUILDINGS.map((b) => {
        let state: TowerState = 'normal';
        if (selectedId) {
          if (b.tool.id === selectedId) state = 'selected';
          else if (neighbours?.has(b.tool.id)) state = 'hovered';
          else state = 'dimmed';
        } else if (hoveredId === b.tool.id) {
          state = 'hovered';
        } else if (activeCat && b.tool.category !== activeCat) {
          state = 'dimmed';
        }
        return (
          <Tower
            key={b.tool.id}
            b={b}
            state={state}
            windowTex={windowTex}
            onHover={onHover}
            onSelect={onSelect}
          />
        );
      })}

      {/* district name plaques */}
      {DISTRICTS.map((d) => (
        <Text
          key={`lbl-${d.category.id}`}
          position={[d.cx, 0.4, d.cz - PLOT_HALF - 1.4]}
          rotation={[-Math.PI / 2.2, 0, 0]}
          fontSize={1.5}
          color={d.category.color}
          anchorX="center"
          anchorY="middle"
          outlineWidth={0.04}
          outlineColor="#03040a"
          fillOpacity={activeCat && activeCat !== d.category.id ? 0.3 : 0.95}
        >
          {d.category.shortName.toUpperCase()}
        </Text>
      ))}

      {labelBuilding && <TowerLabel b={labelBuilding} />}
    </>
  );
}

/* ------------------------------------------------------------------ *
 * Info card (HTML overlay) for the focused tower.
 * ------------------------------------------------------------------ */
function InfoCard({
  tool,
  onClose,
}: {
  tool: AITool;
  onClose: () => void;
}) {
  const cat = categoryById.get(tool.category);
  const related = tool.relationIds
    .map((id) => tools.find((t) => t.id === id))
    .filter((t): t is AITool => Boolean(t));

  const accent = cat?.color ?? '#6ee7ff';
  const cardStyle: CSSProperties = {
    borderColor: `${accent}55`,
    boxShadow: `0 0 40px ${accent}22, inset 0 0 0 1px ${accent}22`,
  };

  return (
    <div
      className="pointer-events-auto absolute right-4 bottom-4 w-[300px] rounded-2xl border bg-[#070b16]/90 p-4 text-white backdrop-blur-xl"
      style={cardStyle}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div
            className="text-[10px] font-semibold uppercase tracking-[0.18em]"
            style={{ color: accent }}
          >
            {cat?.name ?? tool.category}
          </div>
          <div className="mt-0.5 text-lg font-semibold leading-tight">
            {tool.name}
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="rounded-md px-2 py-0.5 text-sm text-white/50 hover:bg-white/10 hover:text-white"
        >
          ✕
        </button>
      </div>

      <p className="mt-2 text-[13px] leading-snug text-white/70">
        {tool.summary}
      </p>

      <div className="mt-3 flex flex-wrap gap-1.5 text-[10px]">
        <span className="rounded-full bg-white/8 px-2 py-0.5 uppercase tracking-wide text-white/60">
          {tool.stage}
        </span>
        <span className="rounded-full bg-white/8 px-2 py-0.5 uppercase tracking-wide text-white/60">
          {tool.relationIds.length} links
        </span>
        <span className="rounded-full bg-white/8 px-2 py-0.5 uppercase tracking-wide text-white/60">
          orbit {tool.orbit}
        </span>
      </div>

      {related.length > 0 && (
        <div className="mt-3">
          <div className="text-[10px] uppercase tracking-[0.16em] text-white/40">
            Connected districts
          </div>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {related.map((r) => {
              const rc = categoryById.get(r.category);
              return (
                <span
                  key={r.id}
                  className="rounded-md px-2 py-0.5 text-[11px] font-medium"
                  style={{
                    color: rc?.color ?? '#fff',
                    background: `${rc?.color ?? '#fff'}1a`,
                  }}
                >
                  {r.name}
                </span>
              );
            })}
          </div>
        </div>
      )}

      {tool.url && (
        <a
          href={tool.url}
          target="_blank"
          rel="noreferrer"
          className="mt-3 inline-block text-[12px] font-medium"
          style={{ color: accent }}
        >
          Visit site →
        </a>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ *
 * Public component
 * ------------------------------------------------------------------ */
export function CityMap() {
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const controls = useRef<CameraControls>(null);

  const handleSelect = useCallback((id: string) => {
    setSelectedId((cur) => (cur === id ? null : id));
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setSelectedId(null);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const selectedTool = useMemo(
    () => (selectedId ? tools.find((t) => t.id === selectedId) ?? null : null),
    [selectedId],
  );

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#03040a]">
      {/* horizon vignette + neon haze */}
      <div
        className="pointer-events-none absolute inset-0 z-10"
        style={{
          background:
            'radial-gradient(120% 80% at 50% 8%, rgba(20,40,90,0.35), transparent 55%), radial-gradient(140% 60% at 50% 100%, rgba(110,231,255,0.12), transparent 60%)',
        }}
      />

      <div
        className="absolute inset-x-0 bottom-0"
        style={{ top: TOP_PAD }}
      >
        <Canvas
          dpr={[1, 2]}
          shadows
          gl={{ antialias: true, alpha: false }}
          camera={{ position: [34, 14, 40], fov: 50, near: 0.1, far: 400 }}
        >
          <CityScene
            hoveredId={hoveredId}
            selectedId={selectedId}
            onHover={setHoveredId}
            onSelect={handleSelect}
            controls={controls}
          />
        </Canvas>
      </div>

      {/* title chip */}
      <div className="pointer-events-none absolute left-4 z-20" style={{ top: TOP_PAD + 12 }}>
        <div className="rounded-full border border-white/10 bg-black/40 px-3 py-1.5 text-[11px] font-medium uppercase tracking-[0.22em] text-white/70 backdrop-blur">
          AI City · {tools.length} towers · {categories.length} districts
        </div>
        <div className="mt-1.5 pl-1 text-[11px] text-white/40">
          Hover a tower · click to focus · drag to fly
        </div>
      </div>

      {/* info card */}
      <div className="pointer-events-none absolute inset-0 z-20">
        {selectedTool && (
          <InfoCard tool={selectedTool} onClose={() => setSelectedId(null)} />
        )}
      </div>
    </div>
  );
}
