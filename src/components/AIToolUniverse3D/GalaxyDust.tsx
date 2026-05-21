import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

const palette = ['#67e8f9', '#7fffd4', '#ff8bd2', '#ffd166', '#a78bfa'];

function createRandom(seed: number) {
  let value = seed;
  return () => {
    value = (value * 1664525 + 1013904223) % 4294967296;
    return value / 4294967296;
  };
}

export function GalaxyDust() {
  const groupRef = useRef<THREE.Group>(null);
  const { positions, colors } = useMemo(() => {
    const count = 2200;
    const random = createRandom(42);
    const nextPositions = new Float32Array(count * 3);
    const nextColors = new Float32Array(count * 3);

    for (let index = 0; index < count; index += 1) {
      const arm = index % 5;
      const radius = 1.2 + random() * 10.4;
      const theta = (arm / 5) * Math.PI * 2 + radius * 0.78 + (random() - 0.5) * 0.95;
      const spread = 0.42 + radius * 0.025;
      const x = Math.cos(theta) * radius + (random() - 0.5) * spread;
      const z = Math.sin(theta) * radius * 0.62 + (random() - 0.5) * spread;
      const y = (random() - 0.5) * 1.1 + Math.sin(theta * 1.7) * 0.16;

      nextPositions[index * 3] = x;
      nextPositions[index * 3 + 1] = y - 0.15;
      nextPositions[index * 3 + 2] = z;

      const color = new THREE.Color(palette[arm]).lerp(new THREE.Color('#f8fbff'), random() * 0.38);
      nextColors[index * 3] = color.r;
      nextColors[index * 3 + 1] = color.g;
      nextColors[index * 3 + 2] = color.b;
    }

    return { positions: nextPositions, colors: nextColors };
  }, []);

  useFrame((_, delta) => {
    if (!groupRef.current) return;
    groupRef.current.rotation.y += delta * 0.018;
  });

  return (
    <group ref={groupRef} rotation={[0.08, 0, -0.02]}>
      <points>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[positions, 3]} />
          <bufferAttribute attach="attributes-color" args={[colors, 3]} />
        </bufferGeometry>
        <pointsMaterial
          vertexColors
          size={0.035}
          sizeAttenuation
          transparent
          opacity={0.52}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </points>
    </group>
  );
}
