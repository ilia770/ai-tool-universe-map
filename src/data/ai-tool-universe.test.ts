import { describe, expect, it } from 'vitest';
import universeSeed from './ai-tool-universe.seed.json';
import {
  categories,
  categoryById,
  tools,
  toolById,
  workflowLinks,
  workflowStages,
  type ToolCategoryId,
} from './ai-tool-universe';

const allowedOrbits = new Set([0, 1, 2, 3]);
const allowedStrengths = new Set(['primary', 'secondary']);

describe('analytics category', () => {
  it('exists as a distinct, non-social category', () => {
    const analytics = categoryById.get('analytics' as ToolCategoryId);
    expect(analytics).toBeDefined();
    expect(analytics?.shortName).toBe('Analytics');
    // Must NOT collide with distribution ("Social").
    expect(analytics?.id).not.toBe('distribution');
  });

  it('keeps a stable, gap-free angle layout for all categories', () => {
    const angles = categories.map((c) => c.angle);
    expect(new Set(angles).size).toBe(angles.length); // no duplicate orbital slots
  });
});

describe('ai tool universe data', () => {
  it('loads the production universe from the JSON seed', () => {
    expect(universeSeed.version).toBe(1);
    expect(universeSeed.tools[0]?.id).toBe('founder-os');
    expect(universeSeed.categories).toHaveLength(categories.length);
    expect(universeSeed.tools).toHaveLength(tools.length);
    expect(universeSeed.workflowLinks).toHaveLength(workflowLinks.length);
  });

  it('keeps founder-os as the central first node', () => {
    expect(tools[0]).toMatchObject({
      id: 'founder-os',
      category: 'core',
      orbit: 0,
    });
  });

  it('has unique category and tool ids', () => {
    expect(new Set(categories.map((category) => category.id)).size).toBe(categories.length);
    expect(new Set(tools.map((tool) => tool.id)).size).toBe(tools.length);
  });

  it('keeps derived lookup maps in sync with source arrays', () => {
    expect(categoryById.size).toBe(categories.length);
    expect(toolById.size).toBe(tools.length);

    categories.forEach((category) => {
      expect(categoryById.get(category.id)).toBe(category);
    });
    tools.forEach((tool) => {
      expect(toolById.get(tool.id)).toBe(tool);
    });
  });

  it('keeps tools inside known categories, stages, orbits, URLs, and confidence bounds', () => {
    const categoryIds = new Set(categories.map((category) => category.id));
    const stageIds = new Set(Object.keys(workflowStages));

    tools.forEach((tool) => {
      expect(categoryIds.has(tool.category), `${tool.id} category`).toBe(true);
      expect(stageIds.has(tool.stage), `${tool.id} stage`).toBe(true);
      expect(allowedOrbits.has(tool.orbit), `${tool.id} orbit`).toBe(true);
      expect(Number.isFinite(tool.angle), `${tool.id} angle`).toBe(true);
      expect(tool.summary.trim().length, `${tool.id} summary`).toBeGreaterThan(20);

      const { url } = tool;
      if (url) {
        expect(() => new URL(url), `${tool.id} url`).not.toThrow();
      }

      if (tool.classification) {
        expect(tool.classification.confidence, `${tool.id} confidence`).toBeGreaterThanOrEqual(0);
        expect(tool.classification.confidence, `${tool.id} confidence`).toBeLessThanOrEqual(1);
      }
    });
  });

  it('does not leave dangling relation or workflow links', () => {
    tools.forEach((tool) => {
      tool.relationIds.forEach((relationId) => {
        expect(toolById.has(relationId), `${tool.id} -> ${relationId}`).toBe(true);
        expect(relationId, `${tool.id} self relation`).not.toBe(tool.id);
      });
    });

    workflowLinks.forEach((link) => {
      expect(toolById.has(link.source), `${link.source} source`).toBe(true);
      expect(toolById.has(link.target), `${link.target} target`).toBe(true);
      expect(allowedStrengths.has(link.strength), `${link.source} -> ${link.target} strength`).toBe(true);
      if (link.confidence !== undefined) {
        expect(link.confidence, `${link.source} -> ${link.target} confidence`).toBeGreaterThanOrEqual(0);
        expect(link.confidence, `${link.source} -> ${link.target} confidence`).toBeLessThanOrEqual(1);
      }
    });
  });
});
