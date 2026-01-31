#!/bin/bash

# Pre-commit hook for ResponsiveDesign compliance
# This script runs before each commit to ensure code quality

set -e

echo "🔍 Running pre-commit checks..."

# Run ResponsiveDesign compliance check
if ! ./scripts/check-responsive-design-v2026-01-30.sh; then
    echo "❌ ResponsiveDesign compliance check failed!"
    echo "Please fix the violations before committing."
    exit 1
fi

# Run specific spacing validation for main views
echo "🔍 Running spacing validation for main views..."
if ! ./scripts/validate-main-view-spacing-v2026-01-30.sh; then
    echo "❌ Main view spacing validation failed!"
    echo "Please ensure Dashboard, Securities Search, and Depot views use optimal spacing."
    exit 1
fi

# Run SwiftLint
echo "🔍 Running SwiftLint..."
if ! swiftlint --strict; then
    echo "❌ SwiftLint check failed!"
    echo "Please fix the linting issues before committing."
    exit 1
fi

# Run SwiftFormat check
echo "🔍 Running SwiftFormat check..."
if ! swiftformat . --lint; then
    echo "❌ SwiftFormat check failed!"
    echo "Please run 'swiftformat .' to fix formatting issues."
    exit 1
fi

# Run MVVM Architecture validation
echo "🔍 Running MVVM architecture validation..."
if ! ./scripts/validate-mvvm-architecture-v2026-01-30.sh; then
    echo "❌ MVVM architecture validation failed!"
    echo "Please fix the MVVM violations before committing."
    exit 1
fi

# Check for duplicate files
echo "🔍 Checking for duplicate files..."
if ! ./scripts/detect-duplicate-files-v2026-01-30.sh; then
    echo "❌ Duplicate files detected!"
    echo "Please remove duplicate files before committing."
    exit 1
fi

# Run Separation of Concerns validation
echo "🔍 Running separation of concerns validation..."
if ! ./scripts/validate-separation-of-concerns-v2026-01-30.sh; then
    echo "❌ Separation of concerns validation failed!"
    echo "Please fix the violations before committing."
    exit 1
fi

# Check file sizes (classes ≤ 400 lines, functions ≤ 50 lines)
echo "🔍 Checking file and function sizes..."
if ! ./scripts/check-file-sizes-v2026-01-30.sh; then
    echo "❌ File size validation failed!"
    echo "Please refactor large files/functions before committing."
    exit 1
fi

echo "✅ All pre-commit checks passed!"
exit 0
