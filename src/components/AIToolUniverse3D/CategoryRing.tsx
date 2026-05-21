import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Html } from '@react-three/drei';
import type { Mesh } from 'three';
import * as THREE from 'three';
import type { ToolCategory } from '../../data/ai-tool-universe';

interface CategoryRingProps {
  category: ToolCategory;
  position: [number, number, number];
  active: boolean;
  hovered: boolean;
  onSelect: (id: ToolCategory['id']) => void;
  onHover: (id: ToolCategory['id'] | null) => void;
}

export function CategoryRing({ category, position, active, hovered, onSelect, onHover }: CategoryRingProps) {
  const haloRef = useRef<Mesh>(null);
  const ringRef = useRef<Mesh>(null);
  const coreRef = useRef<Mesh>(null);
  const opacity = active ? 1.0 : 0.2;

  useFrame(() => {
    const ringTargetScale = hovered ? 1.09 : 1;
    const coreTargetScale = hovered ? 1.16 : 1;
    const haloTargetOpacity = hovered ? 0.08 : 0.012;
    const ringTargetOpacity = opacity * (hovered ? 0.78 : 0.5);
    const emissiveTarget = hovered ? 1.45 : active ? 1.0 : 0.3;

    if (haloRef.current) {
      const material = haloRef.current.material as THREE.MeshBasicMaterial;
      material.opacity += (haloTargetOpacity - material.opacity) * 0.12;
    }

    if (ringRef.current) {
      ringRef.current.scale.x += (ringTargetScale - ringRef.current.scale.x) * 0.1;
      ringRef.current.scale.y += (ringTargetScale - ringRef.current.scale.y) * 0.1;
      ringRef.current.scale.z += (ringTargetScale - ringRef.current.scale.z) * 0.1;
      const material = ringRef.current.material as THREE.MeshStandardMaterial;
      material.opacity += (ringTargetOpacity - material.opacity) * 0.1;
      material.emissiveIntensity += ((hovered ? 0.85 : 0.4) - material.emissiveIntensity) * 0.1;
    }

    if (coreRef.current) {
      coreRef.current.scale.x += (coreTargetScale - coreRef.current.scale.x) * 0.1;
      coreRef.current.scale.y += (coreTargetScale - coreRef.current.scale.y) * 0.1;
      coreRef.current.scale.z += (coreTargetScale - coreRef.current.scale.z) * 0.1;
      const material = coreRef.current.material as THREE.MeshStandardMaterial;
      material.emissiveIntensity += (emissiveTarget - material.emissiveIntensity) * 0.1;
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
      <mesh ref={haloRef} rotation={[Math.PI / 2, 0, 0]}>
        <circleGeometry args={[2.55, 48]} />
        <meshBasicMaterial
          color={category.color}
          transparent
          opacity={0.012}
          depthWrite={false}
        />
      </mesh>
      <mesh ref={ringRef} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[2.0, 0.014, 8, 64]} />
        <meshStandardMaterial
          color={category.color}
          emissive={category.color}
          emissiveIntensity={0.4}
          transparent
          opacity={opacity * 0.5}
        />
      </mesh>
      <mesh ref={coreRef}>
        <sphereGeometry args={[0.45, 24, 24]} />
        <meshStandardMaterial
          color={category.color}
          emissive={category.color}
          emissiveIntensity={active ? 1.0 : 0.3}
        />
      </mesh>
      <Billboard>
        <Html center distanceFactor={9.4} style={{ pointerEvents: 'none' }}>
          <div
            className="universe-label universe-label-category"
            style={{
              color: active ? category.color : 'rgba(210,220,240,0.58)',
              borderColor: active ? `${category.color}66` : 'rgba(255,255,255,0.12)',
              boxShadow: active
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
