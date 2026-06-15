import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import {
  Billboard,
  CameraControls,
  Html,
  Stars,
  Text,
} from '@react-three/drei';
import * as THREE from 'three';
import {
  tools,
  categories,
  toolById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';
import { useInAppBrowser } from '../../components/useInAppBrowser';

/* ------------------------------------------------------------------ *
 * AI Galaxy / RTS Map (Direction C)
 *
 * Zoom hierarchy driven by explicit selection + camera distance:
 *   GALAXY  -> 8 category clusters spread across the galaxy plane.
 *   SECTOR  -> fly into a cluster, its tools bloom as individual suns.
 *   STAR    -> click a tool-sun, camera centres it + info card.
 *
 * Navigation: scroll-zoom + click-to-fly via drei CameraControls,
 * Esc / breadcrumb to pull back out. Label visibility is gated by the
 * active level so the view never clutters.
 * ------------------------------------------------------------------ */

type Level = 'galaxy' | 'sector' | 'star';

const GALAXY_RADIUS = 26; // how far sector clusters sit from centre
const SECTOR_TOOL_SPREAD = 7.5; // radius of a tool disc inside a sector
const PLANE_TILT = -Math.PI / 2.7; // tilt of the galaxy plane

/** Deterministic 0..1 PRNG (mulberry32) so instanced layers stay stable. */
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

/** Polar (category.angle, in degrees) -> world position on the tilted plane. */
function sectorPosition(angleDeg: number): THREE.Vector3 {
  const a = (angleDeg * Math.PI) / 180;
  return new THREE.Vector3(
    Math.cos(a) * GALAXY_RADIUS,
    0,
    Math.sin(a) * GALAXY_RADIUS,
  );
}

/** Deterministic per-tool offset inside its sector (golden-angle spiral). */
function toolOffset(index: number, count: number): THREE.Vector3 {
  const golden = Math.PI * (3 - Math.sqrt(5));
  const t = count <= 1 ? 0 : index / (count - 1);
  const r = SECTOR_TOOL_SPREAD * (0.28 + 0.72 * Math.sqrt(t));
  const a = index * golden;
  // Gentle vertical wobble so suns don't sit perfectly co-planar.
  const y = Math.sin(index * 1.3) * 1.1;
  return new THREE.Vector3(Math.cos(a) * r, y, Math.sin(a) * r);
}

/* ------------------------------------------------------------------ *
 * Background: nebula gradient dome + parallax coloured dust.
 * ------------------------------------------------------------------ */

function NebulaDome() {
  // Vertical gradient sphere (rendered from the inside) as deep-space backdrop.
  const uniforms = useMemo(
    () => ({
      topColor: { value: new THREE.Color('#0a0524') },
      midColor: { value: new THREE.Color('#1a0b3a') },
      botColor: { value: new THREE.Color('#04020f') },
    }),
    [],
  );
  return (
    <mesh scale={[1, 1, 1]}>
      <sphereGeometry args={[140, 32, 32]} />
      <shaderMaterial
        uniforms={uniforms}
        side={THREE.BackSide}
        depthWrite={false}
        vertexShader={`
          varying vec3 vWorld;
          void main() {
            vWorld = position;
            gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          }
        `}
        fragmentShader={`
          varying vec3 vWorld;
          uniform vec3 topColor;
          uniform vec3 midColor;
          uniform vec3 botColor;
          void main() {
            float h = normalize(vWorld).y * 0.5 + 0.5;
            vec3 c = mix(botColor, midColor, smoothstep(0.0, 0.55, h));
            c = mix(c, topColor, smoothstep(0.45, 1.0, h));
            gl_FragColor = vec4(c, 1.0);
          }
        `}
      />
    </mesh>
  );
}

/** Coloured dust band on the galaxy plane — instanced, allocation-free. */
function GalaxyDust({ count = 1400 }: { count?: number }) {
  const ref = useRef<THREE.InstancedMesh>(null);
  const { positions, colors } = useMemo(() => {
    const pos = new Float32Array(count * 3);
    const col = new Float32Array(count * 3);
    const palette = categories.map((c) => new THREE.Color(c.color));
    const dummy = new THREE.Color();
    const rand = makeRng(0x9e3779b1 ^ count);
    for (let i = 0; i < count; i++) {
      const r = 6 + Math.pow(rand(), 0.6) * (GALAXY_RADIUS + 10);
      const a = rand() * Math.PI * 2;
      const spread = (rand() - 0.5) * 2.4;
      pos[i * 3] = Math.cos(a) * r;
      pos[i * 3 + 1] = spread;
      pos[i * 3 + 2] = Math.sin(a) * r;
      dummy.copy(palette[Math.floor(rand() * palette.length)]);
      dummy.multiplyScalar(0.4 + rand() * 0.6);
      col[i * 3] = dummy.r;
      col[i * 3 + 1] = dummy.g;
      col[i * 3 + 2] = dummy.b;
    }
    return { positions: pos, colors: col };
  }, [count]);

  useEffect(() => {
    const mesh = ref.current;
    if (!mesh) return;
    const m = new THREE.Matrix4();
    const c = new THREE.Color();
    for (let i = 0; i < count; i++) {
      m.makeScale(0.16, 0.16, 0.16);
      m.setPosition(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
      mesh.setMatrixAt(i, m);
      c.fromArray(colors, i * 3);
      mesh.setColorAt(i, c);
    }
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  }, [count, positions, colors]);

  return (
    <instancedMesh ref={ref} args={[undefined, undefined, count]} frustumCulled={false}>
      <sphereGeometry args={[1, 6, 6]} />
      <meshBasicMaterial transparent opacity={0.55} depthWrite={false} />
    </instancedMesh>
  );
}

/* ------------------------------------------------------------------ *
 * Reusable radial-glow sprite (canvas texture, built once).
 * ------------------------------------------------------------------ */

function useGlowTexture(): THREE.Texture {
  return useMemo(() => {
    const size = 128;
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
      g.addColorStop(0, 'rgba(255,255,255,1)');
      g.addColorStop(0.25, 'rgba(255,255,255,0.55)');
      g.addColorStop(0.6, 'rgba(255,255,255,0.12)');
      g.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, size, size);
    }
    const tex = new THREE.CanvasTexture(canvas);
    tex.needsUpdate = true;
    return tex;
  }, []);
}

