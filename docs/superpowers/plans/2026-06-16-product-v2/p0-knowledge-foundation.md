# P0 Knowledge Foundation Implementation Plan

> Part of the 2026-06-16 product-v2 set — this is the FOUNDATION other parts (chat, detail, hyperbrain) depend on.

## Goal

Port the web hyperbrain knowledge layer (`killerFeatures`, `whatFor`, `advantages`, `weaknesses`, `whoUses`, `pricing{model,summary}`) into a single canonical artifact consumed by BOTH lanes:

- **Web** keeps `src/playground/knowledge.data.ts` as the authored source of truth and gains a generator that emits a canonical `knowledge.json`.
- **iOS** gets a `Knowledge` Swift struct, a bundled `Resources/knowledge.json` (byte-identical to the web emit), a decoder (`KnowledgeStore`), and integrity tests proving the 49 enriched records line up 1:1 with the 49 seed tool ids.

No behavior in the web app changes (the data is identical, just re-exported); iOS gains a knowledge layer where it currently has none.

## Architecture

This mirrors the EXISTING seed pattern exactly. `src/data/ai-tool-universe.seed.json` and `ios-app/Sources/MyAIMap/Resources/ai-tool-universe.seed.json` are kept **byte-identical** (verified: `diff -q` reports IDENTICAL). We extend that contract to knowledge:

```
src/playground/knowledge.data.ts   (authored source — ENRICHED_DATA, 49 entries)
        │  scripts/gen-knowledge-json.mjs  (deterministic emit, sorted keys)
        ▼
src/data/knowledge.json            (canonical artifact, committed)
        │  copied verbatim (the gen script writes both paths)
        ▼
ios-app/Sources/MyAIMap/Resources/knowledge.json
        │  KnowledgeStore.swift decodes once, lazily, from app bundle
        ▼
Knowledge struct  ──►  consumed by iOS chat / detail (later parts)
```

Web's `knowledge.ts` (`knowledgeFor`, `searchableText`, `ENRICHED`) is untouched — it still reads `ENRICHED_DATA` directly. The emitted `knowledge.json` is the **cross-lane transport**: web authors it in TS, the generator serializes it, iOS decodes the same bytes. A web test asserts the committed JSON matches the TS source (no manual drift); a copy-equality test asserts the two JSON files are identical (same guarantee the seed enjoys today, enforced in `scripts/ios-verify.sh`).

Swift shapes mirror `ToolKnowledge` minus the runtime-only `enriched` flag (every record in the JSON is, by definition, enriched). `PricingModel` becomes a Swift enum matching the web union exactly.

## Tech Stack

- **Web source / generator**: TypeScript (`knowledge.data.ts`), Node ESM script (`.mjs`, matches existing `scripts/check-bundle-size.mjs`), Vitest (`npm run test`, matches `query.test.ts`).
- **iOS**: Swift 6 (strict concurrency `complete`), `Codable`/`Decodable`, `Bundle(for:)` resource loading (matches `UniverseSeed.swift`), Swift Testing (`import Testing`, `@Test`/`#expect`, matches `SeedIntegrityTests.swift`), XcodeGen (`ios-app/project.yml`).
- No new dependencies. iOS resources are auto-copied because `Sources/MyAIMap` is a target source root (same mechanism that bundles `ai-tool-universe.seed.json`).

---

## Task 1 — Web: deterministic knowledge.json generator + drift guard

Adds a script that serializes `ENRICHED_DATA` to a canonical, key-sorted JSON and writes it to both the web `src/data/` location and the iOS Resources folder. A Vitest test guarantees the committed JSON never drifts from the TS source.

### Files
- **Create** `/tmp/wt-ios/scripts/gen-knowledge-json.mjs`
- **Create** `/tmp/wt-ios/src/data/knowledge.test.ts`
- **Create** `/tmp/wt-ios/src/data/knowledge.json` (emitted by the script)
- **Modify** `/tmp/wt-ios/package.json` (add `gen:knowledge` script)

### Steps

1. **Write the failing test** `/tmp/wt-ios/src/data/knowledge.test.ts`. It imports the authored TS source and the committed JSON and asserts they match, plus structural invariants. This fails first because `knowledge.json` does not exist yet.

