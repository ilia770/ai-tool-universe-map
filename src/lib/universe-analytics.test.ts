import { describe, expect, test, vi } from 'vitest';
import { createUniverseAnalyticsEvent, trackUniverseEvent } from './universe-analytics';

describe('createUniverseAnalyticsEvent', () => {
  test('keeps event payload minimal and source-aware', () => {
    expect(createUniverseAnalyticsEvent('deeplink_resolved', {
      source: { utmSource: 'ad', utmCampaign: 'launch', tgStart: 'event-42' },
      deeplinkType: 'tool',
      targetId: 'cursor',
    })).toMatchObject({
      name: 'deeplink_resolved',
      payload: {
        source: { utmSource: 'ad', utmCampaign: 'launch', tgStart: 'event-42' },
        deeplinkType: 'tool',
        targetId: 'cursor',
      },
    });
  });
});

describe('trackUniverseEvent', () => {
  test('dispatches a browser event and appends to the local analytics queue', () => {
    const dispatched: Event[] = [];
    const target = {
      aiToolUniverseAnalytics: [],
      dispatchEvent: vi.fn((event: Event) => {
        dispatched.push(event);
        return true;
      }),
    };

    trackUniverseEvent('search_submitted', { query: 'cursor', resultCount: 1 }, target);

    expect(target.aiToolUniverseAnalytics).toHaveLength(1);
    expect(target.aiToolUniverseAnalytics[0]).toMatchObject({
      name: 'search_submitted',
      payload: { query: 'cursor', resultCount: 1 },
    });
    expect(target.dispatchEvent).toHaveBeenCalledTimes(1);
    expect((dispatched[0] as CustomEvent).detail).toMatchObject({
      name: 'search_submitted',
      payload: { query: 'cursor', resultCount: 1 },
    });
  });
});