/* ------------------------------------------------------------------ *
 * GALAXY level: one glowing cluster per category.
 * ------------------------------------------------------------------ */

function SectorCluster({
  category,
  count,
  glowTex,
  dimmed,
  onSelect,
}: {
  category: ToolCategory;
  count: number;
  glowTex: THREE.Texture;
  dimmed: boolean;
  onSelect: () => void;
}) {
  const groupRef = useRef<THREE.Group>(null);
  const coreRef = useRef<THREE.Mesh>(null);
  const [hovered, setHovered] = useState(false);
  const pos = useMemo(() => sectorPosition(category.angle), [category.angle]);
  const color = useMemo(() => new THREE.Color(category.color), [category.color]);

  useFrame((state) => {
    const t = state.clock.elapsedTime;
    if (coreRef.current) {
      const pulse = 1 + Math.sin(t * 1.6 + category.angle) * 0.08;
      coreRef.current.scale.setScalar(pulse * (hovered ? 1.25 : 1));
    }
    const g = groupRef.current;
    if (g) {
      const target = dimmed ? 0.18 : 1;
      const mat = (g as unknown as { __op?: number }).__op ?? 1;
      const next = mat + (target - mat) * 0.08;
      (g as unknown as { __op?: number }).__op = next;
      g.traverse((o) => {
        const mesh = o as THREE.Mesh & { material?: THREE.Material & { opacity?: number } };
        if (mesh.material && 'opacity' in mesh.material) {
          mesh.material.transparent = true;
          mesh.material.opacity = next;
        }
      });
    }
  });

  return (
    <group ref={groupRef} position={pos}>
      {/* Nebula glow disc */}
      <sprite scale={[14, 14, 1]}>
        <spriteMaterial
          map={glowTex}
          color={color}
          transparent
          opacity={0.9}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </sprite>

      {/* Clickable bright core */}
      <mesh
        ref={coreRef}
        onClick={(e) => {
          e.stopPropagation();
          onSelect();
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          setHovered(true);
          document.body.style.cursor = 'pointer';
        }}
        onPointerOut={() => {
          setHovered(false);
          document.body.style.cursor = 'auto';
        }}
      >
        <sphereGeometry args={[1.5, 24, 24]} />
        <meshBasicMaterial color={color} toneMapped={false} />
      </mesh>

      {/* Surrounding mini-stars hinting at the tools inside */}
      <points>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[clusterPoints(count), 3]}
          />
        </bufferGeometry>
        <pointsMaterial
          size={0.5}
          color={color}
          transparent
          opacity={0.85}
          sizeAttenuation
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </points>

      {/* Sector label (galaxy level only) */}
      <Billboard position={[0, 4.4, 0]}>
        <Text
          fontSize={1.5}
          color="#ffffff"
          anchorX="center"
          anchorY="middle"
          outlineWidth={0.04}
          outlineColor="#000000"
        >
          {category.name}
        </Text>
        <Text
          position={[0, -1.5, 0]}
          fontSize={0.85}
          color={category.color}
          anchorX="center"
          anchorY="middle"
        >
          {`${count} tools`}
        </Text>
      </Billboard>
    </group>
  );
}

