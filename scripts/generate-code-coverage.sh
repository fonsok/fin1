#!/bin/bash

# Script to generate code coverage report for FIN1
# Usage: ./scripts/generate-code-coverage.sh

set -e

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "📊 Generating Code Coverage Report..."

DEST="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.6}"

# Run tests with code coverage (same destination contract as scripts/run-ios-tests.sh)
xcodebuild test \
  -project FIN1.xcodeproj \
  -scheme FIN1 \
  -destination "$DEST" \
  -enableCodeCoverage YES \
  -resultBundlePath ./coverage-results.xcresult

echo "✅ Code Coverage Report Generated"
echo "📁 Results saved to: ./coverage-results.xcresult"
echo ""
echo "To view coverage in Xcode:"
echo "1. Open Xcode"
echo "2. Window → Organizer → Reports"
echo "3. Select the test run"
echo "4. Click 'Coverage' tab"
echo ""
echo "Or use xcresulttool to extract coverage:"
echo "xcrun xcresulttool get --format json --path ./coverage-results.xcresult"







