#!/bin/bash

# Separation of Concerns Validation Script
# Ensures Views only contain UI logic, not business logic or service calls

set -e

VIOLATIONS=0
VIEWS_DIR="FIN1/Features"

echo "🔍 Validating separation of concerns..."
echo ""

# Check 1: Views should not directly call services
echo "📋 Checking for direct service calls in Views..."
SERVICE_CALLS_IN_VIEWS=$(find "$VIEWS_DIR" -path "*/Views/*" -name "*.swift" -type f | xargs grep -l "services\." 2>/dev/null | grep -v "ViewModel\|Wrapper" || true)

if [ -n "$SERVICE_CALLS_IN_VIEWS" ]; then
    echo "❌ Found Views with direct service calls:"
    echo "$SERVICE_CALLS_IN_VIEWS" | while read -r file; do
        echo "   - $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    done
    echo ""
    echo "💡 Fix: Extract service calls to ViewModel"
    echo ""
fi

# Check 2: Views should not contain business logic (calculations, data processing)
echo "📋 Checking for business logic in Views..."
BUSINESS_LOGIC_PATTERNS=(
    "\.filter\s*\{"
    "\.map\s*\{"
    "\.reduce\s*\("
    "\.sorted\s*\("
    "\.group\s*\("
    "try await.*Service"
    "services\..*Service"
)

for pattern in "${BUSINESS_LOGIC_PATTERNS[@]}"; do
    FOUND=$(find "$VIEWS_DIR" -path "*/Views/*" -name "*.swift" -type f | xargs grep -l "$pattern" 2>/dev/null | grep -v "ViewModel\|Wrapper\|Extension" || true)
    if [ -n "$FOUND" ]; then
        echo "⚠️  Potential business logic in Views (pattern: $pattern):"
        echo "$FOUND" | while read -r file; do
            echo "   - $file"
            VIOLATIONS=$((VIOLATIONS + 1))
        done
    fi
done

# Check 3: Views should not be in Models/ directory
echo "📋 Checking for Views in Models/ directory..."
VIEWS_IN_MODELS=$(find "$VIEWS_DIR" -path "*/Models/*" -name "*View*.swift" -type f 2>/dev/null || true)

if [ -n "$VIEWS_IN_MODELS" ]; then
    echo "❌ Found View files in Models/ directory:"
    echo "$VIEWS_IN_MODELS" | while read -r file; do
        echo "   - $file"
        echo "   💡 Move to: $(echo "$file" | sed 's|/Models/|/Views/|')"
        VIOLATIONS=$((VIOLATIONS + 1))
    done
    echo ""
fi

# Check 4: ViewModels should not be in Views/ directory
echo "📋 Checking for ViewModels in Views/ directory..."
VIEWMODELS_IN_VIEWS=$(find "$VIEWS_DIR" -path "*/Views/*" -name "*ViewModel*.swift" -type f 2>/dev/null || true)

if [ -n "$VIEWMODELS_IN_VIEWS" ]; then
    echo "❌ Found ViewModel files in Views/ directory:"
    echo "$VIEWMODELS_IN_VIEWS" | while read -r file; do
        echo "   - $file"
        echo "   💡 Move to: $(echo "$file" | sed 's|/Views/|/ViewModels/|')"
        VIOLATIONS=$((VIOLATIONS + 1))
    done
    echo ""
fi

# Summary
if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ Separation of concerns validation passed!"
    exit 0
else
    echo ""
    echo "❌ Found $VIOLATIONS separation of concerns violations"
    echo ""
    echo "📖 See Documentation/SEPARATION_OF_CONCERNS.md for guidelines"
    exit 1
fi

















