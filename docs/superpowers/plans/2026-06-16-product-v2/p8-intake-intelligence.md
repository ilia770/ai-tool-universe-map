# P8 · Intake Intelligence Implementation Plan

> Part of the 2026-06-16 product-v2 set — depends on **P0 (knowledge foundation)** and feeds **P9 (relationships)**. This part makes adding a tool *smart and HONEST*: accurate classification, confidence gating instead of hallucination, an ambiguous/giant guard, and dynamic category creation. Cross-lane (web React+Vite + iOS SwiftUI), sharing the rule taxonomy where possible.

## Goal

Today the intake guesses. The web classifier (`src/lib/classify-ai-tool.ts`) maps a pasted name/URL onto one of 8 fixed `ToolCategoryId`s and *always* returns something — even when wrong or unknown. Concretely:

- **`posthog` → `distribution`** (which renders with `shortName: "Social"`) because the rule set has the keyword `post` under distribution. PostHog is Product Analytics, not social.
- `datadog` → `research` (keyword `data`); `mixpanel`, `amplitude`, `sentry`, `grafana` → the `core` fallback at confidence `0.34`. There is **no analytics/observability category at all**.
- Unknown/low-confidence input silently lands at `core` (`fallbackResult`) — a bogus entry — with no "I'm not sure" path.
- Giant/ambiguous input (`instagram`, `google`) also lands at `core` with zero confirmation.
- iOS has **no classifier or add-tool intake whatsoever** — only data models (`Tool.swift`, `ToolCategory.swift`, `UniverseSeed.swift`) decoding the canonical seed.

This plan delivers, on BOTH lanes:

1. **Accurate classification** — a corrected/expanded rule taxonomy with a new `analytics` category so observability/analytics tools never fall into Social or the `core` bucket; a regression test asserting `posthog` and a handful of commonly-misplaced tools classify correctly.
2. **Confidence gating** — a `notFound` / `unsure` outcome (never a guessed entry) that prompts: *"Не нашёл такой сервис — скинь ссылку на сайт, определю что это и добавлю."* and then classifies from the URL/domain (+ any pasted text).
3. **Ambiguous / giant guard** — for huge or ambiguous inputs (`instagram`, `google`) the system asks *"Ты уверен? Это <X>?"* before adding, with a refine affordance.
4. **Dynamic category creation** — when no existing category fits, the system mints a NEW named category and places the tool there instead of forcing a wrong fit; the web map and iOS RealityKit scene render the new branch.

## Architecture

The single source of truth for *what the classifier knows* becomes a canonical JSON artifact, mirroring the P0 knowledge pattern and the existing `ai-tool-universe.seed.json` cross-lane contract (web `src/data/` ↔ `ios-app/Sources/MyAIMap/Resources/`, kept byte-identical):

```
src/data/classifier-taxonomy.ts        (authored TS source — CATEGORY_RULES + DOMAIN_RULES + ambiguous/giant lists)
        │  scripts/gen-classifier-json.mjs   (deterministic, key-sorted emit)
        ▼
src/data/classifier-taxonomy.json      (canonical artifact, committed)
        │  copied verbatim (gen script writes BOTH paths)
        ▼
ios-app/Sources/MyAIMap/Resources/classifier-taxonomy.json
        │  ClassifierStore.swift decodes once, lazily, Bundle(for:)
        ▼
ToolClassifier.swift  ──► iOS AddTool intake (AddToolSheet.swift)
```

Web flow (extends the existing pipeline, does not replace it):

```
AddToolModal.tsx  ──text──►  classifyToolIntake(text)   (new wrapper in classify-ai-tool.ts)
                                   │
        ┌──────────────┬───────────┼────────────────┬───────────────────┐
        ▼              ▼           ▼                 ▼                   ▼
    classified     unsure       ambiguous         giant            newCategory
   (conf ≥ HI)   (conf < LO    (in AMBIGUOUS    (in GIANT set)   (no rule fits AND
                  / no rule)     set → confirm)   → confirm)       a domain/text token
                       │                                            implies a fresh branch)
                       └─► prompt for URL ─► re-run on domain ─► classified | newCategory
```

