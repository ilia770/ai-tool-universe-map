import type { UniverseAcquisitionSource } from './universe-url-state';

export type UniverseAnalyticsEventName =
  | 'map_opened'
  | 'deeplink_resolved'
  | 'tool_selected'
  | 'category_opened'
  | 'search_submitted'
  | 'custom_tool_added'
  | 'onboarding_action'
  | 'webgl_fallback'
  | 'logo_fallback';

export interface UniverseAnalyticsPayload {
  source?: UniverseAcquisitionSource;
  [key: string]: string | number | boolean | UniverseAcquisitionSource | undefined;
}

export interface UniverseAnalyticsEvent {
  name: UniverseAnalyticsEventName;
  payload: UniverseAnalyticsPayload;
  timestamp: string;
}

interface AnalyticsTarget {
  aiToolUniverseAnalytics?: UniverseAnalyticsEvent[];
  dispatchEvent?: (event: CustomEvent<UniverseAnalyticsEvent>) => boolean;
}

declare global {
  interface Window {
    aiToolUniverseAnalytics?: UniverseAnalyticsEvent[];
  }
}

export const createUniverseAnalyticsEvent = (
  name: UniverseAnalyticsEventName,
  payload: UniverseAnalyticsPayload = {},
): UniverseAnalyticsEvent => ({
  name,
  payload,
  timestamp: new Date().toISOString(),
});

export const trackUniverseEvent = (
  name: UniverseAnalyticsEventName,
  payload: UniverseAnalyticsPayload = {},
  target: AnalyticsTarget | undefined = typeof window === 'undefined' ? undefined : window,
) => {
  if (!target) return;

  const event = createUniverseAnalyticsEvent(name, payload);
  const queue = target.aiToolUniverseAnalytics ?? [];
  queue.push(event);
  target.aiToolUniverseAnalytics = queue.slice(-100);
  target.dispatchEvent?.(new CustomEvent('ai-tool-universe:analytics', { detail: event }));
};
