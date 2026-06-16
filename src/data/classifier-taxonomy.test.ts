import { describe, expect, it } from 'vitest';
import taxonomy from './classifier-taxonomy.json';
import { CATEGORY_RULES, DOMAIN_RULES, AMBIGUOUS, GIANT } from './classifier-taxonomy';

describe('classifier taxonomy artifact', () => {
  it('committed JSON matches the authored TS source (no drift)', () => {
    expect(taxonomy).toEqual({
      version: 1,
      categoryRules: CATEGORY_RULES,
      domainRules: DOMAIN_RULES,
      ambiguous: AMBIGUOUS,
      giant: GIANT,
    });
  });

  it('routes analytics/observability tools away from social', () => {
    const analytics = CATEGORY_RULES.find((r) => r.category === 'analytics');
    expect(analytics?.keywords).toEqual(
      expect.arrayContaining(['posthog', 'mixpanel', 'amplitude', 'analytics', 'observability', 'telemetry']),
    );
    const distribution = CATEGORY_RULES.find((r) => r.category === 'distribution');
    expect(distribution?.keywords).not.toContain('post'); // the bug seed
  });
});
