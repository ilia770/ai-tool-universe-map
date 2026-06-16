import { afterEach, describe, expect, it } from 'vitest';
import {
  DEFAULT_SETTINGS,
  loadPersisted,
  persist,
  serializeExport,
  type PersistedState,
} from './store';

const KEY = 'playground.store.v1';

afterEach(() => {
  if (typeof localStorage !== 'undefined') localStorage.clear();
});

describe('store persistence', () => {
  it('defaults when nothing is stored', () => {
    const state = loadPersisted();
    expect(state.added).toHaveLength(0);
    expect(state.settings).toEqual(DEFAULT_SETTINGS);
  });

  it('round-trips added tools + settings', () => {
    const state: PersistedState = {
      added: [{ id: 'x', name: 'X' } as PersistedState['added'][number]],
      icons: { x: 'data:image/png;base64,AA' },
      settings: { language: 'ru', variantId: 'K' },
    };
    persist(state);
    const back = loadPersisted();
    expect(back.added.map((t) => t.id)).toEqual(['x']);
    expect(back.icons.x).toBe('data:image/png;base64,AA');
    expect(back.settings).toEqual({ language: 'ru', variantId: 'K' });
  });

  it('falls back to defaults on corrupt json', () => {
    localStorage.setItem(KEY, '{not json');
    expect(loadPersisted().settings).toEqual(DEFAULT_SETTINGS);
  });

  it('serializeExport emits added tools + settings as JSON', () => {
    const json = serializeExport(
      [{ id: 'x', name: 'X' } as PersistedState['added'][number]],
      { language: 'en', variantId: 'A' },
    );
    const parsed = JSON.parse(json);
    expect(parsed.tools[0].id).toBe('x');
    expect(parsed.settings.variantId).toBe('A');
    expect(typeof parsed.exportedAt).toBe('string');
  });
});
