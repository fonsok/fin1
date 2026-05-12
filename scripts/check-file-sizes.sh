#!/bin/bash

# File Size Check Script
# Ensures Swift files ≤ 300 lines, functions ≤ 50 lines per architecture rules

set -e

MAX_CLASS_LINES=300
MAX_FUNCTION_LINES=50
VIOLATIONS=0

echo "🔍 Checking file and function sizes..."
echo ""

# Find all Swift files
SWIFT_FILES=$(find FIN1 -name "*.swift" -type f | grep -v "Tests\|Preview\|Extension" || true)

# Check class/file sizes
echo "📋 Checking Swift file sizes (limit: ${MAX_CLASS_LINES} lines)..."
for file in $SWIFT_FILES; do
    LINES=$(wc -l < "$file" | tr -d ' ')
    if [ "$LINES" -gt "$MAX_CLASS_LINES" ]; then
        echo "❌ $file: ${LINES} lines (exceeds ${MAX_CLASS_LINES} line limit)"
        echo "   💡 Consider splitting into smaller files or extracting logic to extensions"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# Check function sizes (approximate - counts lines between function declarations)
echo ""
echo "📋 Checking function sizes (limit: ${MAX_FUNCTION_LINES} lines)..."
for file in $SWIFT_FILES; do
    # Extract function definitions and count lines
    # This is approximate - looks for func declarations and counts to next func/class/struct/enum
    FUNCTIONS=$(grep -n "^[[:space:]]*func " "$file" 2>/dev/null || true)

    if [ -n "$FUNCTIONS" ]; then
        echo "$FUNCTIONS" | while IFS=: read -r line_num func_line; do
            # Get next function/class/struct/enum line
            NEXT_DECL=$(sed -n "${line_num},\$p" "$file" | grep -n "^[[:space:]]*\(func\|class\|struct\|enum\|extension\) " | head -2 | tail -1 | cut -d: -f1)

            if [ -n "$NEXT_DECL" ] && [ "$NEXT_DECL" -gt 1 ]; then
                FUNC_LINES=$((NEXT_DECL - 1))
            else
                # Last function in file - count to end
                TOTAL_LINES=$(wc -l < "$file" | tr -d ' ')
                FUNC_LINES=$((TOTAL_LINES - line_num + 1))
            fi

            if [ "$FUNC_LINES" -gt "$MAX_FUNCTION_LINES" ]; then
                FUNC_NAME=$(echo "$func_line" | sed 's/.*func \([^(]*\).*/\1/' | xargs)
                echo "⚠️  $file:${line_num} function '$FUNC_NAME': ${FUNC_LINES} lines (exceeds ${MAX_FUNCTION_LINES} line limit)"
                echo "   💡 Consider extracting logic to helper functions or separate methods"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        done
    fi
done

# Summary
if [ $VIOLATIONS -eq 0 ]; then
    echo ""
    echo "✅ File size validation passed!"
    exit 0
else
    echo ""
    echo "❌ Found $VIOLATIONS file/function size violations"
    echo ""
    echo "📖 Architecture rules:"
    echo "   - Swift files should be ≤ ${MAX_CLASS_LINES} lines"
    echo "   - Functions must be ≤ ${MAX_FUNCTION_LINES} lines"
    echo ""
    echo "💡 See .cursor/rules/architecture.md for refactoring guidelines"
    exit 1
fi

