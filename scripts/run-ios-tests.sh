#!/usr/bin/env bash
# =============================================================================
# FIN1 — iOS Unit Tests (xcodebuild)
#
# Used by .github/workflows/ci.yml (every PR). Tune via env vars on self-hosted or
# scheduled jobs (see .github/workflows/ios-extended-tests.yml).
#
# Env (optional):
#   IOS_TEST_DESTINATION   preferred simulator (resolved via scripts/resolve-ios-sim-destination.sh)
#   IOS_TEST_SCHEME        default: FIN1
#   IOS_TEST_CONFIGURATION default: Debug
#   IOS_TEST_TARGETS       comma-separated -only-testing targets, default: FIN1Tests
#                          e.g. FIN1Tests,FIN1InvestorTests,FIN1CoreRegressionTests
#   IOS_INCLUDE_UI_TESTS   set to 1 to append FIN1UITests (slow / flaky — weekly only)
#
# Best practice:
#   PR:   FIN1Tests only (fast signal).
#   main / weekly: add FIN1InvestorTests + FIN1CoreRegressionTests; UITests optional.
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="FIN1.xcodeproj"
SCHEME="${IOS_TEST_SCHEME:-FIN1}"
CONFIG="${IOS_TEST_CONFIGURATION:-Debug}"
TARGETS="${IOS_TEST_TARGETS:-FIN1Tests}"

chmod +x scripts/resolve-ios-sim-destination.sh
DEST="$(./scripts/resolve-ios-sim-destination.sh)"

boot_simulator_for_destination() {
  local dest="$1"
  local udid name os
  udid="$(printf '%s' "$dest" | sed -n 's/.*id=\([^,}]*\).*/\1/p' | head -1)"
  udid="${udid#"${udid%%[![:space:]]*}"}"
  udid="${udid%"${udid##*[![:space:]]}"}"
  if [[ -z "$udid" ]]; then
    name="$(printf '%s' "$dest" | sed -n 's/.*name=\([^,]*\).*/\1/p')"
    os="$(printf '%s' "$dest" | sed -n 's/.*OS=\([^,]*\).*/\1/p')"
    if [[ -n "$name" && -n "$os" ]]; then
      udid="$(xcrun simctl list devices "$os" available 2>/dev/null \
        | grep -F "${name} (" \
        | head -1 \
        | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')"
    fi
  fi
  if [[ -n "$udid" ]]; then
    echo "  booting simulator: $udid"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b 2>/dev/null || sleep 5
  fi
}

boot_simulator_for_destination "$DEST"

ONLY_ARGS=()
IFS=',' read -ra _TARGET_PARTS <<< "$TARGETS"
for raw in "${_TARGET_PARTS[@]}"; do
  t="$(echo "$raw" | xargs)"
  if [[ -n "$t" ]]; then
    ONLY_ARGS+=( -only-testing:"$t" )
  fi
done

if [[ "${IOS_INCLUDE_UI_TESTS:-0}" == "1" ]]; then
  ONLY_ARGS+=( -only-testing:FIN1UITests )
fi

if [[ ${#ONLY_ARGS[@]} -eq 0 ]]; then
  echo "No test targets resolved from IOS_TEST_TARGETS='$TARGETS'" >&2
  exit 1
fi

echo "=== iOS tests ==="
echo "  scheme:        $SCHEME"
echo "  configuration: $CONFIG"
echo "  destination:   $DEST"
echo "  only-testing:  ${ONLY_ARGS[*]}"
echo ""

set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  -parallel-testing-enabled NO \
  "${ONLY_ARGS[@]}"
test_rc=$?
set -e

if [[ "$test_rc" -ne 0 ]]; then
  echo "xcodebuild test failed (exit $test_rc). Recent simulator destinations:" >&2
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>&1 \
    | grep 'platform:iOS Simulator' \
    | grep -v placeholder \
    | head -15 >&2 || true
  exit "$test_rc"
fi
