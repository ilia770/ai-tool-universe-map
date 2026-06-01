import { useMemo } from 'react';
import { QuadraticBezierLine } from '@react-three/drei';
import type { ToolCategoryId, UniverseLink, WorkflowStageId } from '../../data/ai-tool-universe';

type RelationLens = 'direct' | 'adjacent' | 'stage' | 'category';

interface ConnectionLinesProps {
  links: UniverseLink[];
  positionById: Map<string, [number, number, number]>;
  relationDepthById: Map<string, number>;
  lensRelevantIds: Set<string>;
  toolCategoryById: Map<string, ToolCategoryId>;
  toolStageById: Map<string, WorkflowStageId>;
  focusedCategory: ToolCategoryId | null;
  pocketCategory: ToolCategoryId | null;
  relationLens: RelationLens;
  selectedId: string;
}

export function ConnectionLines({
  links,
  positionById,
  relationDepthById,
  lensRelevantIds,
  toolCategoryById,
  toolStageById,
  focusedCategory,
  pocketCategory,
  relationLens,
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
      const bothInLens = lensRelevantIds.has(link.source) && lensRelevantIds.has(link.target);
      const sameStage = toolStageById.get(link.source) === toolStageById.get(link.target);
      const sameCategory = toolCategoryById.get(link.source) === toolCategoryById.get(link.target);
      const sourceCategory = toolCategoryById.get(link.source);
      const targetCategory = toolCategoryById.get(link.target);
      const bothInPocket = Boolean(pocketCategory) && sourceCategory === pocketCategory && targetCategory === pocketCategory;
      const touchesPocket = Boolean(pocketCategory) && (sourceCategory === pocketCategory || targetCategory === pocketCategory);
      const inFocusedCategory = focusedCategory
        ? toolCategoryById.get(link.source) === focusedCategory || toolCategoryById.get(link.target) === focusedCategory
        : true;
      return [{ link, start, end, isSelected, relationDepth, inFocusedCategory, bothInLens, bothInPocket, touchesPocket, sameStage, sameCategory }];
    }),
    [
      focusedCategory,
      lensRelevantIds,
      links,
      pocketCategory,
      positionById,
      relationDepthById,
      selectedId,
      toolCategoryById,
      toolStageById,
    ],
  );

  return (
    <>
      {lineData.map(({ link, start, end, isSelected, relationDepth, inFocusedCategory, bothInLens, bothInPocket, touchesPocket, sameStage, sameCategory }) => {
        const isFounderMode = selectedId === 'founder-os';
        const isPrimary = link.strength === 'primary';
        const isLensLine = relationLens === 'stage'
          ? bothInLens && sameStage
          : relationLens === 'category'
            ? bothInLens && sameCategory
            : bothInLens;
        const opacity = (() => {
          if (isSelected) return bothInPocket ? 0.86 : 0.58;
          if (bothInPocket && isLensLine) return 0.5;
          if (bothInPocket) return 0.32;
          if (touchesPocket && isLensLine) return 0.14;
          if (isLensLine && relationLens === 'adjacent' && relationDepth <= 2) return 0.18;
          if (isLensLine && (relationLens === 'stage' || relationLens === 'category')) return 0.14;
          if (relationDepth === 1) return 0.22;
          if (relationDepth === 2) return 0.075;
          if (isFounderMode && isPrimary) return 0.12;
          return 0.012;
        })();
        const lineWidth = (() => {
          if (isSelected) return bothInPocket ? 2.6 : 1.65;
          if (bothInPocket && isLensLine) return 1.6;
          if (bothInPocket) return 1.18;
          if (isLensLine) return 0.78;
          if (relationDepth === 1) return 0.86;
          if (isPrimary) return 0.62;
          return 0.24;
        })();
        const focusMultiplier = inFocusedCategory || touchesPocket ? 1 : 0.08;

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
