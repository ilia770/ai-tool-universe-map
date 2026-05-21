import { useMemo } from 'react';
import { QuadraticBezierLine } from '@react-three/drei';
import type { ToolCategoryId, UniverseLink } from '../../data/ai-tool-universe';

interface ConnectionLinesProps {
  links: UniverseLink[];
  positionById: Map<string, [number, number, number]>;
  relationDepthById: Map<string, number>;
  toolCategoryById: Map<string, ToolCategoryId>;
  focusedCategory: ToolCategoryId | null;
  selectedId: string;
}

export function ConnectionLines({
  links,
  positionById,
  relationDepthById,
  toolCategoryById,
  focusedCategory,
  selectedId,
}: ConnectionLinesProps) {
  const lineData = useMemo(() =>
    links.flatMap((link) => {
      const start = positionById.get(link.source);
      const end = positionById.get(link.target);
      if (!start || !end) return [];
      const isSelected = link.source === selectedId || link.target === selectedId;
      const sourceDepth = relationDepthById.get(link.source) ?? 99;
      const targetDepth = relationDepthById.get(link.target) ?? 99;
      const relationDepth = Math.min(sourceDepth, targetDepth);
      const inFocusedCategory = focusedCategory
        ? toolCategoryById.get(link.source) === focusedCategory || toolCategoryById.get(link.target) === focusedCategory
        : true;
      return [{ link, start, end, isSelected, relationDepth, inFocusedCategory }];
    }),
    [focusedCategory, links, positionById, relationDepthById, selectedId, toolCategoryById],
  );

  return (
    <>
      {lineData.map(({ link, start, end, isSelected, relationDepth, inFocusedCategory }) => {
        const isFounderMode = selectedId === 'founder-os';
        const isPrimary = link.strength === 'primary';
        const opacity = isSelected
          ? 0.82
          : relationDepth === 1
            ? 0.38
            : relationDepth === 2
              ? 0.16
              : isFounderMode && isPrimary
                ? 0.18
                : 0.025;
        const lineWidth = isSelected ? 2.25 : relationDepth === 1 ? 1.25 : isPrimary ? 0.8 : 0.32;
        const focusMultiplier = inFocusedCategory ? 1 : 0.18;

        return (
          <QuadraticBezierLine
            key={`${link.source}-${link.target}`}
            start={start}
            end={end}
            color={isSelected ? '#dffcff' : isPrimary ? '#9be8ff' : '#ffffff'}
            lineWidth={lineWidth}
            opacity={opacity * focusMultiplier}
            transparent
          />
        );
      })}
    </>
  );
}
