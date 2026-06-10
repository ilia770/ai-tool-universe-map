import { describe, expect, it } from 'vitest';
import {
  filterValidCustomTools,
  getToolArrayPayload,
  isValidCustomToolPayload,
  validateUniverseData,
} from './universe-schema';

const makeTool = (overrides: Record<string, unknown> = {}) => ({
  id: 'custom-test-tool',
  name: 'Test Tool',
  category: 'coding',
  summary: 'A custom service used to verify import validation behavior.',
  stage: 'execution',
  orbit: 3,
  angle: 42,
  url: 'https://example.com',
  relationIds: ['founder-os'],
  classification: {
    confidence: 0.72,
    matchedKeywords: ['test'],
    reason: 'Matched a test fixture.',
  },
  ...overrides,
});

describe('universe schema helpers', () => {
  it('keeps the production universe data valid', () => {
    expect(validateUniverseData()).toEqual({ errors: [], ok: true });
  });

  it('accepts a valid custom tool payload', () => {
    expect(isValidCustomToolPayload(makeTool(), {
      knownToolIds: new Set(['founder-os']),
    })).toBe(true);
  });

  it('extracts array payloads from raw arrays or exported objects', () => {
    const tools = [makeTool()];

    expect(getToolArrayPayload(tools)).toBe(tools);
    expect(getToolArrayPayload({ version: 1, tools })).toBe(tools);
    expect(getToolArrayPayload({ version: 1 })).toBeNull();
  });

  it('rejects malformed fields before they reach the map', () => {
    expect(isValidCustomToolPayload(makeTool({ id: 'founder-os' }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ category: 'unknown' }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ stage: 'unknown' }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ orbit: 4 }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ angle: Number.NaN }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ url: 'not a url' }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ classification: { confidence: 2, matchedKeywords: [], reason: 'bad' } }))).toBe(false);
  });

  it('rejects duplicate, self, or dangling relations', () => {
    expect(isValidCustomToolPayload(makeTool({ relationIds: ['founder-os', 'founder-os'] }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ relationIds: ['custom-test-tool'] }))).toBe(false);
    expect(isValidCustomToolPayload(makeTool({ relationIds: ['missing-tool'] }), {
      knownToolIds: new Set(['founder-os']),
    })).toBe(false);
  });

  it('filters imports to valid unique tools while allowing imported tools to link to each other', () => {
    const first = makeTool({ id: 'custom-first', relationIds: ['custom-second'] });
    const second = makeTool({ id: 'custom-second', relationIds: ['founder-os'] });
    const duplicateSecond = makeTool({ id: 'custom-second', name: 'Duplicate Second' });
    const dangling = makeTool({ id: 'custom-dangling', relationIds: ['missing-tool'] });

    expect(filterValidCustomTools({ version: 1, tools: [first, second, duplicateSecond, dangling] }).map((tool) => tool.id))
      .toEqual(['custom-first', 'custom-second']);
  });
});
