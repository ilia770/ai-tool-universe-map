import { useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, type ThreeEvent } from '@react-three/fiber';
import {
  CameraControls,
  CameraControlsImpl,
  Environment,
  Float,
  Html,
  Lightformer,
  MeshTransmissionMaterial,
  Text,
} from '@react-three/drei';
import * as THREE from 'three';
import {
  categories,
  tools,
  type ToolCategory,
} from '../../data/ai-tool-universe';

const { ACTION } = CameraControlsImpl;

const SPACE_BG = '#030306';

/** Radius of the ring the 8 category worlds float on. */
const WORLD_RING_RADIUS = 9.5;
/** Radius of each large category world. */
const WORLD_RADIUS = 1.65;
/** Radius of the small satellite tool orbs. */
const SATELLITE_RADIUS = 0.42;
/** Radius of the orbit satellites sit on, around their parent world. */
const SATELLITE_ORBIT = 3.6;

/** Pre-computed overview positions for the 8 category worlds. */
interface WorldPlacement {
  category: ToolCategory;
  position: THREE.Vector3;
  color: THREE.Color;
  toolCount: number;
}

function useWorldPlacements(): WorldPlacement[] {
  return useMemo(() => {
    const count = categories.length;
    return categories.map((category, i) => {
      // Even ring distribution, faint vertical wave for a more organic, calm spread.
      const t = (i / count) * Math.PI * 2;
      const x = Math.cos(t) * WORLD_RING_RADIUS;
      const z = Math.sin(t) * WORLD_RING_RADIUS;
      const y = Math.sin(t * 2) * 1.1;
      const toolCount = tools.filter((tool) => tool.category === category.id).length;
      return {
        category,
        position: new THREE.Vector3(x, y, z),
        color: new THREE.Color(category.color),
        toolCount,
      };
    });
  }, []);
}

/** Satellite local offsets around a parent world (shared per category render). */
function satelliteOffsets(n: number): THREE.Vector3[] {
  const offsets: THREE.Vector3[] = [];
  const golden = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < n; i++) {
    // Fibonacci sphere for an even, premium scatter, slightly flattened.
    const y = 1 - (i / Math.max(1, n - 1)) * 2;
    const r = Math.sqrt(Math.max(0, 1 - y * y));
    const theta = golden * i;
    offsets.push(
      new THREE.Vector3(
        Math.cos(theta) * r * SATELLITE_ORBIT,
        y * SATELLITE_ORBIT * 0.55,
        Math.sin(theta) * r * SATELLITE_ORBIT,
      ),
    );
  }
  return offsets;
}

interface GlassWorldProps {
  placement: WorldPlacement;
  dimmed: boolean;
  onSelect: (id: string) => void;
}

