import { Billboard, Text } from '@react-three/drei';
import { Canvas, useThree } from '@react-three/fiber';
import { useEffect } from 'react';
import type { LabData, LabNode } from './visualization-data';

interface VisionSpaceVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

function objectPosition(index: number, total: number): [number, number, number] {
  const angle = (index / Math.max(total, 1)) * Math.PI * 2;
  const radius = 3.1 + (index % 3) * 0.72;

  return [Math.cos(angle) * radius, Math.sin(index * 1.7) * 0.62, Math.sin(angle) * radius];
}

function CameraLookAt() {
  const camera = useThree((state) => state.camera);

  useEffect(() => {
    camera.lookAt(0, 0, 0);
    camera.updateProjectionMatrix();
  }, [camera]);

  return null;
}

function FloatingObject({
  node,
  index,
  total,
  selected,
  onSelect,
}: {
  node: LabNode;
  index: number;
  total: number;
  selected: boolean;
  onSelect: (id: string) => void;
}) {
  const position = objectPosition(index, total);
  const scale = selected ? 1.45 : 0.86 + node.orbit * 0.12;

  return (
    <group
      position={position}
      scale={scale}
      onClick={(event) => {
        event.stopPropagation();
        onSelect(node.id);
      }}
    >
      <mesh>
        <sphereGeometry args={[0.42, 32, 32]} />
        <meshStandardMaterial
          color={node.color}
          emissive={node.color}
          emissiveIntensity={selected ? 1.2 : 0.38}
          roughness={0.42}
          metalness={0.12}
        />
      </mesh>
      <Billboard position={[0, -0.78, 0]}>
        <Text fontSize={0.18} color="white" anchorX="center" anchorY="middle" maxWidth={2}>
          {node.label}
        </Text>
      </Billboard>
    </group>
  );
}

export function VisionSpaceVariant({ data, selectedId, onSelect }: VisionSpaceVariantProps) {
  const visibleNodes = data.nodes.slice(0, 18);

  return (
    <div className="h-full min-h-[620px] bg-black">
      <Canvas camera={{ position: [0, 4.2, 13.5], fov: 52 }} dpr={[1, 1.6]}>
        <CameraLookAt />
        <color attach="background" args={['#020207']} />
        <ambientLight intensity={0.32} />
        <directionalLight position={[4, 6, 5]} intensity={2.4} />
        <pointLight position={[-4, -2, 3]} intensity={8} color="#67e8f9" />
        {visibleNodes.map((node, index) => (
          <FloatingObject
            key={node.id}
            node={node}
            index={index}
            total={visibleNodes.length}
            selected={node.id === selectedId}
            onSelect={onSelect}
          />
        ))}
      </Canvas>
    </div>
  );
}
