#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ios-app/MyAIMap.xcodeproj"
SCHEME="MyAIMap"
DERIVED_DATA="$ROOT_DIR/ios-app/build"
GENERIC_DESTINATION="generic/platform=iOS Simulator"

mode="verify"
device_id=""

usage() {
  cat <<'USAGE'
Usage: bash scripts/ios-verify.sh [--build-only|--test-build-only|--full-test --device-id <sim-id>]

Default:
  Runs generic simulator build + build-for-testing. This validates Swift compile,
  app target, and test target without booting a simulator.

Options:
  --build-only        Run app build only.
  --test-build-only   Run build-for-testing only.
  --full-test         Run build-for-testing, then test-without-building on a booted simulator id.
  --device-id <id>    Simulator UDID for --full-test.
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only)
      mode="build"
      shift
      ;;
    --test-build-only)
      mode="test-build"
      shift
      ;;
    --full-test)
      mode="full-test"
      shift
      ;;
    --device-id)
      device_id="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

# Knowledge JSON must stay byte-identical across lanes (P0 contract).
# It is emitted from src/playground/knowledge.data.ts via `npm run gen:knowledge`.
if ! diff -q "$ROOT_DIR/src/data/knowledge.json" \
             "$ROOT_DIR/ios-app/Sources/MyAIMap/Resources/knowledge.json" >/dev/null; then
  echo "knowledge.json drift: run 'npm run gen:knowledge' and commit both copies." >&2
  exit 1
fi

echo "== Xcode =="
xcodebuild -version

if command -v xcodegen >/dev/null 2>&1; then
  echo "== XcodeGen =="
  (cd "$ROOT_DIR/ios-app" && xcodegen generate)
else
  echo "xcodegen not found; using existing MyAIMap.xcodeproj." >&2
  echo "Install with: brew install xcodegen" >&2
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing Xcode project at $PROJECT_PATH" >&2
  echo "Run: cd ios-app && xcodegen generate" >&2
  exit 1
fi

run_build() {
  echo "== iOS app build =="
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "$GENERIC_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    ENABLE_DEBUG_DYLIB=NO \
    build
}

run_test_build() {
  echo "== iOS build-for-testing =="
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "$GENERIC_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    ENABLE_DEBUG_DYLIB=NO \
    build-for-testing
}

run_full_test() {
  if [[ -z "$device_id" ]]; then
    echo "--full-test requires --device-id <sim-id>." >&2
    echo "Find one with: xcrun simctl list devices available" >&2
    exit 2
  fi

  run_test_build

  echo "== iOS test-without-building on $device_id =="
  xcrun simctl boot "$device_id" 2>/dev/null || true
  xcrun simctl bootstatus "$device_id" -b
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$DERIVED_DATA" \
    ENABLE_DEBUG_DYLIB=NO \
    test-without-building
}

case "$mode" in
  build)
    run_build
    ;;
  test-build)
    run_test_build
    ;;
  verify)
    run_build
    run_test_build
    ;;
  full-test)
    run_full_test
    ;;
esac

echo "== iOS verify complete =="
