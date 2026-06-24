#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ios-app/MyAIMap.xcodeproj"
SCHEME="MyAIMap"
DERIVED_DATA="$ROOT_DIR/ios-app/build"
GENERIC_DESTINATION="generic/platform=iOS Simulator"
UNIT_TEST_BUNDLE="MyAIMapTests"
UI_TEST_TARGET="MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates"
RESULT_BUNDLE="$DERIVED_DATA/MyAIMapTests.xcresult"
UI_RESULT_BUNDLE="$DERIVED_DATA/MyAIMapUITests.xcresult"

mode="verify"
device_id=""
use_existing_project=0

usage() {
  cat <<'USAGE'
Usage: bash scripts/ios-verify.sh [--build-only|--test-build-only|--run-tests|--run-ui-tests|--full-test] [--device-id <sim-id>] [--use-existing-project]

Default:
  Runs generic simulator build + build-for-testing. This validates Swift compile,
  app target, and test target without booting a simulator.

Options:
  --build-only        Run app build only.
  --test-build-only   Run build-for-testing only (fast compile gate, no assertions).
  --run-tests | test  Run `xcodebuild test -only-testing:MyAIMapTests` on a booted
                      simulator id, writing an xcresult bundle. Executes assertions.
  --run-ui-tests      Run the deterministic XCUITest smoke harness on a booted
                      simulator id, writing an xcresult bundle with screenshots.
  --full-test         Run build-for-testing, then test-without-building on a booted simulator id.
  --device-id <id>    Simulator UDID for --run-tests / --full-test.
  --use-existing-project
                      Allow an existing generated .xcodeproj when xcodegen is
                      not installed. Intended only for emergency local checks.
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
    --run-tests|test)
      mode="run-tests"
      shift
      ;;
    --run-ui-tests)
      mode="run-ui-tests"
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
    --use-existing-project)
      use_existing_project=1
      shift
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

echo "== Xcode =="
xcodebuild -version

if command -v xcodegen >/dev/null 2>&1; then
  echo "== XcodeGen =="
  (cd "$ROOT_DIR/ios-app" && xcodegen generate)
else
  if [[ "$use_existing_project" != "1" ]]; then
    echo "xcodegen not found; refusing to use a potentially stale MyAIMap.xcodeproj." >&2
    echo "Install with: brew install xcodegen" >&2
    echo "Temporary escape hatch: pass --use-existing-project." >&2
    exit 1
  fi
  echo "xcodegen not found; using existing MyAIMap.xcodeproj by explicit request." >&2
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

run_tests() {
  if [[ -z "$device_id" ]]; then
    echo "--run-tests requires --device-id <sim-id>." >&2
    echo "Find one with: xcrun simctl list devices available" >&2
    exit 2
  fi

  echo "== iOS unit tests ($UNIT_TEST_BUNDLE) on $device_id =="
  xcrun simctl boot "$device_id" 2>/dev/null || true
  xcrun simctl bootstatus "$device_id" -b
  rm -rf "$RESULT_BUNDLE"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$DERIVED_DATA" \
    -resultBundlePath "$RESULT_BUNDLE" \
    -only-testing:"$UNIT_TEST_BUNDLE" \
    ENABLE_DEBUG_DYLIB=NO \
    test
  echo "== xcresult bundle: $RESULT_BUNDLE =="
}

run_ui_tests() {
  if [[ -z "$device_id" ]]; then
    echo "--run-ui-tests requires --device-id <sim-id>." >&2
    echo "Find one with: xcrun simctl list devices available" >&2
    exit 2
  fi

  echo "== iOS UI smoke tests ($UI_TEST_TARGET) on $device_id =="
  xcrun simctl boot "$device_id" 2>/dev/null || true
  xcrun simctl bootstatus "$device_id" -b
  rm -rf "$UI_RESULT_BUNDLE"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$DERIVED_DATA" \
    -resultBundlePath "$UI_RESULT_BUNDLE" \
    -only-testing:"$UI_TEST_TARGET" \
    ENABLE_DEBUG_DYLIB=NO \
    test
  echo "== xcresult bundle: $UI_RESULT_BUNDLE =="
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
  run-tests)
    run_tests
    ;;
  run-ui-tests)
    run_ui_tests
    ;;
  full-test)
    run_full_test
    ;;
esac

echo "== iOS verify complete =="
