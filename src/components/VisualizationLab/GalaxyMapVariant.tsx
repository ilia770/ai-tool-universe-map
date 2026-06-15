import { Billboard, Line, Text } from '@react-three/drei';
import { Canvas, useThree } from '@react-three/fiber';
import { useEffect, useMemo } from 'react';
import type { LabData, LabNode } from './visualization-data';
import { getConnectedNodeIds } from './visualization-data';

interface GalaxyMapVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

function galaxyPosition(node: LabNode, index: number): [number, number, number] {
  const arm = index % 5;
  const radius = 1.2 + node.orbit * 1.08 + (index % 7) * 0.12;
  const theta = (node.angle * Math.PI) / 180 + arm * 0.38 + radius * 0.24;

  return [Math.cos(theta) * radius, Math.sin(theta * 1.6) * 0.22, Math.sin(theta) * radius * 0.72];
}

function CameraLookAt() {
  const camera = useThree((state) => state.camera);

  useEffect(() => {
    camera.lookAt(0, 0, 0);
    camera.updateProjectionMatrix();
  }, [camera]);

  return null;
}

export function GalaxyMapVariant({ data, selectedId, onSelect }: GalaxyMapVariantProps) {
  const connected = useMemo(() => getConnectedNodeIds(data, selectedId), [data, selectedId]);
  const positions = useMemo(
    () => new Map(data.nodes.map((node, index) => [node.id, galaxyPosition(node, index)] as const)),
    [data.nodes],
  );

  return (
    <div className="h-full min-h-[620px] bg-[#02030b]">
      <Canvas camera={{ position: [0, 7.4, 13.2], fov: 54 }} dpr={[1, 1.6]}>
        <CameraLookAt />
        <color attach="background" args={['#02030b']} />
        <ambientLight intensity={0.55} />
        <pointLight position={[0, 2, 0]} intensity={18} color="#9be8ff" />
        <mesh rotation={[-Math.PI / 2, 0, 0]}>
          <ringGeometry args={[1.2, 7.2, 96]} />
          <meshBasicMaterial color="#67e8f9" transparent opacity={0.06} />
        </mesh>
        {data.links.slice(0, 90).map((link) => {
          const source = positions.get(link.source);
          const target = positions.get(link.target);
          if (!source || !target) return null;

          const active = connected.has(link.source) && connected.has(link.target);

          return (
            <Line
              key={link.id}
              points={[source, target]}
              color={active ? '#9be8ff' : '#ffffff'}
              transparent
              opacity={active ? 0.5 : 0.08}
              lineWidth={active ? 1.2 : 0.45}
            />
          );
        })}
        {data.nodes.map((node, index) => {
          const position = positions.get(node.id) ?? galaxyPosition(node, index);
          const selected = node.id === selectedId;
          const active = connected.has(node.id);

          return (
            <group
              key={node.id}
              position={position}
              onClick={(event) => {
                event.stopPropagation();
                onSelect(node.id);
              }}
            >
              <mesh scale={selected ? 1.9 : 1}>
                <sphereGeometry args={[0.08 + node.orbit * 0.035, 16, 16]} />
                <meshBasicMaterial color={node.color} transparent opacity={selected || active ? 1 : 0.44} />
              </mesh>
              {(selected || active) && (
                <Billboard position={[0, 0.28, 0]}>
                  <Text fontSize={selected ? 0.2 : 0.13} color="white" anchorX="center" anchorY="middle" maxWidth={1.8}>
                    {node.label}
                  </Text>
                </Billboard>
              )}
            </group>
          );
        })}
      </Canvas>
    </div>
  );
}