```ts
import { describe, expect, it } from 'vitest';
import { ENRICHED_DATA } from '../playground/knowledge.data';
import { tools } from './ai-tool-universe';
import knowledgeJson from './knowledge.json';

const PRICING_MODELS = new Set([
  'free', 'open-source', 'freemium', 'subscription',
  'usage-based', 'enterprise', 'mixed', 'unknown',
]);

describe('knowledge.json', () => {
  it('is byte-equal to the canonical emit of ENRICHED_DATA', () => {
    // Same sort + serialization the generator uses. Drift fails here.
    const sorted = Object.fromEntries(
      Object.keys(ENRICHED_DATA).sort().map((k) => [k, ENRICHED_DATA[k]]),
    );
    const expected = JSON.parse(JSON.stringify(sorted));
    expect(knowledgeJson).toEqual(expected);
  });

  it('has exactly one record per seed tool id', () => {
    const seedIds = new Set(tools.map((t) => t.id));
    const knowledgeIds = new Set(Object.keys(knowledgeJson));
    expect(knowledgeIds.size).toBe(seedIds.size);
    for (const id of seedIds) {
      expect(knowledgeIds.has(id), `missing knowledge for ${id}`).toBe(true);
    }
    for (const id of knowledgeIds) {
      expect(seedIds.has(id), `orphan knowledge for ${id}`).toBe(true);
    }
  });

  it('every record is structurally complete', () => {
    for (const [id, k] of Object.entries(knowledgeJson)) {
      expect(Array.isArray(k.killerFeatures), `${id}.killerFeatures`).toBe(true);
      expect(typeof k.whatFor === 'string' && k.whatFor.length > 0, `${id}.whatFor`).toBe(true);
      expect(Array.isArray(k.advantages), `${id}.advantages`).toBe(true);
      expect(Array.isArray(k.weaknesses), `${id}.weaknesses`).toBe(true);
      expect(typeof k.whoUses === 'string', `${id}.whoUses`).toBe(true);
      expect(PRICING_MODELS.has(k.pricing.model), `${id}.pricing.model`).toBe(true);
      expect(typeof k.pricing.summary === 'string' && k.pricing.summary.length > 0, `${id}.pricing.summary`).toBe(true);
    }
  });
});
```

2. **Run** `npm run test -- src/data/knowledge.test.ts` → fails (cannot resolve `./knowledge.json`). Confirm the failure is the missing file.

3. **Write the generator** `/tmp/wt-ios/scripts/gen-knowledge-json.mjs`. It imports the TS source via a tiny inline transpile-free path: it reads the data by spawning `tsx`-free — instead, because `ENRICHED_DATA` is a plain object literal, the script imports it through Vite's loader is overkill; use `esbuild`-free approach by reading from a built artifact is also overkill. Simplest robust approach: load the TS with the already-present TypeScript via a dynamic `tsc`-emitted temp is heavy. Use the pragmatic path that matches this repo: run the emit **inside** a tiny Vitest-independent Node loader using `--import tsx` is unavailable. Therefore generate by re-exporting through a `.mjs` that imports the JSON the test compares — circular. To avoid all that, the generator parses the object from the test's own import surface by invoking `vite-node`.

   Pragmatic decision (matches repo, no new deps): the generator shells out to the project's existing TS toolchain by writing a one-off ESM entry that Vite can load. Concretely:

```js
// scripts/gen-knowledge-json.mjs
// Emits the canonical knowledge.json from the authored TS source
// (src/playground/knowledge.data.ts) to BOTH the web data dir and the
// iOS Resources dir, byte-identically. Run: npm run gen:knowledge
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { createServer } from 'vite';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

const server = await createServer({ root, server: { middlewareMode: true }, appType: 'custom' });
try {
  const mod = await server.ssrLoadModule('/src/playground/knowledge.data.ts');
  const data = mod.ENRICHED_DATA;

  // Canonical form: keys sorted, 2-space indent, trailing newline.
  const sorted = Object.fromEntries(Object.keys(data).sort().map((k) => [k, data[k]]));
  const json = JSON.stringify(sorted, null, 2) + '\n';

  const targets = [
    resolve(root, 'src/data/knowledge.json'),
    resolve(root, 'ios-app/Sources/MyAIMap/Resources/knowledge.json'),
  ];
  for (const t of targets) {
    writeFileSync(t, json, 'utf8');
    console.log('wrote', t);
  }
} finally {
  await server.close();
}
```

   `vite` is already a dependency (root `package.json` uses `vite`), so `createServer().ssrLoadModule` transpiles the TS with no new tooling.

4. **Add the npm script** in `/tmp/wt-ios/package.json` under `scripts`:

```json
    "gen:knowledge": "node scripts/gen-knowledge-json.mjs",
```

5. **Run** `npm run gen:knowledge` → writes `src/data/knowledge.json` and `ios-app/Sources/MyAIMap/Resources/knowledge.json`.

