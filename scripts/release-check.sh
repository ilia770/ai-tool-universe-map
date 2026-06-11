#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_step() {
  local label="$1"
  shift
  echo "== $label =="
  "$@"
}

run_step "typecheck" npm run typecheck
run_step "lint" npm run lint
run_step "unit tests" npm test -- --run
run_step "production build" npm run build
run_step "bundle size budget" npm run size:check

echo "== release check complete =="
