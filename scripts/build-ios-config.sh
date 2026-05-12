#!/usr/bin/env bash
# Build one scheme + configuration for the iOS Simulator (CI / local).
# Usage: ./scripts/build-ios-config.sh <scheme> <configuration>
# Example: ./scripts/build-ios-config.sh FIN1 Release
#
# Optional: IOS_BUILD_DESTINATION (default: platform=iOS Simulator,name=iPhone 16,OS=18.6)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="${1:?usage: $0 <scheme> <configuration>}"
CONFIG="${2:?usage: $0 <scheme> <configuration>}"
PROJECT="FIN1.xcodeproj"
DEST="${IOS_BUILD_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.6}"

echo "=== xcodebuild build === scheme=$SCHEME configuration=$CONFIG destination=$DEST"

xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  -quiet \
  build
