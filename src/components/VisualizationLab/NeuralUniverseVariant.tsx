import { Billboard, Line, Text } from '@react-three/drei';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { useEffect, useMemo, useRef, type ReactNode } from 'react';
import type { Group } from 'three';
import type { LabCluster, LabData, LabNode } from './visualization-data';
import { getConnectedNodeIds } from './visualization-data';

interface NeuralUniverseVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

function peripheralPosition(index: number, total: number): [number, number, number] {
  const angle = (index / Math.max(total, 1)) * Math.PI * 2 - Math.PI / 2;
  const radius = 3.75;

  return [Math.cos(angle) * radius, Math.sin(index * 1.34) * 0.54, Math.sin(angle) * radius * 0.64];
}

function neuronPosition(node: LabNode, index: number, total: number): [number, number, number] {
  const angle = (index / Math.max(total, 1)) * Math.PI * 2 + (node.angle * Math.PI) / 360;
  const radius = 1.24 + (index % 4) * 0.38 + node.orbit * 0.08;

  return [Math.cos(angle) * radius, Math.sin(index * 1.21) * 0.42, Math.sin(angle) * radius * 0.62];
}

function CameraLookAt() {
  const camera = useThree((state) => state.camera);

  useEffect(() => {
    camera.lookAt(0, 0, 0);
    camera.updateProjectionMatrix();
  }, [camera]);

  return null;
}

function LivingField({ children }: { children: ReactNode }) {
  const groupRef = useRef<Group>(null);

  useFrame((state) => {
    if (!groupRef.current) return;

    const elapsed = state.clock.elapsedTime;
    groupRef.current.rotation.y = Math.sin(elapsed * 0.18) * 0.045;
    groupRef.current.rotation.x = Math.sin(elapsed * 0.11) * 0.018;
  });

  return <group ref={groupRef}>{children}</group>;
}

function CategoryCore({
  cluster,
  position,
  active,
  onSelect,
}: {
  cluster: LabCluster;
  position: [number, number, number];
  active: boolean;
  onSelect: (id: string) => void;
}) {
  const firstNodeId = cluster.nodeIds[0];

  return (
    <group
      position={position}
      onClick={(event) => {
        event.stopPropagation();
        if (firstNodeId) onSelect(firstNodeId);
      }}
    >
      <mesh scale={active ? 1.16 : 1}>
        <sphereGeometry args={[active ? 0.62 : 0.34, 32, 32]} />
        <meshStandardMaterial
          color={cluster.color}
          emissive={cluster.color}
          emissiveIntensity={active ? 1.1 : 0.42}
          transparent
          opacity={active ? 0.92 : 0.58}
          roughness={0.36}
          metalness={0.16}
        />
      </mesh>
      <mesh scale={active ? 1.7 : 1.28}>
        <sphereGeometry args={[0.68, 32, 32]} />
        <meshBasicMaterial color={cluster.color} transparent opacity={active ? 0.12 : 0.055} />
      </mesh>
      <Billboard position={[0, active ? -0.98 : -0.64, 0]}>
        <Text fontSize={active ? 0.18 : 0.12} color="white" anchorX="center" anchorY="middle" maxWidth={1.9}>
          {cluster.label}
        </Text>
      </Billboard>
    </group>
  );
}

function ToolNeuron({
  node,
  position,
  selected,
  connected,
  onSelect,
}: {
  node: LabNode;
  position: [number, number, number];
  selected: boolean;
  connected: boolean;
  onSelect: (id: string) => void;
}) {
  return (
    <group
      position={position}
      onClick={(event) => {
        event.stopPropagation();
        onSelect(node.id);
      }}
    >
      <mesh scale={selected ? 1.55 : 1}>
        <sphereGeometry args={[0.105 + node.orbit * 0.025, 20, 20]} />
        <meshStandardMaterial
          color={node.color}
          emissive={node.color}
          emissiveIntensity={selected ? 1.3 : connected ? 0.82 : 0.32}
          transparent
          opacity={selected || connected ? 1 : 0.54}
          roughness={0.32}
          metalness={0.08}
        />
      </mesh>
      {(selected || connected) && (
        <Billboard position={[0, selected ? 0.34 : 0.26, 0]}>
          <Text fontSize={selected ? 0.17 : 0.115} color="white" anchorX="center" anchorY="middle" maxWidth={1.55}>
            {node.label}
          </Text>
        </Billboard>
      )}
    </group>
  );
}