6. **Run** `npm run test -- src/data/knowledge.test.ts` → passes. Then **run** `npm run typecheck` to confirm the JSON import typechecks (add `"resolveJsonModule": true` already implied by the existing seed JSON import in `ai-tool-universe.ts` — verify it builds; no tsconfig change expected).

7. **Verify identity** with `diff -q src/data/knowledge.json ios-app/Sources/MyAIMap/Resources/knowledge.json` → must report identical.

8. **Commit**: `git add scripts/gen-knowledge-json.mjs src/data/knowledge.json src/data/knowledge.test.ts ios-app/Sources/MyAIMap/Resources/knowledge.json package.json && git commit` with message `P0: emit canonical knowledge.json from web source, consumed by both lanes`.

---

## Task 2 — iOS: Knowledge struct + KnowledgeStore decoder

Adds the Swift model and a lazy decoder that loads the bundled `knowledge.json`, mirroring `UniverseSeed.swift` exactly.

### Files
- **Create** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/Knowledge.swift`
- **Create** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/KnowledgeStore.swift`
- **Create** `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/KnowledgeIntegrityTests.swift`

### Steps

1. **Write the failing test** `/tmp/wt-ios/ios-app/Tests/MyAIMapTests/KnowledgeIntegrityTests.swift`. Mirrors `SeedIntegrityTests` style (`import Testing`, `@Test`, `#expect`). Fails to compile first because `KnowledgeStore` / `Knowledge` don't exist.

```swift
import Foundation
import Testing
@testable import MyAIMap

/// Guards the bundled `knowledge.json` against drift from the canonical web
/// emit. Like `UniverseSeed`, `KnowledgeStore` decodes lazily on first access,
/// so a decode failure surfaces here with a clear message.
struct KnowledgeIntegrityTests {
    @Test func decodesOneRecordPerSeedTool() {
        let knowledgeIDs = Set(KnowledgeStore.all.keys)
        let seedIDs = Set(UniverseSeed.tools.map(\.id))
        #expect(knowledgeIDs.count == 49)
        #expect(knowledgeIDs == seedIDs, "knowledge ids must match the 49 seed tool ids exactly")
    }

    @Test func everyRecordIsStructurallyComplete() {
        for (id, k) in KnowledgeStore.all {
            #expect(!k.whatFor.isEmpty, "\(id) has empty whatFor")
            #expect(!k.pricing.summary.isEmpty, "\(id) has empty pricing summary")
        }
    }

    @Test func knowledgeForResolvesAndMissesGracefully() {
        #expect(KnowledgeStore.knowledge(for: "founder-os") != nil)
        #expect(KnowledgeStore.knowledge(for: "does-not-exist") == nil)
    }

    @Test func pricingModelDecodesForEveryRecord() {
        // Decoding already happened in `all`; this asserts no record fell back
        // to an unknown raw value (the enum is non-optional, so a bad value
        // would have thrown during decode and crashed the lazy initializer).
        #expect(KnowledgeStore.all.values.allSatisfy { PricingModel.allCases.contains($0.pricing.model) })
    }
}
```

2. **Run** the test build: `npm run ios:test-build` → fails to compile (unknown `KnowledgeStore` / `Knowledge` / `PricingModel`). Confirm that is the failure.

3. **Write the model** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/Knowledge.swift`. Mirrors the web `ToolKnowledge`/`ToolPricing`/`PricingModel` shapes (without the runtime `enriched` flag — every JSON record is enriched).

```swift
import Foundation

/// Pricing model, mirroring the web app's `PricingModel` union
/// (`src/playground/knowledge.ts`). `CaseIterable` so integrity tests can
/// assert the decoded value is one of the known cases.
enum PricingModel: String, CaseIterable, Codable, Sendable {
    case free
    case openSource = "open-source"
    case freemium
    case subscription
    case usageBased = "usage-based"
    case enterprise
    case mixed
    case unknown
}

/// Pricing facts for one tool. Mirror of the web `ToolPricing`.
struct ToolPricing: Codable, Sendable {
    let model: PricingModel
    let summary: String
}

