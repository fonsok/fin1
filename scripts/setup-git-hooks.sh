#!/bin/bash

# Setup Git Hooks for ResponsiveDesign Compliance
# Run this script once to set up pre-commit hooks

set -e

echo "🔧 Setting up Git hooks for ResponsiveDesign compliance..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository. Please run this from the project root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-commit hook
cp scripts/pre-commit-hook-v2026-01-30.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The following checks will now run before each commit:"
echo "  🔍 ResponsiveDesign compliance check"
echo "  🔍 SwiftLint validation"
echo "  🔍 SwiftFormat validation"
echo "  🔍 Duplicate file detection"
echo ""
echo "To bypass hooks for emergency commits, use:"
echo "  git commit --no-verify -m 'Emergency commit'"
echo ""
echo "To manually run checks:"
echo "  ./scripts/check-responsive-design-v2026-01-30.sh"
echo "  swiftlint --strict"
echo "  swiftformat . --lint"