export function NeuralUniverseVariant({ data, selectedId, onSelect }: NeuralUniverseVariantProps) {
  const selected = data.nodeById.get(selectedId) ?? data.nodes[0];

  const connected = useMemo(() => getConnectedNodeIds(data, selectedId), [data, selectedId]);
  const activeCluster = selected ? data.clusterById.get(selected.category) : undefined;
  const activeNodeIds = useMemo(() => {
    const ids = new Set(activeCluster?.nodeIds ?? []);
    connected.forEach((id) => ids.add(id));

    return ids;
  }, [activeCluster, connected]);

  const visibleNodes = useMemo(() => data.nodes.filter((node) => activeNodeIds.has(node.id)).slice(0, 28), [activeNodeIds, data.nodes]);
  const hubPositions = useMemo(() => {
    const map = new Map<string, [number, number, number]>();

    data.clusters.forEach((cluster, index) => {
      map.set(cluster.id, selected && cluster.id === selected.category ? [0, 0.28, 0] : peripheralPosition(index, data.clusters.length));
    });

    return map;
  }, [data.clusters, selected]);

  const neuronPositions = useMemo(() => {
    const map = new Map<string, [number, number, number]>();

    visibleNodes.forEach((node, index) => {
      map.set(node.id, neuronPosition(node, index, visibleNodes.length));
    });

    return map;
  }, [visibleNodes]);

  if (!selected || !activeCluster) {
    return <div className="h-full min-h-[620px] bg-[#020207]" />;
  }

  return (
    <div className="h-full min-h-[620px] bg-[#020207]">
      <Canvas camera={{ position: [0, 4.8, 11.8], fov: 52 }} dpr={[1, 1.6]}>
        <CameraLookAt />
        <color attach="background" args={['#020207']} />
        <ambientLight intensity={0.38} />
        <pointLight position={[0, 2.4, 4.6]} intensity={12} color="#b8f7ff" />
        <pointLight position={[-4, -1.6, 2]} intensity={5} color="#a78bfa" />
        <LivingField>
          {data.clusters.map((cluster) => {
            const position = hubPositions.get(cluster.id) ?? [0, 0, 0];
            const active = cluster.id === selected.category;

            return (
              <CategoryCore
                key={cluster.id}
                cluster={cluster}
                position={position}
                active={active}
                onSelect={onSelect}
              />
            );
          })}

          {data.clusters
            .filter((cluster) => cluster.id !== selected.category)
            .map((cluster) => {
              const target = hubPositions.get(cluster.id);
              if (!target) return null;

              return (
                <Line
                  key={`core-${cluster.id}`}
                  points={[[0, 0.28, 0], target]}
                  color={cluster.color}
                  transparent
                  opacity={0.075}
                  lineWidth={0.55}
                />
              );
            })}

          {visibleNodes.map((node, index) => {
            const position = neuronPositions.get(node.id) ?? neuronPosition(node, index, visibleNodes.length);
            const isSelected = node.id === selected.id;
            const isConnected = connected.has(node.id);

            return (
              <Line
                key={`axon-${node.id}`}
                points={[[0, 0.28, 0], position]}
                color={node.color}
                transparent
                opacity={isSelected ? 0.45 : isConnected ? 0.24 : 0.105}
                lineWidth={isSelected ? 1.4 : 0.7}
              />
            );
          })}

          {data.links.slice(0, 90).map((link) => {
            const source = neuronPositions.get(link.source);
            const target = neuronPositions.get(link.target);
            if (!source || !target) return null;

            const active = link.source === selected.id || link.target === selected.id;

            return (
              <Line
                key={`synapse-${link.id}`}
                points={[source, target]}
                color={active ? '#ffffff' : '#8fdfff'}
                transparent
                opacity={active ? 0.36 : 0.12}
                lineWidth={active ? 1.1 : 0.48}
              />
            );
          })}

          {visibleNodes.map((node, index) => {
            const position = neuronPositions.get(node.id) ?? neuronPosition(node, index, visibleNodes.length);

            return (
              <ToolNeuron
                key={node.id}
                node={node}
                position={position}
                selected={node.id === selected.id}
                connected={connected.has(node.id)}
                onSelect={onSelect}
              />
            );
          })}
        </LivingField>
      </Canvas>
    </div>
  );
}