/** Small fixed point cloud around a cluster core. */
function clusterPoints(count: number): Float32Array {
  const n = Math.min(Math.max(count, 4), 14);
  const arr = new Float32Array(n * 3);
  const golden = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < n; i++) {
    const r = 2.4 + (i / n) * 2.6;
    const a = i * golden;
    arr[i * 3] = Math.cos(a) * r;
    arr[i * 3 + 1] = Math.sin(i * 1.7) * 1.2;
    arr[i * 3 + 2] = Math.sin(a) * r;
  }
  return arr;
}

/* ------------------------------------------------------------------ *
 * SECTOR level: a category's tools as individual suns.
 * ------------------------------------------------------------------ */

function ToolSun({
  tool,
  worldPos,
  color,
  selected,
  onSelect,
}: {
  tool: AITool;
  worldPos: THREE.Vector3;
  color: THREE.Color;
  selected: boolean;
  onSelect: () => void;
}) {
  const ref = useRef<THREE.Mesh>(null);
  const [hovered, setHovered] = useState(false);

  useFrame((state) => {
    if (!ref.current) return;
    const pulse = 1 + Math.sin(state.clock.elapsedTime * 2 + worldPos.x) * 0.07;
    ref.current.scale.setScalar(pulse * (hovered || selected ? 1.4 : 1));
  });

  return (
    <group position={worldPos}>
      <mesh
        ref={ref}
        onClick={(e) => {
          e.stopPropagation();
          onSelect();
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          setHovered(true);
          document.body.style.cursor = 'pointer';
        }}
        onPointerOut={() => {
          setHovered(false);
          document.body.style.cursor = 'auto';
        }}
      >
        <sphereGeometry args={[0.55, 20, 20]} />
        <meshStandardMaterial
          color={color}
          emissive={color}
          emissiveIntensity={selected ? 2.4 : 1.3}
          toneMapped={false}
        />
      </mesh>
      <Billboard position={[0, 1.2, 0]}>
        <Text
          fontSize={0.6}
          color="#ffffff"
          anchorX="center"
          anchorY="middle"
          outlineWidth={0.03}
          outlineColor="#000000"
          maxWidth={6}
        >
          {tool.name}
        </Text>
      </Billboard>
    </group>
  );
}

