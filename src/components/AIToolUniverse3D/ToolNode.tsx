import { type CSSProperties, useEffect, useRef, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Html } from '@react-three/drei';
import type { Group, Mesh } from 'three';
import * as THREE from 'three';
import type { AITool, ToolCategoryId } from '../../data/ai-tool-universe';
import { ToolLogo } from '../ToolLogo';

// Shared geometries: one BufferGeometry per role, reused across every
// ToolNode instance instead of allocating ~3 × N spheres on mount.
const HIT_GEOM = new THREE.SphereGeometry(0.68, 18, 18);
const AURA_GEOM = new THREE.SphereGeometry(0.46, 24, 24);
const CORE_GEOM = new THREE.SphereGeometry(0.3, 20, 20);

interface ToolNodeProps {
  id: string;
  name: string;
  tool: AITool;
  category: ToolCategoryId;
  position: [number, number, number];
  color: string;
  glow: string;
  selected: boolean;
  relationDepth?: number;
  labelVisible: boolean;
  dimmed: boolean;
  pocketed: boolean;
  onSelect: (id: string) => void;
  onToolHover: (id: string | null, category: ToolCategoryId | null) => void;
}

export function ToolNode({
  id,
  name,
  tool,
  category,
  position,
  color,
  glow,
  selected,
  relationDepth,
  labelVisible,
  dimmed,
  pocketed,
  onSelect,
  onToolHover,
}: ToolNodeProps) {
  const groupRef = useRef<Group>(null);
  const meshRef = useRef<Mesh>(null);
  const auraRef = useRef<Mesh>(null);
  const targetPositionRef = useRef(new THREE.Vector3(...position));
  const [initialPosition] = useState<[number, number, number]>(() => [...position]);
  const [hovered, setHovered] = useState(false);

  useEffect(() => {
    targetPositionRef.current.set(position[0], position[1], position[2]);
  }, [position]);

  useFrame(() => {
    if (groupRef.current) {
      const positionEase = pocketed || selected ? 0.07 : 0.052;
      groupRef.current.position.lerp(targetPositionRef.current, positionEase);
    }

    if (!meshRef.current) return;
    const targetScale = selected ? 1.34 : hovered ? 1.18 : relationDepth === 1 ? 1.12 : relationDepth === 2 ? 1.03 : 0.9;
    const currentScale = meshRef.current.scale.x;
    const next = currentScale + (targetScale - currentScale) * 0.055;
    meshRef.current.scale.setScalar(next);
    const mat = meshRef.current.material as THREE.MeshStandardMaterial;
    const targetEmissive = selected ? 1.1 : hovered ? 0.82 : relationDepth === 1 ? 0.55 : relationDepth === 2 ? 0.28 : 0.16;
    mat.emissiveIntensity += (targetEmissive - mat.emissiveIntensity) * 0.055;
    mat.opacity += ((dimmed ? 0.12 : relationDepth === 2 ? 0.5 : 0.94) - mat.opacity) * 0.06;

    if (auraRef.current) {
      const auraMaterial = auraRef.current.material as THREE.MeshBasicMaterial;
      const auraTargetOpacity = hovered ? 0.28 : selected ? 0.2 : relationDepth === 1 && !dimmed ? 0.08 : 0;
      const auraTargetScale = hovered ? 1.32 : selected ? 1.22 : relationDepth === 1 ? 1.04 : 0.86;
      auraRef.current.scale.x += (auraTargetScale - auraRef.current.scale.x) * 0.07;
      auraRef.current.scale.y += (auraTargetScale - auraRef.current.scale.y) * 0.07;
      auraRef.current.scale.z += (auraTargetScale - auraRef.current.scale.z) * 0.07;
      auraMaterial.opacity += (auraTargetOpacity - auraMaterial.opacity) * 0.08;
    }
  });

  const showLabel = selected || hovered || labelVisible;
  const labelIsFocus = selected || hovered;
  const labelIsRelated = !labelIsFocus && relationDepth === 1;
  const showLogoBadge = selected || hovered || (labelVisible && !dimmed && (pocketed || relationDepth === 1));
  const labelLane = ((Math.abs(Math.round(tool.angle / 8)) + tool.orbit) % 5) - 2;
  const labelLaneSpacing = pocketed ? 19 : 12;
  const labelStyle = {
    '--label-x': labelIsFocus ? '0px' : `${labelLane * labelLaneSpacing}px`,
    '--label-y': labelIsFocus ? '-46px' : pocketed ? '-39px' : labelIsRelated ? '-34px' : '-26px',
    '--label-scale': labelIsFocus ? '1.06' : pocketed ? '0.98' : labelIsRelated ? '0.98' : '0.92',
    borderColor: `${color}66`,
    boxShadow: labelIsFocus
      ? `0 0 26px ${glow}, 0 10px 32px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.2)`
      : `0 0 14px ${glow}, inset 0 1px 0 rgba(255,255,255,0.14)`,
    opacity: showLabel ? (dimmed ? 0.48 : labelIsFocus ? 1 : 0.86) : 0,
  } as CSSProperties;

  return (
    <group
      ref={groupRef}
      position={initialPosition}
      onClick={() => onSelect(id)}
      onPointerOver={(event) => {
        event.stopPropagation();
        setHovered(true);
        onToolHover(id, category);
      }}
      onPointerOut={(event) => {
        event.stopPropagation();
        setHovered(false);
        onToolHover(null, null);
      }}
    >
      <mesh geometry={HIT_GEOM}>
        <meshBasicMaterial transparent opacity={0} depthWrite={false} />
      </mesh>
      <mesh ref={auraRef} geometry={AURA_GEOM}>
        <meshBasicMaterial
          color={color}
          transparent
          opacity={0}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      <mesh ref={meshRef} geometry={CORE_GEOM}>
        <meshStandardMaterial
          color={color}
          emissive={color}
          emissiveIntensity={0.3}
          transparent
          opacity={0.74}
        />
      </mesh>
      <Billboard>
        <Html
          center
          distanceFactor={7}
          zIndexRange={showLogoBadge ? (labelIsFocus ? [105, 82] : [72, 42]) : [0, 0]}
          style={{ pointerEvents: showLogoBadge ? 'auto' : 'none' }}
        >
          <button
            type="button"
            aria-label={`Inspect ${name}`}
            className={`universe-node-logo-badge ${showLogoBadge ? 'is-visible' : ''} ${labelIsFocus ? 'is-focus' : ''} ${pocketed ? 'is-pocket' : ''}`}
            onClick={() => onSelect(id)}
            onMouseEnter={() => {
              setHovered(true);
              onToolHover(id, category);
            }}
            onMouseLeave={() => {
              setHovered(false);
              onToolHover(null, null);
            }}
            style={{
              '--node-logo-color': color,
              '--node-logo-glow': glow,
            } as CSSProperties}
          >
            {showLogoBadge && <ToolLogo tool={tool} size={labelIsFocus ? 58 : 38} className="universe-node-logo-badge__image" />}
          </button>
        </Html>
      </Billboard>
      <Billboard>
        <Html
          center
          distanceFactor={7.4}
          zIndexRange={showLabel ? (labelIsFocus ? [100, 80] : labelIsRelated ? [80, 44] : [46, 20]) : [0, 0]}
          style={{ pointerEvents: showLabel ? 'auto' : 'none' }}
        >
          <div
            aria-hidden={!showLabel}
            className={`universe-label universe-label-tool ${showLabel ? 'is-visible' : ''} ${labelIsFocus ? 'is-focus' : ''} ${labelIsRelated ? 'is-related' : ''} ${pocketed ? 'is-pocket' : ''}`}
            onClick={() => onSelect(id)}
            onMouseEnter={() => {
              setHovered(true);
              onToolHover(id, category);
            }}
            onMouseLeave={() => {
              setHovered(false);
              onToolHover(null, null);
            }}
            style={labelStyle}
          >
            {showLabel && (
              <span className="universe-label-logo">
                <ToolLogo tool={tool} size={20} />
              </span>
            )}
            <span>{name.length > 18 ? `${name.slice(0, 17)}...` : name}</span>
          </div>
        </Html>
      </Billboard>
    </group>
  );
}
