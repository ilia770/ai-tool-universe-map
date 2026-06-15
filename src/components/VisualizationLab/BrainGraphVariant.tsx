import { useMemo } from 'react';
import type { LabData } from './visualization-data';
import { getConnectedNodeIds } from './visualization-data';

interface BrainGraphVariantProps {
  data: LabData;
  selectedId: string;
  onSelect: (id: string) => void;
}

const width = 1100;
const height = 680;
const centerX = width / 2;
const centerY = height / 2;

function positionFor(index: number, count: number, orbit: number, angle: number) {
  const ring = 90 + orbit * 86 + (index % 5) * 12;
  const theta = (angle * Math.PI) / 180 + (index / Math.max(count, 1)) * Math.PI * 0.4;

  return {
    x: centerX + Math.cos(theta) * ring,
    y: centerY + Math.sin(theta) * ring * 0.72,
  };
}

export function BrainGraphVariant({ data, selectedId, onSelect }: BrainGraphVariantProps) {
  const connected = useMemo(() => getConnectedNodeIds(data, selectedId), [data, selectedId]);
  const positions = useMemo(() => {
    const map = new Map<string, { x: number; y: number }>();

    data.nodes.forEach((node, index) => {
      map.set(
        node.id,
        node.id === selectedId ? { x: centerX, y: centerY } : positionFor(index, data.nodes.length, node.orbit, node.angle),
      );
    });

    return map;
  }, [data.nodes, selectedId]);

  return (
    <div className="h-full min-h-[620px] bg-[radial-gradient(circle_at_50%_50%,rgba(103,232,249,0.16),transparent_35%),#03040a]">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" aria-labelledby="ai-brain-title ai-brain-desc">
        <title id="ai-brain-title">AI Brain relationship graph</title>
        <desc id="ai-brain-desc">Select a node to center it and reveal its direct AI tool relationships.</desc>
        <style>
          {`
            .ai-brain-node:focus-visible > .ai-brain-focus-ring {
              stroke: rgba(255,255,255,0.88);
              stroke-width: 3;
            }
          `}
        </style>
        <g>
          {data.links.map((link) => {
            const source = positions.get(link.source);
            const target = positions.get(link.target);
            if (!source || !target) return null;

            const active = connected.has(link.source) && connected.has(link.target);

            return (
              <line
                key={link.id}
                x1={source.x}
                y1={source.y}
                x2={target.x}
                y2={target.y}
                stroke={active ? 'rgba(155,232,255,0.62)' : 'rgba(255,255,255,0.10)'}
                strokeWidth={active ? 1.8 : 1}
              />
            );
          })}
        </g>
        <g>
          {data.nodes.map((node, index) => {
            const position = positions.get(node.id) ?? positionFor(index, data.nodes.length, node.orbit, node.angle);
            const isSelected = node.id === selectedId;
            const isConnected = connected.has(node.id);
            const radius = isSelected ? 30 : 9 + node.weight * 3.2;

            return (
              <g
                key={node.id}
                transform={`translate(${position.x} ${position.y})`}
                opacity={isSelected || isConnected ? 1 : 0.28}
                role="button"
                tabIndex={0}
                aria-label={`Select ${node.label}`}
                onClick={() => onSelect(node.id)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    onSelect(node.id);
                  }
                }}
                className="ai-brain-node"
                style={{ cursor: 'pointer' }}
              >
                <circle className="ai-brain-focus-ring" r={radius + 20} fill="none" stroke="transparent" />
                <circle r={radius + 16} fill={node.color} opacity={isSelected ? 0.18 : 0.08} />
                <circle r={radius} fill={node.color} opacity={isSelected ? 0.95 : 0.78} />
                {(isSelected || isConnected) && (
                  <text
                    y={radius + 20}
                    textAnchor="middle"
                    fill="white"
                    fontSize={isSelected ? 17 : 12}
                    fontWeight={isSelected ? 700 : 500}
                  >
                    {node.label}
                  </text>
                )}
              </g>
            );
          })}
        </g>
      </svg>
    </div>
  );
}
