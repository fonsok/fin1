#!/bin/bash

# Script to generate code coverage report for FIN1
# Usage: ./scripts/generate-code-coverage.sh

set -e

echo "📊 Generating Code Coverage Report..."

# Run tests with code coverage
xcodebuild test \
  -project FIN1.xcodeproj \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,id=AFA8ED45-7716-4D4C-A338-5D4ED1302E4F' \
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







