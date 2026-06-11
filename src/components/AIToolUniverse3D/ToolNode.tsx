import { type CSSProperties, memo, useEffect, useRef, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Html } from '@react-three/drei';
import type { Group, Mesh } from 'three';
import * as THREE from 'three';
import type { AITool } from '../../data/ai-tool-universe';
import { ToolLogo } from '../ToolLogo';

// Shared geometries: one BufferGeometry per role, reused across every
// ToolNode instance instead of allocating ~3 × N spheres on mount.
const HIT_GEOM = new THREE.SphereGeometry(0.68, 18, 18);
const AURA_GEOM = new THREE.SphereGeometry(0.46, 24, 24);
const CORE_GEOM = new THREE.SphereGeometry(0.3, 20, 20);
const LABEL_EXIT_MS = 540;
const BADGE_EXIT_MS = 460;

interface ToolNodeProps {
  id: string;
  name: string;
  tool: AITool;
  position: [number, number, number];
  color: string;
  glow: string;
  selected: boolean;
  activeFocus: boolean;
  relationDepth?: number;
  labelVisible: boolean;
  dimmed: boolean;
  interactive: boolean;
  pocketed: boolean;
  reducedMotion: boolean;
  onSelect: (id: string) => void;
  onToolHover: (id: string | null) => void;
}

