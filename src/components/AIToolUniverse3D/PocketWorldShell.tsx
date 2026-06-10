import { type CSSProperties, useRef } from 'react';
import { Billboard, Html, Sparkles } from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import type { Group, Mesh } from 'three';
import * as THREE from 'three';
import type { ToolCategory } from '../../data/ai-tool-universe';
import { POCKET_WORLD_RADIUS } from './layout';

interface PocketWorldShellProps {
  category: ToolCategory;
  position: [number, number, number];
  toolCount: number;
  reducedMotion: boolean;
}

export function PocketWorldShell({ category, position, toolCount, reducedMotion }: PocketWorldShellProps) {
  const groupRef = useRef<Group>(null);
  const shellRef = useRef<Mesh>(null);
  const outerRingRef = useRef<Mesh>(null);
  const innerRingRef = useRef<Mesh>(null);

  useFrame((state) => {
    if (reducedMotion) {
      if (groupRef.current) {
        groupRef.current.rotation.y = 0;
      }
      if (shellRef.current) {
        const material = shellRef.current.material as THREE.MeshBasicMaterial;
        material.opacity = 0.052;
        shellRef.current.scale.set(1.18, 0.18, 0.74);
      }
      if (outerRingRef.current) {
        outerRingRef.current.rotation.z = 0;
      }
      if (innerRingRef.current) {
        innerRingRef.current.rotation.z = 0;
      }
      return;
    }

    const elapsed = state.clock.elapsedTime;

    if (groupRef.current) {
      groupRef.current.rotation.y = Math.sin(elapsed * 0.12) * 0.035;
    }

    if (shellRef.current) {
      const material = shellRef.current.material as THREE.MeshBasicMaterial;
      material.opacity += (0.052 - material.opacity) * 0.04;
      shellRef.current.scale.x = 1 + Math.sin(elapsed * 0.32) * 0.018;
      shellRef.current.scale.z = 1 + Math.cos(elapsed * 0.28) * 0.016;
    }

    if (outerRingRef.current) {
      outerRingRef.current.rotation.z = elapsed * 0.035;
    }

    if (innerRingRef.current) {
      innerRingRef.current.rotation.z = -elapsed * 0.055;
    }
  });

  return (
    <group ref={groupRef} position={position}>
      <mesh ref={shellRef} scale={[1.18, 0.18, 0.74]}>
        <sphereGeometry args={[POCKET_WORLD_RADIUS, 40, 16]} />
        <meshBasicMaterial
          color={category.color}
          transparent
          opacity={0.03}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      <mesh ref={outerRingRef} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[POCKET_WORLD_RADIUS, 0.018, 8, 104]} />
        <meshBasicMaterial
          color={category.color}
          transparent
          opacity={0.28}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      <mesh ref={innerRingRef} rotation={[Math.PI / 2.18, 0.24, 0.2]}>
        <torusGeometry args={[POCKET_WORLD_RADIUS * 0.64, 0.012, 8, 88]} />
        <meshBasicMaterial
          color="#ffffff"
          transparent
          opacity={0.12}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      <Sparkles
        count={54}
        scale={[POCKET_WORLD_RADIUS * 2.18, 2.8, POCKET_WORLD_RADIUS * 1.36]}
        size={1.65}
        speed={reducedMotion ? 0 : 0.16}
        color={category.color}
      />
      <Billboard position={[0, 3.05, 0]}>
        <Html center distanceFactor={9.2} zIndexRange={[88, 58]} style={{ pointerEvents: 'none' }}>
          <div className="universe-pocket-readout" style={{ '--pocket-color': category.color } as CSSProperties}>
            <span className="universe-pocket-readout__kicker">Pocket world</span>
            <strong>{category.shortName}</strong>
            <span>{toolCount} tools expanded</span>
          </div>
        </Html>
      </Billboard>
    </group>
  );
}
