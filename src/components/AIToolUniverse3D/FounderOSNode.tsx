import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Sparkles, Billboard, Html } from '@react-three/drei';
import type { Mesh } from 'three';
import * as THREE from 'three';

interface FounderOSNodeProps {
  selected: boolean;
  onSelect: () => void;
  reducedMotion: boolean;
}

export function FounderOSNode({ selected, onSelect, reducedMotion }: FounderOSNodeProps) {
  const meshRef = useRef<Mesh>(null);

  useFrame((_, delta) => {
    if (!meshRef.current) return;
    if (!reducedMotion) {
      meshRef.current.rotation.y += delta * 0.3;
    }
    const target = selected ? 2.0 : 0.8;
    const mat = meshRef.current.material as THREE.MeshStandardMaterial;
    mat.emissiveIntensity = reducedMotion
      ? target
      : mat.emissiveIntensity + (target - mat.emissiveIntensity) * 0.05;
  });

  return (
    <group onClick={onSelect}>
      <Sparkles count={40} scale={3} size={2} speed={reducedMotion ? 0 : 0.4} color="#67e8f9" />
      <mesh ref={meshRef}>
        <sphereGeometry args={[0.8, 32, 32]} />
        <meshStandardMaterial
          color="#ffffff"
          emissive="#67e8f9"
          emissiveIntensity={0.8}
          metalness={0.6}
          roughness={0.2}
        />
      </mesh>
      <Billboard>
        <Html center distanceFactor={7.5} style={{ pointerEvents: 'none' }}>
          <div
            className="universe-label universe-label-founder"
            style={{
              boxShadow: selected
                ? '0 0 26px rgba(103,232,249,0.42), inset 0 1px 0 rgba(255,255,255,0.18)'
                : '0 0 14px rgba(103,232,249,0.22), inset 0 1px 0 rgba(255,255,255,0.12)',
            }}
          >
            Founder OS
          </div>
        </Html>
      </Billboard>
    </group>
  );
}
