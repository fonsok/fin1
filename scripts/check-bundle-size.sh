#!/usr/bin/env bash

# Bundle Size Check Script
# Checks iOS app bundle size and warns if it exceeds thresholds
# Usage: ./scripts/check-bundle-size.sh [configuration]
#
# Uses -derivedDataPath ./build so the .app path is deterministic (CI + local);
# without it, Xcode writes to ~/Library/Developer/DerivedData and find ./build fails.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-Release}"
SCHEME="FIN1"
PROJECT="FIN1.xcodeproj"
# Generic simulator: compile-only size check; avoids runner-specific OS= pins.
DESTINATION="${IOS_BUNDLE_SIZE_DESTINATION:-generic/platform=iOS Simulator}"
DERIVED_DATA="${ROOT}/build"

# Size thresholds (in MB) — Release .app on simulator (debug dylibs etc.) trends ~100MB+;
# ERROR is a guardrail below OTA concern; raise intentionally when product grows.
WARNING_THRESHOLD=50
ERROR_THRESHOLD=120
CRITICAL_THRESHOLD=180  # Near App Store OTA-style concern (200MB ceiling context)

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "📦 Checking bundle size for configuration: $CONFIGURATION"
echo ""

echo "🔨 Building app (DerivedData: ${DERIVED_DATA})..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    build

PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphonesimulator"
APP_PATH=""
if [[ -d "$PRODUCTS_DIR" ]]; then
    APP_PATH=$(find "$PRODUCTS_DIR" -maxdepth 1 -name "*.app" -type d | head -1)
fi

if [[ -z "$APP_PATH" ]]; then
    echo "❌ Error: Could not find built .app under ${PRODUCTS_DIR}" >&2
    exit 1
fi

# Use KiB (du -sk) for thresholds — du -sm rounds up and false-fails at the boundary
# (e.g. 119 MiB actual → du -sm reports 120MB while 121892 KiB < 122880 KiB limit).
BUNDLE_SIZE_KB=$(du -sk "$APP_PATH" | cut -f1)
BUNDLE_SIZE_BYTES=$((BUNDLE_SIZE_KB * 1024))
BUNDLE_SIZE_MB_DISPLAY=$(awk "BEGIN { printf \"%.1f\", ${BUNDLE_SIZE_KB} / 1024 }")
WARNING_THRESHOLD_KB=$((WARNING_THRESHOLD * 1024))
ERROR_THRESHOLD_KB=$((ERROR_THRESHOLD * 1024))
CRITICAL_THRESHOLD_KB=$((CRITICAL_THRESHOLD * 1024))

echo "📊 Bundle Size Analysis"
echo "----------------------------------------------------------------"
echo "   Size: ${BUNDLE_SIZE_MB_DISPLAY}MB (${BUNDLE_SIZE_BYTES} bytes, ${BUNDLE_SIZE_KB} KiB)"
echo "   Path: $APP_PATH"
echo ""

# Check thresholds
if [ "$BUNDLE_SIZE_KB" -ge "$CRITICAL_THRESHOLD_KB" ]; then
    echo -e "${RED}❌ CRITICAL: Bundle size exceeds ${CRITICAL_THRESHOLD}MB!${NC}"
    echo "   ⚠️  App Store over-the-air download limit is 200MB"
    echo "   ⚠️  Users will need WiFi to download"
    exit 1
elif [ "$BUNDLE_SIZE_KB" -ge "$ERROR_THRESHOLD_KB" ]; then
    echo -e "${RED}❌ ERROR: Bundle size exceeds ${ERROR_THRESHOLD}MB${NC}"
    echo "   ⚠️  Consider optimizing assets or removing unused dependencies"
    exit 1
elif [ "$BUNDLE_SIZE_KB" -ge "$WARNING_THRESHOLD_KB" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Bundle size exceeds ${WARNING_THRESHOLD}MB${NC}"
    echo "   💡 Monitor bundle size growth"
    exit 0
else
    echo -e "${GREEN}✅ Bundle size is acceptable (${BUNDLE_SIZE_MB_DISPLAY}MB < ${WARNING_THRESHOLD}MB)${NC}"
    exit 0
fi
