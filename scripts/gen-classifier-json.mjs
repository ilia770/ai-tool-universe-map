// scripts/gen-classifier-json.mjs
// Emits the canonical classifier-taxonomy.json from the authored TS source
// (src/data/classifier-taxonomy.ts) to BOTH the web data dir and the iOS
// Resources dir, byte-identically. Run: npm run gen:classifier
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { createServer } from 'vite';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

const server = await createServer({
  root,
  logLevel: 'silent',
  server: { middlewareMode: true },
  appType: 'custom',
  optimizeDeps: { noDiscovery: true, include: [] },
});
try {
  const mod = await server.ssrLoadModule('/src/data/classifier-taxonomy.ts');
  const payload = {
    version: 1,
    categoryRules: mod.CATEGORY_RULES,
    domainRules: mod.DOMAIN_RULES,
    ambiguous: mod.AMBIGUOUS,
    giant: mod.GIANT,
  };

  // Canonical form: top-level keys sorted, 2-space indent, trailing newline.
  const sorted = Object.fromEntries(Object.keys(payload).sort().map((k) => [k, payload[k]]));
  const json = JSON.stringify(sorted, null, 2) + '\n';

  const targets = [
    resolve(root, 'src/data/classifier-taxonomy.json'),
    resolve(root, 'ios-app/Sources/MyAIMap/Resources/classifier-taxonomy.json'),
  ];
  for (const t of targets) {
    writeFileSync(t, json, 'utf8');
    console.log('wrote', t);
  }
} finally {
  await server.close();
}
