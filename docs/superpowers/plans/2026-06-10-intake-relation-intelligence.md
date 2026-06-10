# Intake Relation Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Liquid Glass intake classifier return explainable relation suggestions, not only a category/stage.

**Architecture:** Keep the current rule-based classifier and make it richer without changing 3D scene ownership. Add typed `RelationSuggestion` objects to `classifyToolDetailed`, keep `relationIds` backward-compatible for the existing UI, and document the completed classifier work in `docs/AGENT_STATUS.md`.

**Tech Stack:** TypeScript, Vitest, existing React/Vite data model.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `src/lib/classify-ai-tool.ts` | Rule-based intake classifier with category, workflow stage, confidence, matched keywords, relation ids, and relation suggestions. |
| `src/lib/classify-ai-tool.test.ts` | Unit tests for category classification, display helpers, fallback behavior, and relation suggestion metadata. |
| `docs/AGENT_STATUS.md` | Durable handoff dashboard for what changed, validation, and remaining risks. |

### Task 1: Add Relation Suggestion Types

**Files:**
- Modify: `src/lib/classify-ai-tool.ts`

- [x] **Step 1: Extend classifier result types**

Add these exports near the classifier interfaces:

```ts
type RelationSuggestionSource = 'category-anchor' | 'direct-match' | 'fallback-review' | 'workflow-anchor';

export interface RelationSuggestion {
  id: string;
  label: string;
  reason: string;
  confidence: number;
  source: RelationSuggestionSource;
}
```

Then add `relationSuggestions: RelationSuggestion[]` to `ClassificationResult`.

- [x] **Step 2: Convert rule anchors from strings to metadata**

Change each `anchors: string[]` rule field to `anchors: RelationSuggestionSeed[]`, where each seed has:

```ts
interface RelationSuggestionSeed {
  id: string;
  label: string;
  reason: string;
  source: Exclude<RelationSuggestionSource, 'direct-match' | 'fallback-review'>;
}
```

- [x] **Step 3: Keep backward compatibility**

Make sure `ClassificationResult.relationIds` still returns `relationSuggestions.map((suggestion) => suggestion.id)` so existing UI remains unchanged.

### Task 2: Build Suggestion Generation

**Files:**
- Modify: `src/lib/classify-ai-tool.ts`

- [x] **Step 1: Add helper functions**

Add helpers:

```ts
const makeRelationSuggestions = (
  seeds: RelationSuggestionSeed[],
  normalizedInput: string,
  baseConfidence: number,
): RelationSuggestion[] => seeds.map((seed, index) => {
  const directMatch = normalizedInput.includes(seed.id) || normalizedInput.includes(seed.label.toLowerCase());
  return {
    ...seed,
    confidence: Number(Math.min(0.98, Math.max(0.35, baseConfidence - index * 0.07 + (directMatch ? 0.08 : 0))).toFixed(2)),
    source: directMatch ? 'direct-match' : seed.source,
  };
});
```

Use a compatibility-safe variation if TypeScript needs explicit typing.

- [x] **Step 2: Update fallback result**

Fallback should include:

```ts
relationSuggestions: [
  {
    id: 'founder-os',
    label: 'manual review in Founder OS',
    reason: 'No strong keyword matched, so this should stay near the operating core until a human connects it.',
    confidence: 0.34,
    source: 'fallback-review',
  },
],
relationIds: ['founder-os'],
```

- [x] **Step 3: Update classified result**

For a matched rule:

```ts
const relationSuggestions = makeRelationSuggestions(ranked.rule.anchors, normalized, confidence);

return {
  category: ranked.rule.category,
  stage: ranked.rule.stage,
  confidence: Number(confidence.toFixed(2)),
  matchedKeywords: signals,
  relationSuggestions,
  relationIds: relationSuggestions.map((suggestion) => suggestion.id),
  reason: `Matched ${signals.map((signal) => `"${signal}"`).join(', ')} and suggested ${relationSuggestions.length} relation anchors in the closest workflow orbit.`,
};
```

### Task 3: Test Relation Suggestions

**Files:**
- Modify: `src/lib/classify-ai-tool.test.ts`

- [x] **Step 1: Update existing intake preview test**

Assert that Buffer includes an explainable approval relation:

```ts
expect(result.relationSuggestions).toEqual(
  expect.arrayContaining([
    expect.objectContaining({
      id: 'approval-gate',
      label: expect.any(String),
      reason: expect.stringContaining('approval'),
      source: expect.any(String),
    }),
  ]),
);
```

- [x] **Step 2: Add fallback suggestion test**

Add:

```ts
it('keeps unknown tools near Founder OS with a fallback relation suggestion', () => {
  const result = classifyToolDetailed('mysterious private beta');

  expect(result.category).toBe('core');
  expect(result.relationSuggestions).toEqual([
    expect.objectContaining({
      id: 'founder-os',
      source: 'fallback-review',
    }),
  ]);
});
```

- [x] **Step 3: Add direct-match boost test**

Add:

```ts
it('marks direct anchor matches in relation suggestions', () => {
  const result = classifyToolDetailed('Vercel deploy preview runtime');

  expect(result.category).toBe('infrastructure');
  expect(result.relationSuggestions[0]).toMatchObject({
    id: 'vercel',
    source: 'direct-match',
  });
  expect(result.relationSuggestions[0].confidence).toBeGreaterThanOrEqual(result.confidence);
});
```

### Task 4: Update Agent Status

**Files:**
- Modify: `docs/AGENT_STATUS.md`

- [x] **Step 1: Add a current work note**

Add a row or note saying:

```markdown
| Intake relation intelligence | `classifyToolDetailed` now returns explainable relation suggestions while preserving `relationIds` | `npm run typecheck`, `npm test`, `npm run build` | Next UI pass can render suggestion reasons in the Liquid Glass preview |
```

- [x] **Step 2: Verify status mentions the new classifier field**

Run:

```bash
rg "relation suggestions|classifyToolDetailed" docs/AGENT_STATUS.md
```

Expected: both phrases appear.

### Task 5: Validate And Commit

**Files:**
- Validate all files above.

- [x] **Step 1: Run unit tests**

Run:

```bash
npm test -- src/lib/classify-ai-tool.test.ts
```

Expected: classify tests pass.

- [x] **Step 2: Run project checks**

Run:

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

Expected: all commands exit 0.

- [x] **Step 3: Commit**

Run:

```bash
git add src/lib/classify-ai-tool.ts src/lib/classify-ai-tool.test.ts docs/AGENT_STATUS.md docs/superpowers/plans/2026-06-10-intake-relation-intelligence.md
git commit -m "feat: add explainable intake relation suggestions"
```

Expected: one focused commit.

## Self-Review

Spec coverage:
- Liquid Glass intake gets stronger classification metadata.
- Existing UI compatibility is preserved through `relationIds`.
- Agent status receives a durable handoff note.

Placeholder scan:
- No TODO/TBD placeholders.
- All tasks have exact file paths and commands.

Type consistency:
- `RelationSuggestion` fields match the tests and classifier return shape.