/** A large frosted-glass category "world" with its label. */
function GlassWorld({ placement, dimmed, onSelect }: GlassWorldProps) {
  const { category, position, color, toolCount } = placement;
  const [hovered, setHovered] = useState(false);

  useEffect(() => {
    document.body.style.cursor = hovered ? 'pointer' : 'auto';
    return () => {
      document.body.style.cursor = 'auto';
    };
  }, [hovered]);

  return (
    <Float
      speed={1.1}
      rotationIntensity={0.25}
      floatIntensity={0.7}
      floatingRange={[-0.18, 0.18]}
      position={position}
    >
      <group
        onClick={(e: ThreeEvent<MouseEvent>) => {
          e.stopPropagation();
          onSelect(category.id);
        }}
        onPointerOver={(e: ThreeEvent<PointerEvent>) => {
          e.stopPropagation();
          setHovered(true);
        }}
        onPointerOut={() => setHovered(false)}
      >
        {/* Soft tinted glow halo */}
        <mesh scale={hovered ? 1.32 : 1.22}>
          <sphereGeometry args={[WORLD_RADIUS, 24, 24]} />
          <meshBasicMaterial
            color={color}
            transparent
            opacity={dimmed ? 0.03 : hovered ? 0.14 : 0.08}
            blending={THREE.AdditiveBlending}
            depthWrite={false}
          />
        </mesh>

        {/* Frosted glass body */}
        <mesh castShadow>
          <sphereGeometry args={[WORLD_RADIUS, 64, 64]} />
          <MeshTransmissionMaterial
            transmission={1}
            thickness={1.4}
            roughness={0.18}
            ior={1.32}
            chromaticAberration={0.04}
            anisotropy={0.2}
            distortion={0.12}
            distortionScale={0.25}
            temporalDistortion={0.05}
            color={color}
            attenuationColor={color}
            attenuationDistance={2.4}
            transparent
            opacity={dimmed ? 0.35 : 1}
          />
        </mesh>

        {/* Inner core bloom — gives the glass a lit-from-within feel */}
        <mesh scale={0.42}>
          <sphereGeometry args={[WORLD_RADIUS, 24, 24]} />
          <meshBasicMaterial color={color} transparent opacity={dimmed ? 0.1 : 0.45} />
        </mesh>

        <Text
          position={[0, -WORLD_RADIUS - 0.95, 0]}
          fontSize={0.52}
          color="#f4f7ff"
          anchorX="center"
          anchorY="middle"
          maxWidth={5}
          textAlign="center"
          outlineWidth={0.004}
          outlineColor="#000000"
          fillOpacity={dimmed ? 0.25 : 1}
        >
          {category.shortName}
        </Text>
        <Text
          position={[0, -WORLD_RADIUS - 1.55, 0]}
          fontSize={0.26}
          color={category.color}
          anchorX="center"
          anchorY="middle"
          fillOpacity={dimmed ? 0.2 : 0.85}
        >
          {`${toolCount} tools`}
        </Text>
      </group>
    </Float>
  );
}

interface SatelliteProps {
  name: string;
  url?: string;
  offset: THREE.Vector3;
  color: THREE.Color;
  geometry: THREE.SphereGeometry;
}

/** A small glass tool orb orbiting an opened category world. */
function Satellite({ name, url, offset, color, geometry }: SatelliteProps) {
  const [hovered, setHovered] = useState(false);

  useEffect(() => {
    if (!hovered) return;
    document.body.style.cursor = 'pointer';
    return () => {
      document.body.style.cursor = 'auto';
    };
  }, [hovered]);

  return (
    <Float speed={2} rotationIntensity={0.4} floatIntensity={0.5} position={offset}>
      <group
        onPointerOver={(e: ThreeEvent<PointerEvent>) => {
          e.stopPropagation();
          setHovered(true);
        }}
        onPointerOut={() => setHovered(false)}
        onClick={(e: ThreeEvent<MouseEvent>) => {
          e.stopPropagation();
          if (url) window.open(url, '_blank', 'noopener,noreferrer');
        }}
      >
        <mesh geometry={geometry} scale={hovered ? 1.18 : 1}>
          <MeshTransmissionMaterial
            transmission={1}
            thickness={0.6}
            roughness={0.12}
            ior={1.3}
            chromaticAberration={0.05}
            color={color}
            attenuationColor={color}
            attenuationDistance={1.2}
          />
        </mesh>
        <mesh scale={(hovered ? 1.18 : 1) * 1.35}>
          <sphereGeometry args={[SATELLITE_RADIUS, 16, 16]} />
          <meshBasicMaterial
            color={color}
            transparent
            opacity={hovered ? 0.16 : 0.07}
            blending={THREE.AdditiveBlending}
            depthWrite={false}
          />
        </mesh>
        <Text
          position={[0, -SATELLITE_RADIUS - 0.32, 0]}
          fontSize={0.18}
          color="#eef2ff"
          anchorX="center"
          anchorY="middle"
          maxWidth={2.4}
          textAlign="center"
          outlineWidth={0.003}
          outlineColor="#000000"
        >
          {name}
        </Text>
      </group>
    </Float>
  );
}

interface CategoryDetailProps {
  placement: WorldPlacement;
}