function SectorView({
  category,
  selectedToolId,
  onSelectTool,
}: {
  category: ToolCategory;
  selectedToolId: string | null;
  onSelectTool: (t: AITool) => void;
}) {
  const center = useMemo(() => sectorPosition(category.angle), [category.angle]);
  const color = useMemo(() => new THREE.Color(category.color), [category.color]);

  // Precompute tool positions + connection-line buffers once per category.
  const placed = useMemo(() => {
    const sectorTools = tools.filter((t) => t.category === category.id);
    return sectorTools.map((tool, i) => {
      const world = center.clone().add(toolOffset(i, sectorTools.length));
      const line = new Float32Array([
        center.x, center.y, center.z,
        world.x, world.y, world.z,
      ]);
      return { tool, world, line };
    });
  }, [category.id, center]);

  return (
    <group>
      {/* Faint connection lines from the sector core to each sun. */}
      {placed.map(({ tool, line }) => (
        <line key={`l-${tool.id}`}>
          <bufferGeometry>
            <bufferAttribute attach="attributes-position" args={[line, 3]} />
          </bufferGeometry>
          <lineBasicMaterial color={color} transparent opacity={0.22} />
        </line>
      ))}
      {placed.map(({ tool, world }) => (
        <ToolSun
          key={tool.id}
          tool={tool}
          worldPos={world}
          color={color}
          selected={selectedToolId === tool.id}
          onSelect={() => onSelectTool(tool)}
        />
      ))}
    </group>
  );
}

/* ------------------------------------------------------------------ *
 * Camera director: flies between levels + reports distance-based level.
 * ------------------------------------------------------------------ */

function CameraDirector({
  level,
  activeCategory,
  selectedTool,
  controlsRef,
  onDistanceZoomOut,
}: {
  level: Level;
  activeCategory: ToolCategory | null;
  selectedTool: AITool | null;
  controlsRef: React.RefObject<CameraControls | null>;
  onDistanceZoomOut: () => void;
}) {
  const { camera } = useThree();

  // Fly the camera whenever the logical target changes.
  useEffect(() => {
    const controls = controlsRef.current;
    if (!controls) return;

    if (level === 'galaxy') {
      controls.setLookAt(0, 34, 52, 0, 0, 0, true);
      return;
    }
    if (level === 'sector' && activeCategory) {
      const c = sectorPosition(activeCategory.angle);
      controls.setLookAt(c.x * 1.18, 14, c.z * 1.18 + 14, c.x, 0, c.z, true);
      return;
    }
    if (level === 'star' && selectedTool && activeCategory) {
      const center = sectorPosition(activeCategory.angle);
      const sectorTools = tools.filter((t) => t.category === activeCategory.id);
      const idx = sectorTools.findIndex((t) => t.id === selectedTool.id);
      const world = center.clone().add(toolOffset(idx, sectorTools.length));
      controls.setLookAt(world.x + 4, world.y + 3, world.z + 6, world.x, world.y, world.z, true);
    }
  }, [level, activeCategory, selectedTool, controlsRef]);

  // Distance-driven zoom-out: pulling far back from a sector returns to galaxy.
  const cooldown = useRef(0);
  useFrame((_, delta) => {
    cooldown.current = Math.max(0, cooldown.current - delta);
    if (level !== 'sector' || !activeCategory || cooldown.current > 0) return;
    const c = sectorPosition(activeCategory.angle);
    const dist = camera.position.distanceTo(c);
    if (dist > 46) {
      cooldown.current = 1.2;
      onDistanceZoomOut();
    }
  });

  return null;
}

/* ------------------------------------------------------------------ *
 * Rotating galaxy plane wrapper (subtle drift, paused when focused).
 * ------------------------------------------------------------------ */

function GalaxyPlane({
  level,
  children,
}: {
  level: Level;
  children: React.ReactNode;
}) {
  const ref = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (!ref.current) return;
    const speed = level === 'galaxy' ? 0.02 : 0.004;
    ref.current.rotation.y += delta * speed;
  });
  return (
    <group rotation={[PLANE_TILT + Math.PI / 2, 0, 0]}>
      <group ref={ref}>{children}</group>
    </group>
  );
}

/* ------------------------------------------------------------------ *
 * Scene root.
 * ------------------------------------------------------------------ */

