#!/usr/bin/env bash
# Static analyzer for one scheme + configuration (simulator).
# Usage: ./scripts/analyze-ios-config.sh <scheme> <configuration>
# Example: ./scripts/analyze-ios-config.sh FIN1 Release
#
# Optional: IOS_BUILD_DESTINATION (default: platform=iOS Simulator,name=iPhone 16,OS=18.6)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="${1:?usage: $0 <scheme> <configuration>}"
CONFIG="${2:?usage: $0 <scheme> <configuration>}"
PROJECT="FIN1.xcodeproj"
DEST="${IOS_BUILD_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.6}"

echo "=== xcodebuild analyze === scheme=$SCHEME configuration=$CONFIG destination=$DEST"

xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  analyze
