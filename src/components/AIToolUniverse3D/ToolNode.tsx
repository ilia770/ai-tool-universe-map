import { useRef, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Html } from '@react-three/drei';
import type { Mesh } from 'three';
import * as THREE from 'three';
import type { ToolCategoryId } from '../../data/ai-tool-universe';

interface ToolNodeProps {
  id: string;
  name: string;
  category: ToolCategoryId;
  position: [number, number, number];
  color: string;
  glow: string;
  selected: boolean;
  relationDepth?: number;
  labelVisible: boolean;
  dimmed: boolean;
  onSelect: (id: string) => void;
  onCategoryHover: (category: ToolCategoryId | null) => void;
}

export function ToolNode({
  id,
  name,
  category,
  position,
  color,
  glow,
  selected,
  relationDepth,
  labelVisible,
  dimmed,
  onSelect,
  onCategoryHover,
}: ToolNodeProps) {
  const meshRef = useRef<Mesh>(null);
  const [hovered, setHovered] = useState(false);

  useFrame(() => {
    if (!meshRef.current) return;
    const targetScale = selected ? 1.48 : relationDepth === 1 ? 1.22 : relationDepth === 2 ? 1.06 : 0.92;
    const currentScale = meshRef.current.scale.x;
    const next = currentScale + (targetScale - currentScale) * 0.1;
    meshRef.current.scale.setScalar(next);
    const mat = meshRef.current.material as THREE.MeshStandardMaterial;
    const targetEmissive = selected ? 2.25 : relationDepth === 1 ? 1.35 : relationDepth === 2 ? 0.78 : 0.42;
    mat.emissiveIntensity += (targetEmissive - mat.emissiveIntensity) * 0.08;
    mat.opacity += ((dimmed ? 0.18 : relationDepth === 2 ? 0.64 : 1.0) - mat.opacity) * 0.1;
  });

  const showLabel = selected || hovered || labelVisible;

  return (
    <group
      position={position}
      onClick={() => onSelect(id)}
      onPointerOver={(event) => {
        event.stopPropagation();
        setHovered(true);
        onCategoryHover(category);
      }}
      onPointerOut={(event) => {
        event.stopPropagation();
        setHovered(false);
        onCategoryHover(null);
      }}
    >
      <mesh ref={meshRef}>
        <sphereGeometry args={[0.3, 20, 20]} />
        <meshStandardMaterial
          color={color}
          emissive={color}
          emissiveIntensity={0.6}
          transparent
          opacity={dimmed ? 0.18 : relationDepth === 2 ? 0.64 : 1.0}
        />
      </mesh>
      <Billboard>
        <Html
          center
          distanceFactor={7.4}
          zIndexRange={showLabel ? [60, 20] : [0, 0]}
          style={{ pointerEvents: showLabel ? 'auto' : 'none' }}
        >
          <div
            aria-hidden={!showLabel}
            className={`universe-label universe-label-tool ${showLabel ? 'is-visible' : ''}`}
            onClick={() => onSelect(id)}
            style={{
              borderColor: `${color}66`,
              boxShadow: `0 0 18px ${glow}, inset 0 1px 0 rgba(255,255,255,0.16)`,
              opacity: showLabel ? (dimmed ? 0.7 : 1) : 0,
            }}
          >
            {name.length > 18 ? `${name.slice(0, 17)}...` : name}
          </div>
        </Html>
      </Billboard>
    </group>
  );
}