The classifier becomes a small state machine returning a **discriminated `IntakeOutcome`** rather than always a `ClassificationResult`. `classifyToolDetailed` / `classifyTool` keep their current signatures (so existing callers and `classify-ai-tool.test.ts` stay green); the new `classifyToolIntake` wraps them and adds the gating, guard, and dynamic-category branches.

**Dynamic categories** are a runtime extension to the fixed `categoryById` map. The seed's 8 categories stay immutable; user/dynamic categories live in the tool store (web `store.tsx` `dynamicCategories` state; iOS `UniverseViewModel` `@Published dynamicCategories`). A dynamic category gets a deterministic id (`dyn-<slug>`), a name the classifier proposes, a color/glow derived from a stable hash of the id, and the next free `angle` (max existing angle + golden-angle step) so the new branch slots into the orbit ring without overlapping. Both renderers already iterate `categories` (web `GalaxyMap.tsx` line ~581 maps over `categories`; iOS `CategoryRail.swift` `ForEach(UniverseSeed.categories)`), so they switch to iterating `allCategories = [...seed, ...dynamic]`.

The `analytics` category (fix for P8.1) is a **permanent seed category**, added to the union and the seed JSON — distinct from dynamic categories, which are runtime-only.

## Tech Stack

- **Web**: TypeScript (`classify-ai-tool.ts`, `classifier-taxonomy.ts`), Node ESM generator (`.mjs`, matches `scripts/check-bundle-size.mjs` / P0's `gen-knowledge-json.mjs`), Vitest (`npm run test`, matches `classify-ai-tool.test.ts`), React 18 + Vite, liquid-glass design tokens from `src/playground/designSystem.ts` (`GLASS`, `RADIUS`, `EASE`, `DURATION`, `FOCUS_RING`, press `active:scale-[0.96/0.98]`).
- **iOS**: Swift 6 (strict concurrency `complete`), `Codable`/`Decodable`, `Bundle(for:)` resource loading (matches `UniverseSeed.swift`), Swift Testing (`import Testing`, `@Test`/`#expect`, matches `SeedIntegrityTests.swift`), SwiftUI sheet + `BrandHaptics` + `LiquidGlass` + `PressBounce`, `@Environment(UniverseViewModel.self)`. XcodeGen auto-copies `Sources/MyAIMap/Resources/*` into the bundle.
- **Motion/accessibility**: tap/long-press/swipe, press feedback `0.96`, micro-anim, haptics, honor reduce-motion (web `prefersReducedMotion()` already in `AddToolModal.tsx`; iOS `accessibilityReduceMotion`), 60fps.
- No new dependencies on either lane.

---

## Task 1 — Web: add the `analytics` category to the type union + seed

Introduces the permanent category that fixes the PostHog class of bugs, before touching any rules. Verified today: `ToolCategoryId` is an 8-member union in `src/data/ai-tool-universe.ts`; categories are defined in `src/data/ai-tool-universe.seed.json` and the iOS copy must stay byte-identical (`scripts/ios-verify.sh` enforces it).

**Files**

- Modify: `/tmp/wt-ios/src/data/ai-tool-universe.ts`
- Modify: `/tmp/wt-ios/src/data/ai-tool-universe.seed.json`
- Modify: `/tmp/wt-ios/ios-app/Sources/MyAIMap/Resources/ai-tool-universe.seed.json` (byte-identical copy)
- Modify: `/tmp/wt-ios/src/data/ai-tool-universe.test.ts`

**Steps**

1. Write a failing test in `ai-tool-universe.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { categories, categoryById, type ToolCategoryId } from './ai-tool-universe';

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
```

2. Run `npm run test -- src/data/ai-tool-universe.test.ts` → fails (no `analytics`).
3. Minimal impl: add `| 'analytics'` to the `ToolCategoryId` union in `ai-tool-universe.ts`. Add the category object to the `categories` array in BOTH seed JSONs (web + iOS Resources), e.g.:

```json
{
  "id": "analytics",
  "name": "Analytics & Observability",
  "shortName": "Analytics",
  "description": "Product analytics, telemetry, error tracking, dashboards, and observability for shipped software.",
  "color": "#ff9bd2",
  "glow": "rgba(255, 155, 210, 0.28)",
  "angle": 128
}
```

   Pick an `angle` not already used by the 8 existing categories (verified used: 74 for distribution, etc.) so the orbital-slot test passes.
4. Run `npm run test -- src/data/ai-tool-universe.test.ts` → green. Run `npm run typecheck` (the union widens; `categoryById` map is exhaustive, no `switch` to update).
5. Verify the JSON copies are identical: `diff -q src/data/ai-tool-universe.seed.json ios-app/Sources/MyAIMap/Resources/ai-tool-universe.seed.json`.
6. Commit: `feat(p8): add analytics & observability category (fixes posthog→social)`.

---

## Task 2 — iOS: mirror the `analytics` category in the Swift union

Keeps the compiler-enforced parity (`ToolCategoryId` is `CaseIterable` and `SeedIntegrityTests` asserts `categories.count == 8`).

**Files**

- Modify: `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/ToolCategory.swift`
- Modify: `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/SeedIntegrityTests.swift`

**Steps**

1. Update the failing count test in `SeedIntegrityTests.swift`:

```swift
@Test func decodesExpectedCounts() {
    #expect(UniverseSeed.tools.count == 49)
    #expect(UniverseSeed.categories.count == 9) // was 8 — analytics added in P8
}

@Test func analyticsCategoryExists() {
    let analytics = UniverseSeed.category(.analytics)
    #expect(analytics.id == .analytics)
    #expect(analytics.shortName == "Analytics")
}
```

2. Run `npm run ios:test-build` → fails (no `.analytics` case; decode count mismatch).
3. Minimal impl: add `case analytics` to the `ToolCategoryId` enum in `ToolCategory.swift` (alphabetical placement is irrelevant; keep next to related cases for readability). The seed JSON was already updated byte-identically in Task 1, so decode now yields 9.
4. Run `npm run ios:test-build` → green.
5. Commit: `feat(p8): mirror analytics category in iOS ToolCategoryId`.

---

## Task 3 — Web: extract the classifier taxonomy into a canonical, generatable artifact

Moves the inline `classifierRules` / `domainRules` out of `classify-ai-tool.ts` into an authored TS module + emitted JSON so iOS can decode the *same* rules. Mirrors P0's generator/drift-guard pattern exactly.

**Files**

- Create: `/tmp/wt-ios/src/data/classifier-taxonomy.ts`
- Create: `/tmp/wt-ios/scripts/gen-classifier-json.mjs`
- Create: `/tmp/wt-ios/src/data/classifier-taxonomy.json` (emitted, committed)
- Create: `/tmp/wt-ios/ios-app/Sources/MyAIMap/Resources/classifier-taxonomy.json` (byte-identical, emitted)
- Modify: `/tmp/wt-ios/src/lib/classify-ai-tool.ts` (import rules from the new module)
- Create: `/tmp/wt-ios/src/data/classifier-taxonomy.test.ts`

**Steps**

1. Write a failing drift-guard test in `classifier-taxonomy.test.ts`:

```ts
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
```

2. Run `npm run test -- src/data/classifier-taxonomy.test.ts` → fails (module + JSON do not exist).
3. Minimal impl:
   - Create `classifier-taxonomy.ts` exporting `CATEGORY_RULES`, `DOMAIN_RULES`, `AMBIGUOUS`, `GIANT`. Port the existing 7 rule objects from `classify-ai-tool.ts` verbatim, then apply the fixes:
     - **Remove** the `post` keyword from `distribution` (use only unambiguous tokens: `social`, `buffer`, `hootsuite`, `mailchimp`, `newsletter`, `publish`, `schedule post`, etc.).
     - **Add** an `analytics` rule (stage `review`): keywords `['amplitude','analytics','dashboards','datadog','grafana','heap','honeycomb','logs','mixpanel','observability','posthog','sentry','telemetry','tracking']`, anchors `['founder-os']`.
     - **Remove** `data` from `research` keywords *only if* it still over-captures `datadog`; keep `dataset`/`data intake` (datadog is now caught by the analytics domain/keyword rule, which wins on a longer/more specific match — assert this in Task 5).
   - Add `AMBIGUOUS` and `GIANT` arrays (small, explicit lists) — full content authored in Task 6/7; here they may start as `[]` then be filled, but the gen step must already serialize them.
   - Create `gen-classifier-json.mjs` (Node ESM, sorted keys, writes both web + iOS paths — copy the structure of P0's `gen-knowledge-json.mjs`).
   - Run the generator: `node scripts/gen-classifier-json.mjs`.
   - In `classify-ai-tool.ts`, replace the inline `classifierRules` / `domainRules` consts with imports from `classifier-taxonomy.ts` (keep `ClassifierRule`/`DomainRule` types; keep `fallbackResult`, `classifyToolDetailed`, `classifyTool` signatures unchanged).
4. Run `npm run test` (full) → `classify-ai-tool.test.ts` must STILL be green (signatures unchanged). Run `npm run typecheck`.
5. `diff -q src/data/classifier-taxonomy.json ios-app/Sources/MyAIMap/Resources/classifier-taxonomy.json`.
6. Commit: `feat(p8): canonical classifier taxonomy artifact + generator + drift guard`.

---

## Task 4 — Web: regression test for commonly-misplaced tools (the PostHog audit)

Locks in the accurate-classification fix with concrete assertions before relying on it elsewhere.

**Files**

- Modify: `/tmp/wt-ios/src/lib/classify-ai-tool.test.ts`

**Steps**

1. Add a failing `describe` block:

```ts
describe('classifyTool — misplacement regression audit', () => {
  it('classifies PostHog as analytics, never social/distribution', () => {
    expect(classifyTool('posthog')).toBe('analytics');
    expect(classifyTool('https://posthog.com')).toBe('analytics');
    expect(classifyTool('posthog')).not.toBe('distribution');
  });

  it('routes the analytics/observability cohort correctly', () => {
    expect(classifyTool('mixpanel')).toBe('analytics');
    expect(classifyTool('amplitude')).toBe('analytics');
    expect(classifyTool('sentry')).toBe('analytics');
    expect(classifyTool('grafana')).toBe('analytics');
    expect(classifyTool('https://www.datadoghq.com')).toBe('analytics');
  });

  it('does not regress the previously-correct cohort', () => {
    expect(classifyTool('https://cursor.com')).toBe('coding');
    expect(classifyTool('Make in Figma')).toBe('design');
    expect(classifyTool('Remotion video renderer')).toBe('media');
    expect(classifyTool('https://buffer.com/')).toBe('distribution');
  });
});
```

2. Run `npm run test -- src/lib/classify-ai-tool.test.ts` → expect any still-failing cases (e.g. `datadog` if the `data` keyword still wins for `research`, or `sentry`/`grafana` if keyword scoring ties).
3. Minimal impl: tune `classifier-taxonomy.ts` (re-run `node scripts/gen-classifier-json.mjs` after each edit) — e.g. add a `datadoghq.com` / `sentry.io` / `grafana.com` entry to `DOMAIN_RULES` for high-confidence routing, and ensure analytics keyword scoring beats research/distribution. Keep edits surgical.
4. Run `npm run test` (full) → green, including the unchanged original assertions.
5. Commit: `test(p8): regression audit pins posthog + analytics cohort to analytics`.

---

## Task 5 — Web: `IntakeOutcome` state machine (confidence gating + URL fallback)

Adds the HONEST layer: a discriminated outcome that returns `unsure` instead of guessing, and re-classifies from a URL when prompted. Pure logic, fully unit-tested before any UI.

**Files**

- Modify: `/tmp/wt-ios/src/lib/classify-ai-tool.ts`
- Create: `/tmp/wt-ios/src/lib/intake.ts`
- Create: `/tmp/wt-ios/src/lib/intake.test.ts`

**Steps**

1. Write failing tests in `intake.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { classifyIntake, UNSURE_PROMPT } from './intake';

describe('classifyIntake — confidence gating', () => {
  it('returns "classified" for a confident, known tool', () => {
    const out = classifyIntake('https://cursor.com');
    expect(out.kind).toBe('classified');
    if (out.kind === 'classified') expect(out.result.category).toBe('coding');
  });

  it('returns "unsure" (NOT a guess) for an unknown low-confidence token', () => {
    const out = classifyIntake('zxqwobble');
    expect(out.kind).toBe('unsure');
    if (out.kind === 'unsure') {
      expect(out.prompt).toBe(UNSURE_PROMPT);
      expect(out.prompt).toContain('скинь ссылку на сайт');
    }
  });

  it('re-classifies from a pasted URL after an unsure result', () => {
    const out = classifyIntake('zxqwobble', { url: 'https://posthog.com' });
    expect(out.kind).toBe('classified');
    if (out.kind === 'classified') expect(out.result.category).toBe('analytics');
  });
});
```

2. Run `npm run test -- src/lib/intake.test.ts` → fails (module missing).
3. Minimal impl in `intake.ts`:

```ts
import { classifyToolDetailed, type ClassificationResult } from './classify-ai-tool';
import { AMBIGUOUS, GIANT } from '../data/classifier-taxonomy';

export const UNSURE_PROMPT =
  'Не нашёл такой сервис — скинь ссылку на сайт, определю что это и добавлю.';
export const CONFIDENCE_FLOOR = 0.45; // below this we do NOT auto-place

export type IntakeOutcome =
  | { kind: 'classified'; result: ClassificationResult; name: string }
  | { kind: 'unsure'; prompt: string; query: string }
  | { kind: 'ambiguous'; result: ClassificationResult; name: string; question: string }
  | { kind: 'newCategory'; suggestedName: string; result: ClassificationResult; name: string };

export function classifyIntake(
  text: string,
  opts: { url?: string } = {},
): IntakeOutcome {
  const source = (opts.url ?? text).trim();
  const norm = source.toLowerCase();

  if (GIANT.includes(norm)) { /* → Task 7 */ }
  if (AMBIGUOUS.includes(norm)) { /* → Task 7 */ }

  const result = classifyToolDetailed(source);
  const hasUrl = /\.[a-z]{2,}/i.test(source) || source.startsWith('http');

  // Unknown AND no URL to reason from → ask, do not guess.
  if (result.category === 'core' && result.confidence <= CONFIDENCE_FLOOR && !hasUrl) {
    return { kind: 'unsure', prompt: UNSURE_PROMPT, query: text.trim() };
  }
  // No rule fit even with a URL → dynamic category (→ Task 6).
  // ...
  return { kind: 'classified', result, name: getDisplayName(source) };
}
```

   (Import `getDisplayName` from `classify-ai-tool.ts`.)
4. Run `npm run test` (full) → green.
5. Commit: `feat(p8): IntakeOutcome state machine — unsure gating + URL fallback`.

---

## Task 6 — Web: dynamic category creation

When even a URL/text produces no category fit, mint a new named branch instead of dumping into `core`.

**Files**

- Modify: `/tmp/wt-ios/src/lib/intake.ts`
- Modify: `/tmp/wt-ios/src/playground/store.tsx`
- Modify: `/tmp/wt-ios/src/playground/toolStoreContext.ts`
- Create: `/tmp/wt-ios/src/lib/dynamic-category.ts`
- Create: `/tmp/wt-ios/src/lib/dynamic-category.test.ts`

**Steps**

1. Failing tests in `dynamic-category.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { makeDynamicCategory } from './dynamic-category';
import { categories } from '../data/ai-tool-universe';

describe('makeDynamicCategory', () => {
  it('creates a stable id, a non-empty name, and a unique angle', () => {
    const existing = categories;
    const cat = makeDynamicCategory('Voice Cloning', existing);
    expect(cat.id).toBe('dyn-voice-cloning');
    expect(cat.shortName.length).toBeGreaterThan(0);
    expect(existing.some((c) => c.angle === cat.angle)).toBe(false);
  });

  it('is deterministic for the same name', () => {
    expect(makeDynamicCategory('Voice Cloning', categories))
      .toEqual(makeDynamicCategory('Voice Cloning', categories));
  });
});
```

2. Run `npm run test -- src/lib/dynamic-category.test.ts` → fails.
3. Minimal impl in `dynamic-category.ts`: `makeDynamicCategory(name, existing)` → `{ id: 'dyn-' + makeSlug(name), name, shortName: firstWord(name), description, color: hslFromHash(id), glow, angle: nextFreeAngle(existing) }` where `nextFreeAngle` = `(max(existing.angle) + 137.508) % 360` re-rolled until unique. Wire `intake.ts` to return `{ kind: 'newCategory', suggestedName, ... }` when `classifyToolDetailed` returns `core`/low-confidence WITH a URL present.
4. Extend `store.tsx`: add `dynamicCategories` state + `addTool` accepts an optional resolved `IntakeOutcome`; on `newCategory` it appends the dynamic category (dedupe by id) and places the tool in it. Expose `allCategories` (seed + dynamic) on `ToolStore` (update `toolStoreContext.ts`). The web map (`variants/GalaxyMap.tsx` etc.) reads `allCategories` instead of the static `categories` import — minimal, since they already `.map` over a categories array; the new branch renders automatically.
5. Run `npm run test` (full) → green. `npm run typecheck`.
6. Commit: `feat(p8): dynamic category creation + render new branch on web map`.

---

## Task 7 — Web: ambiguous / giant guard

Adds the confirmation gate for huge/ambiguous inputs.

**Files**

- Modify: `/tmp/wt-ios/src/data/classifier-taxonomy.ts` (fill `AMBIGUOUS`, `GIANT`; re-run gen)
- Modify: `/tmp/wt-ios/src/lib/intake.ts`
- Modify: `/tmp/wt-ios/src/lib/intake.test.ts`

**Steps**

1. Add failing tests:

```ts
describe('classifyIntake — ambiguous / giant guard', () => {
  it('asks for confirmation on a giant, ambiguous brand', () => {
    const out = classifyIntake('instagram');
    expect(out.kind).toBe('ambiguous');
    if (out.kind === 'ambiguous') expect(out.question).toContain('Ты уверен? Это');
  });

  it('asks before adding a mega-platform', () => {
    expect(classifyIntake('google').kind).toBe('ambiguous');
  });

  it('still classifies a confirmed selection', () => {
    const out = classifyIntake('instagram', { confirmed: true });
    expect(out.kind).toBe('classified');
  });
});
```

2. Run → fails.
3. Minimal impl: fill `GIANT = ['google','instagram','facebook','amazon','apple','microsoft','meta']` and `AMBIGUOUS` (brands that span many categories). In `classifyIntake`, when `norm` is in those lists and `!opts.confirmed`, return `{ kind: 'ambiguous', question: 'Ты уверен? Это ' + getDisplayName(source) + '?', ... }`. Re-run `node scripts/gen-classifier-json.mjs`.
4. Run `npm run test` (full) → green.
5. Commit: `feat(p8): ambiguous/giant intake guard with confirmation`.

---

## Task 8 — Web: wire intake states into `AddToolModal` (liquid glass UX)

Surfaces `unsure` / `ambiguous` / `newCategory` in the existing modal, reusing its motion/haptics/reduce-motion contract.

**Files**

- Modify: `/tmp/wt-ios/src/playground/AddToolModal.tsx`
- Create: `/tmp/wt-ios/src/playground/AddToolModal.test.tsx`

**Steps**

1. Failing component tests (`@testing-library/react`, already a devDep):

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
// renders the modal inside ToolStoreProvider, types an unknown token,
// and asserts the unsure prompt + URL field appear (not an Add CTA).
describe('AddToolModal intake states', () => {
  it('shows the unsure prompt + URL input for an unknown token', async () => {
    // ...type 'zxqwobble' → expect UNSURE_PROMPT text, expect a url <input>
  });
  it('shows the "Ты уверен?" confirm row for a giant brand', async () => {
    // ...type 'instagram' → expect confirm question + Refine + Yes buttons
  });
});
```

2. Run `npm run test -- src/playground/AddToolModal.test.tsx` → fails.
3. Minimal impl: replace the single `preview` `useMemo` with `const outcome = useMemo(() => classifyIntake(trimmed, { url, confirmed }), [...])`. Render per `outcome.kind`:
   - `classified` / `newCategory`: existing brand-plate preview (newCategory shows a "Новая ветка: <name>" chip using the dynamic color).
   - `unsure`: the prompt copy in a glass info row (`GLASS.chip`) + a second URL `<input>` (same styling as the name input); the Add CTA stays disabled until the URL resolves.
   - `ambiguous`: a confirm row — question text + `Refine` (clears) and `Да, добавить` (sets `confirmed`) buttons, each `min-h-[44px]`, `active:scale-[0.96]`, `haptic()` on `onPointerDown`, `FOCUS_RING`, entrance `atm-rise` gated on `!reduced`.
   `submit()` routes through `addTool` with the resolved outcome (Task 6 store change). No change to swipe-to-dismiss / focus-trap / celebration logic.
4. Run `npm run test` (full) → green. Manual 60fps + reduce-motion check via `npm run dev`.
5. Commit: `feat(p8): surface unsure/ambiguous/new-category intake states in AddToolModal`.

---

## Task 9 — iOS: port the classifier from the canonical taxonomy

Gives iOS the same rules the web uses, decoded from the byte-identical JSON.

**Files**

- Create: `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/ClassifierStore.swift`
- Create: `/tmp/wt-ios/ios-app/Sources/MyAIMap/Intake/ToolClassifier.swift`
- Create: `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/ToolClassifierTests.swift`

**Steps**

1. Failing test in `ToolClassifierTests.swift` (Swift Testing):

```swift
import Testing
@testable import MyAIMap

struct ToolClassifierTests {
    @Test func classifiesPostHogAsAnalyticsNotSocial() {
        let out = ToolClassifier.shared.classify("posthog")
        guard case .classified(let r) = out else { Issue.record("expected classified"); return }
        #expect(r.category == .analytics)
        #expect(r.category != .distribution)
    }

    @Test func unsureForUnknownTokenWithoutURL() {
        let out = ToolClassifier.shared.classify("zxqwobble")
        guard case .unsure(let prompt, _) = out else { Issue.record("expected unsure"); return }
        #expect(prompt.contains("скинь ссылку на сайт"))
    }

    @Test func reclassifiesFromURL() {
        let out = ToolClassifier.shared.classify("zxqwobble", url: "https://posthog.com")
        guard case .classified(let r) = out else { Issue.record("expected classified"); return }
        #expect(r.category == .analytics)
    }
}
```

2. Run `npm run ios:test-build` → fails (types missing).
3. Minimal impl:
   - `ClassifierStore.swift`: decode `classifier-taxonomy.json` lazily via `Bundle(for:)` (copy `UniverseSeed.swift`'s `BundleToken` pattern); expose `categoryRules`, `domainRules`, `ambiguous`, `giant`.
   - `ToolClassifier.swift`: a `enum IntakeOutcome` (`classified`/`unsure`/`ambiguous`/`newCategory`) + `ClassificationResult` struct + `classify(_:url:confirmed:)` mirroring `intake.ts` scoring (keyword `count/10 + 1`, confidence formula, `CONFIDENCE_FLOOR = 0.45`, the giant/ambiguous lists, the URL `\.[a-z]{2,}` heuristic). `UNSURE_PROMPT` is the same Russian string constant.
4. Run `npm run ios:test-build` → green.
5. Commit: `feat(p8): iOS ToolClassifier from canonical taxonomy (parity with web)`.

---

## Task 10 — iOS: dynamic categories in the view model + add-tool intake sheet

Brings the full intake UX (and dynamic branch rendering) to iOS.

**Files**

- Modify: `/tmp/wt-ios/ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- Create: `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Sheets/AddToolSheet.swift`
- Modify: `/tmp/wt-ios/ios-app/Sources/MyAIMap/UI/Sheets/CategoryRail.swift` (iterate `model.allCategories`)
- Create: `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/AddToolIntakeTests.swift`

**Steps**

1. Failing test in `AddToolIntakeTests.swift`:

```swift
import Testing
@testable import MyAIMap

@MainActor struct AddToolIntakeTests {
    @Test func addingAnUnfittableURLMintsADynamicCategory() {
        let model = UniverseViewModel()
        let before = model.allCategories.count
        model.addTool(text: "QuantumKnitting", url: "https://quantumknitting.example")
        #expect(model.allCategories.count == before + 1)
        #expect(model.allCategories.contains { $0.id.rawValueOrString.hasPrefix("dyn-") })
    }

    @Test func giantBrandRequiresConfirmation() {
        let model = UniverseViewModel()
        let added = model.addTool(text: "instagram") // unconfirmed
        #expect(added == nil) // gated — no tool added until confirmed
    }
}
```

   (Use a `DynamicToolCategory` value type so `id` can be a free-form string `dyn-…`; `ToolCategoryId` enum stays for seed categories. `allCategories` returns a unified view type.)
2. Run `npm run ios:test-build` → fails.
3. Minimal impl:
   - `UniverseViewModel`: add `@Published private(set) var dynamicCategories: [DynamicToolCategory]` + `var allCategories: [CategoryDisplay]` (seed mapped + dynamic) + `addTool(text:url:confirmed:)` that runs `ToolClassifier`, mints a dynamic category on `.newCategory` (Swift mirror of `makeDynamicCategory`: `dyn-<slug>` id, hash-derived color, golden-angle next-free slot), returns `nil` on `.ambiguous`/`.unsure` until resolved.
   - `AddToolSheet.swift`: SwiftUI `.sheet` with a `LiquidGlass` background, name `TextField`, live state row per outcome (unsure prompt + URL field; ambiguous "Ты уверен? Это <X>?" with Refine/Confirm buttons), `PressBounce`/`.scaleEffect(pressed ? 0.96 : 1)`, `BrandHaptics` on tap/confirm, `@Environment(\.accessibilityReduceMotion)` to disable entrance anims. Present it from the universe screen's add affordance (long-press/`+`).
   - `CategoryRail.swift`: change `ForEach(UniverseSeed.categories)` → `ForEach(model.allCategories)` so a new dynamic branch chip appears (and the RealityKit scene, which lays out by category, picks up the new orbit slot from `allCategories`).
4. Run `npm run ios:test-build` → green.
5. Commit: `feat(p8): iOS add-tool intake sheet + dynamic categories render new branch`.

---

## Task 11 — Cross-lane parity + drift guards

Final integrity pass so the two lanes can't silently diverge (same guarantee the seed already enjoys).

**Files**

- Modify: `/tmp/wt-ios/scripts/ios-verify.sh` (add `classifier-taxonomy.json` to the `diff -q` byte-identity checks)
- Modify: `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/ToolClassifierTests.swift` (add the misplacement-cohort cases mirroring web Task 4: mixpanel/amplitude/sentry/grafana/datadog → `.analytics`)

**Steps**

1. Add the iOS cohort regression `@Test` cases (mirror of web Task 4). Run `npm run ios:test-build` → expect green (taxonomy is shared) or surface a real iOS-only scoring gap to fix.
2. Add the taxonomy JSON to `ios-verify.sh`'s identity diff; run `npm run ios:verify` to confirm byte-identity of both seed + taxonomy JSONs.
3. Run the full web suite `npm run test` and `npm run typecheck` once more.
4. Commit: `test(p8): cross-lane classifier parity + taxonomy drift guard`.

---

## Verification checklist (success criteria)

- `npm run test` green, including: `posthog`/`mixpanel`/`amplitude`/`sentry`/`grafana`/`datadog` → `analytics`; original cohort unchanged; `unsure`/`ambiguous`/`newCategory` outcomes; dynamic-category determinism; modal state rendering.
- `npm run ios:test-build` green, including the Swift mirrors of every logic test above.
- `npm run ios:verify` confirms `ai-tool-universe.seed.json` AND `classifier-taxonomy.json` are byte-identical across lanes.
- Manual: web `npm run dev` + iOS simulator — adding an unknown token shows the Russian "скинь ссылку" prompt (no bogus entry); a URL resolves it; `instagram`/`google` ask "Ты уверен?"; an unfittable URL mints and renders a new branch; all interactions hold 60fps and respect reduce-motion.
