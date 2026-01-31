#!/bin/bash

# ResponsiveDesign Compliance Checker
# This script ensures all UI code uses the ResponsiveDesign system

set -e

echo "🔍 Checking ResponsiveDesign compliance..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track violations
VIOLATIONS=0

# Check for forbidden patterns
check_pattern() {
    local pattern="$1"
    local description="$2"
    local files=$(find . -name "*.swift" -type f -not -path "*/.*" -not -path "*Tests*" -exec grep -l "$pattern" {} \; 2>/dev/null || true)

    if [ -n "$files" ]; then
        echo -e "${RED}❌ VIOLATION: $description${NC}"
        echo "$files" | while read -r file; do
            echo "  📄 $file"
            grep -n "$pattern" "$file" | head -3 | sed 's/^/    /'
        done
        VIOLATIONS=$((VIOLATIONS + 1))
        echo ""
    fi
}

# Check for fixed font patterns
check_pattern "\.font(\.title[^F])" "Fixed font patterns (.font(.title), .font(.headline), etc.)"
check_pattern "\.font(\.headline[^F])" "Fixed headline font patterns"
check_pattern "\.font(\.subheadline[^F])" "Fixed subheadline font patterns"
check_pattern "\.font(\.body[^F])" "Fixed body font patterns"
check_pattern "\.font(\.caption[^F])" "Fixed caption font patterns"

# Check for fixed spacing patterns
check_pattern "VStack(spacing: [0-9]" "Fixed VStack spacing values"
check_pattern "HStack(spacing: [0-9]" "Fixed HStack spacing values"

# Check for fixed corner radius patterns
check_pattern "\.cornerRadius([0-9]" "Fixed corner radius values"
check_pattern "RoundedRectangle(cornerRadius: [0-9]" "Fixed RoundedRectangle corner radius values"

# Check for fixed padding patterns (excluding ResponsiveDesign calls)
check_pattern "\.padding([0-9]" "Fixed padding values"

# Check for fixed icon sizes
check_pattern "\.font(\.title3)" "Fixed icon font sizes"

# Summary
echo "=========================================="
if [ $VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Code is fully compliant with ResponsiveDesign system.${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $VIOLATIONS violation(s). Please fix these issues.${NC}"
    echo -e "${YELLOW}💡 Use ResponsiveDesign.titleFont(), ResponsiveDesign.spacing(N), etc.${NC}"
    exit 1
fi
