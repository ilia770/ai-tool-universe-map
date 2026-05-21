import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface StarLayerProps {
  count: number;
  radius: number;
  depth: number;
  size: number;
  opacity: number;
  seed: number;
  drift: number;
}

function createRandom(seed: number) {
  let value = seed;
  return () => {
    value = (value * 16807) % 2147483647;
    return (value - 1) / 2147483646;
  };
}

function createStarTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 64;
  canvas.height = 64;
  const context = canvas.getContext('2d');

  if (!context) return null;

  const gradient = context.createRadialGradient(32, 32, 0, 32, 32, 31);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(0.24, 'rgba(255,255,255,0.9)');
  gradient.addColorStop(0.56, 'rgba(170,230,255,0.34)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 64, 64);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function StarLayer({ count, radius, depth, size, opacity, seed, drift }: StarLayerProps) {
  const pointsRef = useRef<THREE.Points>(null);
  const starTexture = useMemo(() => createStarTexture(), []);
  const { positions, colors } = useMemo(() => {
    const random = createRandom(seed);
    const nextPositions = new Float32Array(count * 3);
    const nextColors = new Float32Array(count * 3);
    const blue = new THREE.Color('#b7f4ff');
    const white = new THREE.Color('#fffaf0');
    const gold = new THREE.Color('#ffe6a8');

    for (let index = 0; index < count; index += 1) {
      const theta = random() * Math.PI * 2;
      const phi = Math.acos(2 * random() - 1);
      const shell = radius - random() * depth;
      const x = Math.sin(phi) * Math.cos(theta) * shell;
      const y = Math.cos(phi) * shell * 0.62;
      const z = Math.sin(phi) * Math.sin(theta) * shell;

      nextPositions[index * 3] = x;
      nextPositions[index * 3 + 1] = y;
      nextPositions[index * 3 + 2] = z;

      const color = random() > 0.82 ? gold.clone() : random() > 0.52 ? blue.clone() : white.clone();
      color.lerp(new THREE.Color('#ffffff'), random() * 0.35);
      nextColors[index * 3] = color.r;
      nextColors[index * 3 + 1] = color.g;
      nextColors[index * 3 + 2] = color.b;
    }

    return { positions: nextPositions, colors: nextColors };
  }, [count, depth, radius, seed]);

  useFrame((_, delta) => {
    if (!pointsRef.current) return;
    pointsRef.current.rotation.y += delta * drift;
    pointsRef.current.rotation.x += delta * drift * 0.18;
  });

  return (
    <points ref={pointsRef}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
        <bufferAttribute attach="attributes-color" args={[colors, 3]} />
      </bufferGeometry>
      <pointsMaterial
        map={starTexture ?? undefined}
        vertexColors
        size={size}
        sizeAttenuation
        transparent
        opacity={opacity}
        alphaTest={0.02}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  );
}

export function StarField() {
  return (
    <group>
      <StarLayer count={1800} radius={42} depth={18} size={0.18} opacity={0.92} seed={11} drift={0.012} />
      <StarLayer count={4200} radius={96} depth={46} size={0.13} opacity={0.66} seed={29} drift={0.004} />
      <StarLayer count={900} radius={28} depth={10} size={0.24} opacity={0.54} seed={47} drift={-0.008} />
    </group>
  );
}
