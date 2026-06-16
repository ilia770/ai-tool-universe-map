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

const server = await createServer({
  root,
  logLevel: 'silent',
  server: { middlewareMode: true },
  appType: 'custom',
  optimizeDeps: { noDiscovery: true, include: [] },
});
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
