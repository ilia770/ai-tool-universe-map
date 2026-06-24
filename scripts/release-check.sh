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
run_step "production dependency audit" npm audit --omit=dev --audit-level=high
run_step "production build" npm run build
run_step "bundle size budget" npm run size:check

if [[ "${SKIP_IOS_RELEASE_CHECK:-}" == "1" ]]; then
  echo "== iOS test build skipped by SKIP_IOS_RELEASE_CHECK=1 =="
elif [[ -d "$ROOT_DIR/ios-app" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "iOS release check requires macOS. Set SKIP_IOS_RELEASE_CHECK=1 only for non-iOS release contexts." >&2
    exit 1
  fi
  run_step "iOS test build" bash scripts/ios-verify.sh --test-build-only
fi

echo "== release check complete =="