function GalaxyScene({
  level,
  activeCategory,
  selectedTool,
  onSelectCategory,
  onSelectTool,
  onZoomOut,
  controlsRef,
}: {
  level: Level;
  activeCategory: ToolCategory | null;
  selectedTool: AITool | null;
  onSelectCategory: (c: ToolCategory) => void;
  onSelectTool: (t: AITool) => void;
  onZoomOut: () => void;
  controlsRef: React.RefObject<CameraControls | null>;
}) {
  const glowTex = useGlowTexture();
  const counts = useMemo(() => {
    const m = new Map<string, number>();
    for (const t of tools) m.set(t.category, (m.get(t.category) ?? 0) + 1);
    return m;
  }, []);

  return (
    <>
      <color attach="background" args={['#04020f']} />
      <fog attach="fog" args={['#06031a', 40, 130]} />
      <ambientLight intensity={0.6} />
      <pointLight position={[0, 30, 0]} intensity={1.2} color="#b9a6ff" />

      <NebulaDome />
      <Stars radius={120} depth={60} count={6000} factor={4} saturation={0} fade speed={0.6} />

      <GalaxyPlane level={level}>
        <GalaxyDust />

        {/* Sector clusters — always present; dimmed when a sector is focused. */}
        {categories.map((c) => (
          <SectorCluster
            key={c.id}
            category={c}
            count={counts.get(c.id) ?? 0}
            glowTex={glowTex}
            dimmed={level !== 'galaxy' && activeCategory?.id !== c.id}
            onSelect={() => onSelectCategory(c)}
          />
        ))}

        {/* Tool suns appear once a sector is active. */}
        {level !== 'galaxy' && activeCategory && (
          <SectorView
            category={activeCategory}
            selectedToolId={selectedTool?.id ?? null}
            onSelectTool={onSelectTool}
          />
        )}
      </GalaxyPlane>

      <CameraControls
        ref={controlsRef}
        minDistance={6}
        maxDistance={90}
        dollySpeed={0.6}
        smoothTime={0.45}
      />
      <CameraDirector
        level={level}
        activeCategory={activeCategory}
        selectedTool={selectedTool}
        controlsRef={controlsRef}
        onDistanceZoomOut={onZoomOut}
      />
    </>
  );
}

/* ------------------------------------------------------------------ *
 * Public component: Canvas + HUD overlay (breadcrumb, info card, hint).
 * ------------------------------------------------------------------ */

