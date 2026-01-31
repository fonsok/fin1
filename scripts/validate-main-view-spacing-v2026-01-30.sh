#!/bin/bash

# Main View Spacing Validation Script
# This script ensures the critical spacing fixes in main views are preserved

set -e

echo "🔍 Validating main view spacing..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track violations
VIOLATIONS=0

# Check specific files for correct spacing patterns
check_main_view_spacing() {
    local file="$1"
    local view_name="$2"

    echo "🔍 Checking $view_name spacing..."

    # Check for correct VStack spacing (should be 6 or less)
    if grep -q "VStack.*spacing: ResponsiveDesign\.spacing\([7-9]\|[1-9][0-9]\)" "$file"; then
        echo -e "${RED}❌ VIOLATION: $view_name has excessive VStack spacing${NC}"
        grep -n "VStack.*spacing: ResponsiveDesign\.spacing\([7-9]\|[1-9][0-9]\)" "$file" | sed 's/^/    /'
        VIOLATIONS=$((VIOLATIONS + 1))
    fi

    # Check for .responsivePadding() usage (should be replaced)
    if grep -q "\.responsivePadding()" "$file"; then
        echo -e "${RED}❌ VIOLATION: $view_name still uses .responsivePadding()${NC}"
        grep -n "\.responsivePadding()" "$file" | sed 's/^/    /'
        VIOLATIONS=$((VIOLATIONS + 1))
    fi

    # Check for correct padding pattern
    if ! grep -q "\.padding(\.horizontal, ResponsiveDesign\.horizontalPadding())" "$file"; then
        echo -e "${RED}❌ VIOLATION: $view_name missing correct horizontal padding pattern${NC}"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi

    if ! grep -q "\.padding(\.top, ResponsiveDesign\.spacing(8))" "$file"; then
        echo -e "${RED}❌ VIOLATION: $view_name missing correct top padding pattern${NC}"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
}

# Check the three main views
check_main_view_spacing "FIN1/Features/Dashboard/Views/Components/DashboardContainer.swift" "Dashboard"
check_main_view_spacing "FIN1/Features/Trader/Views/SecuritiesSearchView.swift" "Securities Search"
check_main_view_spacing "FIN1/Features/Trader/Views/TraderDepotView.swift" "Depot"

# Summary
echo "=========================================="
if [ $VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}✅ All main views have correct spacing patterns!${NC}"
    echo -e "${GREEN}✅ Spacing fixes are protected from regression.${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $VIOLATIONS violation(s) in main view spacing.${NC}"
    echo -e "${YELLOW}💡 These views must maintain optimal spacing patterns:${NC}"
    echo -e "${YELLOW}   - VStack spacing ≤ 6pt${NC}"
    echo -e "${YELLOW}   - Use .padding(.horizontal, ResponsiveDesign.horizontalPadding())${NC}"
    echo -e "${YELLOW}   - Use .padding(.top, ResponsiveDesign.spacing(8))${NC}"
    echo -e "${YELLOW}   - NO .responsivePadding() in main views${NC}"
    exit 1
fi
