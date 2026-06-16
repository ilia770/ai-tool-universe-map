#!/usr/bin/env node
/**
 * Bundle size guardrail.
 *
 * Reads the built dist/assets/*.js files, matches each against the
 * BUDGETS table by filename prefix, and fails if either the raw or
 * gzipped size exceeds the threshold.
 *
 * Thresholds track the current multi-entry production build
 * (main app + playground lab) with enough headroom for small UI drift,
 * while still catching accidental vendor rebundling.
 *
 * Run locally after `npm run build`:
 *   node scripts/check-bundle-size.mjs
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { join } from 'node:path';

/** @type {Array<{prefix: string, maxRawKb: number, maxGzipKb: number}>} */
const BUDGETS = [
  { prefix: 'main-',              maxRawKb: 85,  maxGzipKb: 25 },
  { prefix: 'playground-',        maxRawKb: 360, maxGzipKb: 115 },
  { prefix: 'AIToolUniverse3D-',  maxRawKb: 35,  maxGzipKb: 12 },
  { prefix: 'three-r3f-',         maxRawKb: 650, maxGzipKb: 205 },
  { prefix: 'three-core-',        maxRawKb: 800, maxGzipKb: 205 },
];

const ASSETS_DIR = join(process.cwd(), 'dist', 'assets');

let files;
try {
  files = readdirSync(ASSETS_DIR).filter((name) => name.endsWith('.js'));
} catch (err) {
  console.error(`Cannot read ${ASSETS_DIR}. Did you forget to run \`npm run build\`?`);
  console.error(err.message);
  process.exit(2);
}

let failed = false;
const rows = [];

for (const budget of BUDGETS) {
  const match = files.find((name) => name.startsWith(budget.prefix));
  if (!match) {
    console.error(`✖ No build artifact matches prefix "${budget.prefix}" in ${ASSETS_DIR}.`);
    failed = true;
    continue;
  }

  const fullPath = join(ASSETS_DIR, match);
  const rawBytes = statSync(fullPath).size;
  const gzipBytes = gzipSync(readFileSync(fullPath), { level: 9 }).length;
  const rawKb = rawBytes / 1024;
  const gzipKb = gzipBytes / 1024;

  const overRaw = rawKb > budget.maxRawKb;
  const overGzip = gzipKb > budget.maxGzipKb;
  const ok = !overRaw && !overGzip;
  if (!ok) failed = true;

  rows.push({
    file: match,
    raw: rawKb.toFixed(1),
    rawLimit: budget.maxRawKb,
    gz: gzipKb.toFixed(1),
    gzLimit: budget.maxGzipKb,
    status: ok ? 'OK' : `OVER${overRaw ? ' raw' : ''}${overGzip ? ' gzip' : ''}`,
  });
}

const header = ['file', 'raw kB', 'raw limit', 'gz kB', 'gz limit', 'status'];
const widths = header.map((h, i) => Math.max(h.length, ...rows.map((r) => String(Object.values(r)[i]).length)));
const pad = (val, i) => String(val).padEnd(widths[i]);
console.log(header.map(pad).join('  '));
console.log(widths.map((w) => '-'.repeat(w)).join('  '));
for (const r of rows) {
  console.log(Object.values(r).map(pad).join('  '));
}

if (failed) {
  console.error('\nBundle size budget exceeded. Either ship the regression intentionally and bump the thresholds in scripts/check-bundle-size.mjs, or simplify the change.');
  process.exit(1);
}

console.log('\nAll chunks within budget.');