export function GalaxyMap() {
  const [activeCategory, setActiveCategory] = useState<ToolCategory | null>(null);
  const [selectedTool, setSelectedTool] = useState<AITool | null>(null);
  const controlsRef = useRef<CameraControls | null>(null);

  const level: Level = selectedTool ? 'star' : activeCategory ? 'sector' : 'galaxy';

  const goGalaxy = useCallback(() => {
    setSelectedTool(null);
    setActiveCategory(null);
  }, []);

  const goSector = useCallback(() => {
    setSelectedTool(null);
  }, []);

  const handleSelectCategory = useCallback((c: ToolCategory) => {
    setSelectedTool(null);
    setActiveCategory(c);
  }, []);

  const handleSelectTool = useCallback((t: AITool) => {
    setSelectedTool(t);
  }, []);

  // Esc: layered exit (star -> sector -> galaxy).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      if (selectedTool) goSector();
      else if (activeCategory) goGalaxy();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [selectedTool, activeCategory, goSector, goGalaxy]);

  const relations = useMemo(() => {
    if (!selectedTool) return [];
    return selectedTool.relationIds
      .map((id) => toolById.get(id))
      .filter((t): t is AITool => Boolean(t));
  }, [selectedTool]);

  return (
    <div className="absolute inset-0 h-full w-full overflow-hidden bg-[#04020f]">
      <Canvas
        camera={{ position: [0, 34, 52], fov: 50, near: 0.1, far: 400 }}
        gl={{ antialias: true, alpha: false }}
        dpr={[1, 2]}
        frameloop="always"
      >
        <GalaxyScene
          level={level}
          activeCategory={activeCategory}
          selectedTool={selectedTool}
          onSelectCategory={handleSelectCategory}
          onSelectTool={handleSelectTool}
          onZoomOut={goGalaxy}
          controlsRef={controlsRef}
        />
        {/* Star-level info card, anchored in 3D via Html. */}
        {selectedTool && activeCategory && (
          <Html fullscreen style={pointerNone} zIndexRange={[20, 0]}>
            <InfoCard
              tool={selectedTool}
              category={activeCategory}
              relations={relations}
              onClose={goSector}
            />
          </Html>
        )}
      </Canvas>

      {/* HUD: breadcrumb + level + hint. */}
      <div className="pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between p-5">
        <div className="pointer-events-auto flex items-center gap-2 text-sm">
          <Crumb active={level === 'galaxy'} onClick={goGalaxy}>
            Galaxy
          </Crumb>
          {activeCategory && (
            <>
              <span className="text-white/30">/</span>
              <Crumb active={level === 'sector'} onClick={goSector}>
                {activeCategory.name}
              </Crumb>
            </>
          )}
          {selectedTool && (
            <>
              <span className="text-white/30">/</span>
              <Crumb active>{selectedTool.name}</Crumb>
            </>
          )}
        </div>
        <div className="rounded-full border border-white/10 bg-black/40 px-3 py-1 text-[11px] uppercase tracking-[0.2em] text-white/60 backdrop-blur">
          {level} view
        </div>
      </div>

      <div className="pointer-events-none absolute inset-x-0 bottom-0 flex justify-center p-5">
        <p className="rounded-full border border-white/10 bg-black/40 px-4 py-1.5 text-xs text-white/55 backdrop-blur">
          {level === 'galaxy'
            ? 'Click a sector to fly in · scroll to zoom · drag to orbit'
            : level === 'sector'
              ? 'Click a tool-star for details · Esc or zoom out to return'
              : 'Esc to step back · scroll to zoom'}
        </p>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ *
 * HUD helpers.
 * ------------------------------------------------------------------ */

const pointerNone: CSSProperties = { pointerEvents: 'none' };

function Crumb({
  active,
  onClick,
  children,
}: {
  active?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!onClick}
      className={`rounded-full px-3 py-1 backdrop-blur transition ${
        active
          ? 'bg-white/15 text-white'
          : 'bg-black/40 text-white/60 hover:bg-white/10 hover:text-white'
      } ${onClick ? 'cursor-pointer' : 'cursor-default'} border border-white/10`}
    >
      {children}
    </button>
  );
}

function InfoCard({
  tool,
  category,
  relations,
  onClose,
}: {
  tool: AITool;
  category: ToolCategory;
  relations: AITool[];
  onClose: () => void;
}) {
  const { openInApp } = useInAppBrowser();
  return (
    <div className="flex h-full w-full items-end justify-end p-5 sm:items-center">
      <div
        className="pointer-events-auto w-full max-w-sm rounded-2xl border border-white/15 bg-black/65 p-5 text-white shadow-2xl backdrop-blur-xl"
        style={{ boxShadow: `0 0 60px ${category.glow}` }}
      >
        <div className="mb-2 flex items-center justify-between">
          <span
            className="rounded-full px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider"
            style={{ backgroundColor: `${category.color}22`, color: category.color }}
          >
            {category.name}
          </span>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full px-2 text-white/50 hover:text-white"
            aria-label="Close"
          >
            ✕
          </button>
        </div>
        <h2 className="text-xl font-semibold">{tool.name}</h2>
        <p className="mt-2 text-sm leading-relaxed text-white/70">{tool.summary}</p>

        {relations.length > 0 && (
          <div className="mt-4">
            <p className="mb-1.5 text-[11px] uppercase tracking-wider text-white/40">
              Connects to
            </p>
            <div className="flex flex-wrap gap-1.5">
              {relations.map((r) => (
                <span
                  key={r.id}
                  className="rounded-md border border-white/10 bg-white/5 px-2 py-0.5 text-xs text-white/70"
                >
                  {r.name}
                </span>
              ))}
            </div>
          </div>
        )}

        {tool.url && (
          <button
            type="button"
            onClick={() => openInApp(tool.url!, tool.name)}
            className="mt-4 inline-flex items-center gap-1 rounded-lg bg-white/10 px-3 py-1.5 text-sm font-medium text-white hover:bg-white/20"
          >
            Open ↗
          </button>
        )}
      </div>
    </div>
  );
}
