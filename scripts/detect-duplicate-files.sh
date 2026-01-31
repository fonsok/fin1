#!/bin/bash

# Script to detect duplicate Swift files in the project
# This helps prevent build errors from "Multiple commands produce" errors
# Compatible with macOS bash 3.2+

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUPLICATES_FOUND=0

echo "🔍 Checking for duplicate Swift files..."

# Create temporary file for tracking duplicates
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Find all Swift files, extract basenames, and find duplicates
find "$PROJECT_ROOT" -type f -name "*.swift" | \
    grep -v "/build/" | \
    grep -v "/.git/" | \
    grep -v "/DerivedData/" | \
    while read -r file; do
        basename=$(basename "$file")
        rel_path="${file#$PROJECT_ROOT/}"
        echo "$basename|$rel_path"
    done | sort > "$TEMP_FILE"

# Find duplicates by grouping by basename
CURRENT_BASENAME=""
CURRENT_PATHS=""
DUPLICATE_COUNT=0

while IFS='|' read -r basename rel_path; do
    if [[ "$basename" == "$CURRENT_BASENAME" ]]; then
        # Same basename - add to paths
        CURRENT_PATHS="$CURRENT_PATHS|$rel_path"
        DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
    else
        # New basename - check if previous one was duplicate
        if [[ $DUPLICATE_COUNT -gt 0 ]]; then
            echo ""
            echo "❌ DUPLICATE FOUND: $CURRENT_BASENAME (found $((DUPLICATE_COUNT + 1)) times)"
            IFS='|' read -ra PATHS <<< "$CURRENT_PATHS"
            for path in "${PATHS[@]}"; do
                echo "   📁 $path"
            done
            DUPLICATES_FOUND=1
        fi
        # Start tracking new basename
        CURRENT_BASENAME="$basename"
        CURRENT_PATHS="$rel_path"
        DUPLICATE_COUNT=0
    fi
done < "$TEMP_FILE"

# Check last basename
if [[ $DUPLICATE_COUNT -gt 0 ]]; then
    echo ""
    echo "❌ DUPLICATE FOUND: $CURRENT_BASENAME (found $((DUPLICATE_COUNT + 1)) times)"
    IFS='|' read -ra PATHS <<< "$CURRENT_PATHS"
    for path in "${PATHS[@]}"; do
        echo "   📁 $path"
    done
    DUPLICATES_FOUND=1
fi

# Check for nested FIN1/FIN1 directory structure (common source of duplicates)
if [[ -d "$PROJECT_ROOT/FIN1/FIN1" ]]; then
    echo ""
    echo "⚠️  WARNING: Found nested FIN1/FIN1 directory structure"
    echo "   This is likely a duplicate directory. Check if files should be in FIN1/Features/ instead."
    echo "   📁 FIN1/FIN1/"
    DUPLICATES_FOUND=1
fi

if [[ $DUPLICATES_FOUND -eq 1 ]]; then
    echo ""
    echo "❌ Duplicate files detected! Please remove duplicates before committing."
    echo "   Common causes:"
    echo "   - Files accidentally copied to FIN1/FIN1/ instead of FIN1/Features/"
    echo "   - Files added to both source and test directories"
    echo "   - Xcode project file includes same file multiple times"
    exit 1
else
    echo "✅ No duplicate files found"
    exit 0
fi