/** The opened category: parent world + its tools as orbiting satellites. */
function CategoryDetail({ placement }: CategoryDetailProps) {
  const { category, position, color } = placement;

  const categoryTools = useMemo(
    () => tools.filter((tool) => tool.category === category.id),
    [category.id],
  );
  const offsets = useMemo(() => satelliteOffsets(categoryTools.length), [categoryTools.length]);

  // One shared geometry instance for every satellite in this category.
  const satGeometry = useMemo(() => new THREE.SphereGeometry(SATELLITE_RADIUS, 32, 32), []);
  useEffect(() => () => satGeometry.dispose(), [satGeometry]);

  const groupRef = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (groupRef.current) groupRef.current.rotation.y += delta * 0.06;
  });

  return (
    <group position={position}>
      {/* The parent world, now centred and steady */}
      <Float speed={0.8} rotationIntensity={0.15} floatIntensity={0.4}>
        <mesh scale={1.18}>
          <sphereGeometry args={[WORLD_RADIUS, 24, 24]} />
          <meshBasicMaterial
            color={color}
            transparent
            opacity={0.12}
            blending={THREE.AdditiveBlending}
            depthWrite={false}
          />
        </mesh>
        <mesh>
          <sphereGeometry args={[WORLD_RADIUS, 64, 64]} />
          <MeshTransmissionMaterial
            transmission={1}
            thickness={1.4}
            roughness={0.16}
            ior={1.32}
            chromaticAberration={0.04}
            distortion={0.1}
            distortionScale={0.2}
            color={color}
            attenuationColor={color}
            attenuationDistance={2.4}
          />
        </mesh>
        <mesh scale={0.42}>
          <sphereGeometry args={[WORLD_RADIUS, 24, 24]} />
          <meshBasicMaterial color={color} transparent opacity={0.5} />
        </mesh>
        <Text
          position={[0, WORLD_RADIUS + 0.7, 0]}
          fontSize={0.46}
          color="#f4f7ff"
          anchorX="center"
          anchorY="middle"
          maxWidth={6}
          textAlign="center"
          outlineWidth={0.004}
          outlineColor="#000000"
        >
          {category.name}
        </Text>
      </Float>

      {/* Slowly rotating constellation of tool satellites */}
      <group ref={groupRef}>
        {categoryTools.map((tool, i) => (
          <Satellite
            key={tool.id}
            name={tool.name}
            url={tool.url}
            offset={offsets[i]}
            color={color}
            geometry={satGeometry}
          />
        ))}
      </group>
    </group>
  );
}

interface RigProps {
  selectedId: string | null;
  placements: WorldPlacement[];
  reducedMotion: boolean;
}

/** Drives programmatic camera moves on selection / deselection. */
function Rig({ selectedId, placements, reducedMotion }: RigProps) {
  const controlsRef = useRef<CameraControlsImpl>(null);

  useEffect(() => {
    const controls = controlsRef.current;
    if (!controls) return;
    const smooth = !reducedMotion;

    if (selectedId) {
      const placement = placements.find((p) => p.category.id === selectedId);
      if (!placement) return;
      const { x, y, z } = placement.position;
      // Pull in close to the chosen world, slightly above and pushed outward
      // along its own radius so the satellites read clearly.
      const dir = new THREE.Vector3(x, 0, z).normalize();
      const camX = x + dir.x * 6.5;
      const camZ = z + dir.z * 6.5;
      void controls.setLookAt(camX, y + 2.6, camZ, x, y, z, smooth);
    } else {
      // Calm, centred overview of all eight worlds.
      void controls.setLookAt(0, 3.5, 22, 0, 0, 0, smooth);
    }
  }, [selectedId, placements, reducedMotion]);

  return (
    <CameraControls
      ref={controlsRef}
      makeDefault
      minDistance={5}
      maxDistance={34}
      smoothTime={reducedMotion ? 0.05 : 0.9}
      draggingSmoothTime={reducedMotion ? 0.03 : 0.14}
      mouseButtons={{
        left: ACTION.ROTATE,
        middle: ACTION.DOLLY,
        right: ACTION.TRUCK,
        wheel: ACTION.DOLLY,
      }}
      touches={{
        one: ACTION.TOUCH_ROTATE,
        two: ACTION.TOUCH_DOLLY_TRUCK,
        three: ACTION.TOUCH_DOLLY_TRUCK,
      }}
    />
  );
}