/// Rich, web-researched knowledge for one tool. Direct mirror of the web
/// app's `ToolKnowledge` (`src/playground/knowledge.ts`) minus the runtime
/// `enriched` flag — every record bundled in `knowledge.json` is enriched by
/// definition. Decoded from `Resources/knowledge.json`, which is emitted
/// byte-identically from `src/playground/knowledge.data.ts`.
struct Knowledge: Codable, Sendable {
    let killerFeatures: [String]
    let whatFor: String
    let advantages: [String]
    let weaknesses: [String]
    let whoUses: String
    let pricing: ToolPricing
}
```

4. **Write the decoder** `/tmp/wt-ios/ios-app/Sources/MyAIMap/Data/KnowledgeStore.swift`. Copy the `UniverseSeed` bundle-resolution pattern verbatim (same `BundleToken`, same lazy decode, same `fatalError` invariants).

```swift
import Foundation

/// Tool knowledge, decoded once from the bundled canonical `knowledge.json`.
///
/// The JSON is emitted byte-identically from the web source of truth
/// (`src/playground/knowledge.data.ts`) by `scripts/gen-knowledge-json.mjs`,
/// then copied into `Sources/MyAIMap/Resources/`. This makes drift between the
/// two ports impossible — there is a single authored source and a committed
/// artifact shared by both lanes (the same contract as `ai-tool-universe.seed.json`).
enum KnowledgeStore {
    /// See `UniverseSeed.BundleToken` — resolves the app bundle for both the
    /// XcodeGen app target and the host-app unit test bundle.
    private final class BundleToken {}

    /// Keyed by tool id, matching `UniverseSeed.tools[*].id`.
    static let all: [String: Knowledge] = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "knowledge", withExtension: "json") else {
            fatalError("Missing bundled resource knowledge.json — build-time invariant (XcodeGen copies it from Sources/MyAIMap/Resources; run `npm run gen:knowledge` to regenerate).")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Knowledge].self, from: data)
        } catch {
            fatalError("Failed to decode knowledge.json: \(error)")
        }
    }()

    /// Best available knowledge for a tool id, or `nil` if none is bundled.
    static func knowledge(for id: String) -> Knowledge? {
        all[id]
    }
}
```

5. **Run** `npm run ios:test-build` → compiles. Then run the full simulator test pass per the repo's workflow: `npm run ios:verify` (or `bash scripts/ios-verify.sh --full-test --device-id <sim-id>` if a sim id is required) → `KnowledgeIntegrityTests` passes (49/49 ids match, all records complete).

6. **Commit**: `git add ios-app/Sources/MyAIMap/Data/Knowledge.swift ios-app/Sources/MyAIMap/Data/KnowledgeStore.swift ios-app/Tests/MyAIMapTests/KnowledgeIntegrityTests.swift && git commit` with message `P0: iOS Knowledge struct + KnowledgeStore decoding bundled knowledge.json`.

---

## Task 3 — Wire the copy-equality guard into ios-verify

Guarantees the iOS `knowledge.json` can never silently diverge from the web emit, exactly as the seed JSON is already protected by `diff` in CI/verify.

### Files
- **Modify** `/tmp/wt-ios/scripts/ios-verify.sh`

### Steps

1. **Inspect** `scripts/ios-verify.sh` to find where the seed JSON identity is asserted (search for `ai-tool-universe.seed.json`). If a `diff -q` guard for the seed already exists, add the knowledge equivalent right beside it; if none exists, add a guard block near the top (after arg parsing, before `xcodebuild`).

2. **Add** the guard (real block — adjust the surrounding style to match the existing script):

```sh
# Knowledge JSON must stay byte-identical across lanes (P0 contract).
# It is emitted from src/playground/knowledge.data.ts via `npm run gen:knowledge`.
if ! diff -q "$ROOT_DIR/src/data/knowledge.json" \
             "$ROOT_DIR/ios-app/Sources/MyAIMap/Resources/knowledge.json" >/dev/null; then
  echo "knowledge.json drift: run 'npm run gen:knowledge' and commit both copies." >&2
  exit 1
fi
```

3. **Run** `bash scripts/ios-verify.sh --build-only` → guard passes (files are identical from Task 1). Then temporarily edit one byte of the iOS copy and re-run to confirm the guard fails, then restore via `npm run gen:knowledge`.

4. **Commit**: `git add scripts/ios-verify.sh && git commit` with message `P0: guard knowledge.json byte-equality in ios-verify`.

---

## Done criteria

- `npm run test -- src/data/knowledge.test.ts` green (JSON matches TS source, 49 ids, complete records).
- `npm run ios:verify` green (`KnowledgeIntegrityTests` passes, drift guard passes).
- `diff -q src/data/knowledge.json ios-app/Sources/MyAIMap/Resources/knowledge.json` → identical.
- `npm run gen:knowledge` is the single regeneration entry point; editing `knowledge.data.ts` then running it updates both lanes.