function ToolNodeImpl({
  id,
  name,
  tool,
  position,
  color,
  glow,
  selected,
  activeFocus,
  relationDepth,
  labelVisible,
  dimmed,
  interactive,
  pocketed,
  reducedMotion,
  onSelect,
  onToolHover,
}: ToolNodeProps) {
  const groupRef = useRef<Group>(null);
  const meshRef = useRef<Mesh>(null);
  const auraRef = useRef<Mesh>(null);
  const targetPositionRef = useRef(new THREE.Vector3(...position));
  const [initialPosition] = useState<[number, number, number]>(() => [...position]);
  const wantsLabel = selected || activeFocus || labelVisible;
  const wantsLogoBadge = activeFocus;
  const [labelMounted, setLabelMounted] = useState(wantsLabel);
  const [logoBadgeMounted, setLogoBadgeMounted] = useState(wantsLogoBadge);

  useEffect(() => {
    targetPositionRef.current.set(position[0], position[1], position[2]);
  }, [position]);

  useEffect(() => {
    const delay = wantsLabel || reducedMotion ? 0 : LABEL_EXIT_MS;
    const handle = window.setTimeout(() => setLabelMounted(wantsLabel), delay);
    return () => window.clearTimeout(handle);
  }, [reducedMotion, wantsLabel]);

  useEffect(() => {
    const delay = wantsLogoBadge || reducedMotion ? 0 : BADGE_EXIT_MS;
    const handle = window.setTimeout(() => setLogoBadgeMounted(wantsLogoBadge), delay);
    return () => window.clearTimeout(handle);
  }, [reducedMotion, wantsLogoBadge]);

  useFrame(() => {
    if (groupRef.current) {
      const positionEase = pocketed || selected ? 0.07 : 0.052;
      if (reducedMotion || groupRef.current.position.distanceToSquared(targetPositionRef.current) < 0.0004) {
        groupRef.current.position.copy(targetPositionRef.current);
      } else {
        groupRef.current.position.lerp(targetPositionRef.current, positionEase);
      }
    }

    if (!meshRef.current) return;
    const targetScale = activeFocus ? 1.42 : selected ? 1.2 : relationDepth === 1 ? 1.12 : relationDepth === 2 ? 1.03 : 0.9;
    const currentScale = meshRef.current.scale.x;
    const next = reducedMotion || Math.abs(targetScale - currentScale) < 0.002
      ? targetScale
      : currentScale + (targetScale - currentScale) * 0.055;
    meshRef.current.scale.setScalar(next);
    const mat = meshRef.current.material as THREE.MeshStandardMaterial;
    const targetEmissive = activeFocus ? 1.35 : selected ? 0.72 : relationDepth === 1 ? 0.55 : relationDepth === 2 ? 0.28 : 0.16;
    mat.emissiveIntensity = reducedMotion || Math.abs(targetEmissive - mat.emissiveIntensity) < 0.002
      ? targetEmissive
      : mat.emissiveIntensity + (targetEmissive - mat.emissiveIntensity) * 0.055;
    const targetOpacity = dimmed ? 0.12 : relationDepth === 2 ? 0.5 : 0.94;
    mat.opacity = reducedMotion || Math.abs(targetOpacity - mat.opacity) < 0.002
      ? targetOpacity
      : mat.opacity + (targetOpacity - mat.opacity) * 0.06;

    if (auraRef.current) {
      const auraMaterial = auraRef.current.material as THREE.MeshBasicMaterial;
      const auraTargetOpacity = activeFocus ? 0.38 : selected ? 0.18 : relationDepth === 1 && !dimmed ? 0.08 : 0;
      const auraTargetScale = activeFocus ? 1.58 : selected ? 1.22 : relationDepth === 1 ? 1.04 : 0.86;
      const nextAuraScale = reducedMotion || Math.abs(auraTargetScale - auraRef.current.scale.x) < 0.002
        ? auraTargetScale
        : auraRef.current.scale.x + (auraTargetScale - auraRef.current.scale.x) * 0.07;
      auraRef.current.scale.setScalar(nextAuraScale);
      auraMaterial.opacity = reducedMotion || Math.abs(auraTargetOpacity - auraMaterial.opacity) < 0.002
        ? auraTargetOpacity
        : auraMaterial.opacity + (auraTargetOpacity - auraMaterial.opacity) * 0.08;
    }
  });

  const labelIsFocus = activeFocus;
  const labelIsRelated = !labelIsFocus && relationDepth === 1;
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
    opacity: wantsLabel ? (dimmed ? 0.42 : labelIsFocus ? 1 : 0.86) : 0,
  } as CSSProperties;
  const htmlPointerEvents = interactive ? 'auto' : 'none';
  const htmlCursor = interactive ? 'pointer' : 'default';

  return (
    <group
      ref={groupRef}
      position={initialPosition}
      onClick={() => {
        if (interactive) onSelect(id);
      }}
      onPointerOver={(event) => {
        if (!interactive) return;
        event.stopPropagation();
        onToolHover(id);
      }}
      onPointerOut={(event) => {
        if (!interactive) return;
        event.stopPropagation();
        onToolHover(null);
      }}
    >
      <mesh geometry={HIT_GEOM} visible={interactive}>
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
          zIndexRange={logoBadgeMounted ? (labelIsFocus ? [105, 82] : [72, 42]) : [0, 0]}
          style={{ pointerEvents: wantsLogoBadge ? htmlPointerEvents : 'none' }}
        >
          <button
            type="button"
            aria-label={`Inspect ${name}`}
            aria-hidden={!wantsLogoBadge}
            tabIndex={wantsLogoBadge && interactive ? 0 : -1}
            title={name}
            className={`universe-node-logo-badge ${wantsLogoBadge ? 'is-visible' : ''} ${labelIsFocus ? 'is-focus' : ''} ${pocketed ? 'is-pocket' : ''}`}
            onClick={() => {
              if (interactive) onSelect(id);
            }}
            onMouseEnter={() => {
              if (interactive) onToolHover(id);
            }}
            onMouseLeave={() => {
              if (interactive) onToolHover(null);
            }}
            onFocus={() => {
              if (interactive) onToolHover(id);
            }}
            onBlur={() => {
              if (interactive) onToolHover(null);
            }}
            style={{
              '--node-logo-color': color,
              '--node-logo-glow': glow,
              cursor: htmlCursor,
            } as CSSProperties}
          >
            {logoBadgeMounted && <ToolLogo tool={tool} size={labelIsFocus ? 58 : 38} className="universe-node-logo-badge__image" />}
          </button>
        </Html>
      </Billboard>
      <Billboard>
        <Html
          center
          distanceFactor={7.4}
          zIndexRange={labelMounted ? (labelIsFocus ? [100, 80] : labelIsRelated ? [80, 44] : [46, 20]) : [0, 0]}
          style={{ pointerEvents: wantsLabel ? htmlPointerEvents : 'none' }}
        >
          <div
            aria-hidden={!wantsLabel}
            title={name}
            className={`universe-label universe-label-tool ${wantsLabel ? 'is-visible' : ''} ${labelIsFocus ? 'is-focus' : ''} ${labelIsRelated ? 'is-related' : ''} ${pocketed ? 'is-pocket' : ''}`}
            onClick={() => {
              if (interactive) onSelect(id);
            }}
            onMouseEnter={() => {
              if (interactive) onToolHover(id);
            }}
            onMouseLeave={() => {
              if (interactive) onToolHover(null);
            }}
            style={{ ...labelStyle, cursor: htmlCursor }}
          >
            {labelMounted && (
              <span className="universe-label-logo">
                <ToolLogo tool={tool} size={20} />
              </span>
            )}
            <span className="universe-label-name">{name}</span>
          </div>
        </Html>
      </Billboard>
    </group>
  );
}

export const ToolNode = memo(ToolNodeImpl);