/** Soft IBL built from lightformers — no network HDR fetch. */
function SoftStudio() {
  return (
    <Environment resolution={256}>
      <Lightformer
        intensity={2.2}
        color="#aab8ff"
        position={[0, 6, 4]}
        scale={[10, 10, 1]}
        form="circle"
      />
      <Lightformer
        intensity={1.2}
        color="#ff9ad6"
        position={[-8, 2, -6]}
        scale={[6, 6, 1]}
        form="circle"
      />
      <Lightformer
        intensity={1.0}
        color="#7fffd4"
        position={[8, -2, -6]}
        scale={[6, 6, 1]}
        form="circle"
      />
      <Lightformer
        intensity={0.6}
        color="#ffffff"
        position={[0, -8, 2]}
        scale={[10, 10, 1]}
        form="circle"
      />
    </Environment>
  );
}

export function ObjectSpace() {
  const placements = useWorldPlacements();
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const reducedMotion = useMemo(
    () =>
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches,
    [],
  );

  // Escape returns to the overview.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setSelectedId(null);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const selectedPlacement = selectedId
    ? placements.find((p) => p.category.id === selectedId)
    : null;

  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: [0, 3.5, 22], fov: 42 }}
      gl={{ antialias: true, alpha: false }}
      style={{ width: '100%', height: '100%', background: SPACE_BG }}
      onPointerMissed={() => setSelectedId(null)}
    >
      <color attach="background" args={[SPACE_BG]} />
      <fog attach="fog" args={[SPACE_BG, 24, 60]} />

      <ambientLight intensity={0.18} />
      {/* Single soft central bloom light */}
      <pointLight position={[0, 4, 6]} intensity={40} distance={70} color="#cdd7ff" />

      <SoftStudio />

      {/* Overview: only the 8 worlds. Dim them when one is opened. */}
      {placements.map((placement) => (
        <GlassWorld
          key={placement.category.id}
          placement={placement}
          dimmed={selectedId !== null && selectedId !== placement.category.id}
          onSelect={setSelectedId}
        />
      ))}

      {/* Drill-in: one category's tools at a time. */}
      {selectedPlacement && <CategoryDetail placement={selectedPlacement} />}

      <Rig selectedId={selectedId} placements={placements} reducedMotion={reducedMotion} />

      {selectedPlacement && (
        <Html fullscreen style={{ pointerEvents: 'none' }}>
          <button
            type="button"
            onClick={() => setSelectedId(null)}
            style={{
              position: 'absolute',
              top: 24,
              left: 24,
              pointerEvents: 'auto',
              padding: '10px 18px',
              borderRadius: 999,
              border: '1px solid rgba(255,255,255,0.18)',
              background: 'rgba(255,255,255,0.06)',
              backdropFilter: 'blur(14px)',
              WebkitBackdropFilter: 'blur(14px)',
              color: '#f4f7ff',
              fontSize: 14,
              fontWeight: 500,
              letterSpacing: '0.02em',
              cursor: 'pointer',
              fontFamily:
                '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif',
            }}
          >
            ← All worlds
          </button>
          <div
            style={{
              position: 'absolute',
              bottom: 28,
              left: '50%',
              transform: 'translateX(-50%)',
              maxWidth: 520,
              textAlign: 'center',
              color: 'rgba(244,247,255,0.62)',
              fontSize: 13,
              lineHeight: 1.5,
              fontFamily:
                '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif',
            }}
          >
            {selectedPlacement.category.description}
          </div>
        </Html>
      )}
    </Canvas>
  );
}
