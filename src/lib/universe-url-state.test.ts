import { describe, expect, test } from 'vitest';
import {
  buildUniverseSearch,
  parseUniverseUrlState,
  type UniverseUrlWritableState,
} from './universe-url-state';

const toolIds = new Set(['founder-os', 'cursor', 'buffer']);
const categoryIds = new Set(['coding', 'design', 'distribution', 'core']);

describe('parseUniverseUrlState', () => {
  test('resolves tool, source, and acquisition metadata from query params', () => {
    const state = parseUniverseUrlState(
      '?tool=cursor&utm_source=telegram&utm_medium=bot&utm_campaign=launch&tg_start=event-42',
      { toolIds, categoryIds },
    );

    expect(state.toolId).toBe('cursor');
    expect(state.hasExplicitState).toBe(true);
    expect(state.source).toEqual({
      utmSource: 'telegram',
      utmMedium: 'bot',
      utmCampaign: 'launch',
      ref: undefined,
      tgStart: 'event-42',
    });
    expect(state.invalidParams).toEqual([]);
  });

  test('keeps invalid deeplink evidence recoverable without applying it', () => {
    const state = parseUniverseUrlState('?tool=missing-tool&category=unknown&q=agent', {
      toolIds,
      categoryIds,
    });

    expect(state.toolId).toBeUndefined();
    expect(state.category).toBe('all');
    expect(state.query).toBe('agent');
    expect(state.invalidParams).toEqual([
      { name: 'tool', value: 'missing-tool' },
      { name: 'category', value: 'unknown' },
    ]);
  });
});

describe('buildUniverseSearch', () => {
  test('writes shareable map state while preserving acquisition params', () => {
    const writableState: UniverseUrlWritableState = {
      selectedId: 'cursor',
      activeCategory: 'coding',
      activeStage: 'execution',
      query: 'agent',
      relationLens: 'category',
    };

    expect(buildUniverseSearch('?utm_source=ad&ref=telegram', writableState)).toBe(
      '?utm_source=ad&ref=telegram&tool=cursor&category=coding&stage=execution&q=agent&lens=category',
    );
  });

  test('removes default map state from the URL but keeps source params', () => {
    const writableState: UniverseUrlWritableState = {
      selectedId: 'founder-os',
      activeCategory: 'all',
      activeStage: 'all',
      query: '',
      relationLens: 'direct',
    };

    expect(buildUniverseSearch('?utm_source=ad&tool=cursor&q=agent', writableState)).toBe('?utm_source=ad');
  });
});
