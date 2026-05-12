#!/usr/bin/env bash
# =============================================================================
# FIN1 — iOS Unit Tests (xcodebuild)
#
# Used by .github/workflows/ci.yml (every PR). Tune via env vars on self-hosted or
# scheduled jobs (see .github/workflows/ios-extended-tests.yml).
#
# Env (optional):
#   IOS_TEST_DESTINATION   default: platform=iOS Simulator,name=iPhone 16,OS=18.6
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
DEST="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.6}"
TARGETS="${IOS_TEST_TARGETS:-FIN1Tests}"

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

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  "${ONLY_ARGS[@]}"
