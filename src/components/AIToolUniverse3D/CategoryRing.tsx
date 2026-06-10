import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Html, Sparkles } from '@react-three/drei';
import type { Mesh } from 'three';
import * as THREE from 'three';
import type { ToolCategory } from '../../data/ai-tool-universe';

interface CategoryRingProps {
  category: ToolCategory;
  position: [number, number, number];
  active: boolean;
  hovered: boolean;
  pocketActive: boolean;
  labelVisible: boolean;
  reducedMotion: boolean;
  onSelect: (id: ToolCategory['id']) => void;
  onHover: (id: ToolCategory['id'] | null) => void;
}

export function CategoryRing({ category, position, active, hovered, pocketActive, labelVisible, reducedMotion, onSelect, onHover }: CategoryRingProps) {
  const haloRef = useRef<Mesh>(null);
  const cloudRef = useRef<Mesh>(null);
  const coreRef = useRef<Mesh>(null);
  const opacity = labelVisible ? (active ? 1.0 : 0.2) : 0;

  useFrame(({ camera }) => {
    // Proximity cue: as the camera approaches the ring's anchor, lift
    // the core's emissive a little so the user *sees* which pocket is
    // about to open under the auto-enter threshold from B1 (dist 11).
    const dx = camera.position.x - position[0];
    const dy = camera.position.y - position[1];
    const dz = camera.position.z - position[2];
    const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
    // 0 when far (≥18), 1 when at/under the auto-enter ring (~9).
    const proximityFactor = Math.max(0, Math.min(1, (18 - dist) / 9));

    const cloudTargetScale = pocketActive ? 1.24 : hovered ? 1.06 : active ? 0.96 : 0.86;
    const coreTargetScale = pocketActive ? 1.18 : hovered ? 1.1 : 1;
    const haloTargetOpacity = pocketActive ? 0.032 : hovered ? 0.026 : active ? 0.008 : 0.002;
    const cloudTargetOpacity = opacity * (pocketActive ? 0.065 : hovered ? 0.04 : active ? 0.018 : 0.006);
    const baseEmissive = pocketActive ? 1.22 : hovered ? 1.05 : active ? 0.72 : 0.22;
    const emissiveTarget = baseEmissive + proximityFactor * 0.55;

    if (haloRef.current) {
      const material = haloRef.current.material as THREE.MeshBasicMaterial;
      material.opacity = reducedMotion
        ? haloTargetOpacity
        : material.opacity + (haloTargetOpacity - material.opacity) * 0.055;
    }

    if (cloudRef.current) {
      if (reducedMotion) {
        cloudRef.current.scale.setScalar(cloudTargetScale);
      } else {
        cloudRef.current.scale.x += (cloudTargetScale - cloudRef.current.scale.x) * 0.06;
        cloudRef.current.scale.y += (cloudTargetScale - cloudRef.current.scale.y) * 0.06;
        cloudRef.current.scale.z += (cloudTargetScale - cloudRef.current.scale.z) * 0.06;
      }
      const material = cloudRef.current.material as THREE.MeshBasicMaterial;
      material.opacity = reducedMotion
        ? cloudTargetOpacity
        : material.opacity + (cloudTargetOpacity - material.opacity) * 0.06;
    }

    if (coreRef.current) {
      if (reducedMotion) {
        coreRef.current.scale.setScalar(coreTargetScale);
      } else {
        coreRef.current.scale.x += (coreTargetScale - coreRef.current.scale.x) * 0.06;
        coreRef.current.scale.y += (coreTargetScale - coreRef.current.scale.y) * 0.06;
        coreRef.current.scale.z += (coreTargetScale - coreRef.current.scale.z) * 0.06;
      }
      const material = coreRef.current.material as THREE.MeshStandardMaterial;
      material.emissiveIntensity = reducedMotion
        ? emissiveTarget
        : material.emissiveIntensity + (emissiveTarget - material.emissiveIntensity) * 0.055;
    }
  });

  return (
    <group
      position={position}
      onClick={() => onSelect(category.id)}
      onPointerOver={(event) => {
        event.stopPropagation();
        onHover(category.id);
      }}
      onPointerOut={(event) => {
        event.stopPropagation();
        onHover(null);
      }}
    >
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <circleGeometry args={[3.2, 64]} />
        <meshBasicMaterial
          color={category.color}
          transparent
          opacity={0}
          depthWrite={false}
          side={THREE.DoubleSide}
        />
      </mesh>
      <mesh ref={haloRef} rotation={[Math.PI / 2, 0, 0]}>
        <circleGeometry args={[2.85, 64]} />
        <meshBasicMaterial
          color={category.color}
          transparent
          opacity={0.004}
          depthWrite={false}
          side={THREE.DoubleSide}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      <Sparkles
        count={pocketActive ? 58 : hovered ? 42 : 24}
        scale={pocketActive ? [4.2, 1.24, 3.1] : [3.0, 1.0, 2.2]}
        size={pocketActive ? 2.45 : hovered ? 2.2 : 1.25}
        speed={reducedMotion ? 0 : 0.18}
        color={category.color}
      />
      <mesh ref={cloudRef} scale={[1.45, 0.22, 0.85]}>
        <sphereGeometry args={[0.9, 32, 16]} />
        <meshBasicMaterial
          color={category.color}
          transparent
          opacity={0.025}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      <mesh ref={coreRef}>
        <icosahedronGeometry args={[0.34, 2]} />
        <meshStandardMaterial
          color={category.color}
          emissive={category.color}
          emissiveIntensity={active ? 0.72 : 0.22}
          metalness={0.25}
          roughness={0.45}
        />
      </mesh>
      <Billboard>
        <Html center distanceFactor={9.4} style={{ pointerEvents: 'none' }}>
          <div
            className="universe-label universe-label-category"
            style={{
              color: active || pocketActive ? category.color : 'rgba(210,220,240,0.58)',
              borderColor: active || pocketActive ? `${category.color}66` : 'rgba(255,255,255,0.12)',
              boxShadow: active || pocketActive
                ? `0 0 18px ${category.glow}, inset 0 1px 0 rgba(255,255,255,0.14)`
                : 'inset 0 1px 0 rgba(255,255,255,0.08)',
              opacity,
            }}
          >
            {category.shortName}
          </div>
        </Html>
      </Billboard>
    </group>
  );
}
