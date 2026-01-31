#!/bin/bash

# MVVM Architecture Validation Script
# Detects violations of MVVM patterns in SwiftUI Views
# This script performs deeper analysis than SwiftLint regex rules

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VIOLATIONS=0
WARNINGS=0

log() { echo -e "${BLUE}[MVVM Check]${NC} $1"; }
warn() { echo -e "${YELLOW}[MVVM Warning]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
error() { echo -e "${RED}[MVVM Error]${NC} $1"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}[MVVM OK]${NC} $1"; }

# Find all View files
VIEW_FILES=$(find FIN1/Features -name "*.swift" -type f | grep -E "(View|Component)" | grep -v "ViewModel" | grep -v "Model" | grep -v "Extension" | grep -v "Wrapper" | sort)

log "Checking MVVM architecture compliance..."
echo ""

for file in $VIEW_FILES; do
    # Skip if file doesn't exist or is empty
    [ ! -f "$file" ] && continue
    [ ! -s "$file" ] && continue

    filename=$(basename "$file")

    # Check if file contains a View struct
    if ! grep -q "struct.*View.*:" "$file" 2>/dev/null; then
        continue
    fi

    # Extract View struct name
    view_name=$(grep -oE "struct\s+(\w+View|\w+Component)" "$file" | head -1 | awk '{print $2}' || echo "")
    [ -z "$view_name" ] && continue

    # Check 1: View has model property but no ViewModel
    has_model=$(grep -E "let\s+\w+:\s*(Investment|Trade|Order|Invoice|User|MockTrader|DepotHolding)" "$file" | grep -v "ViewModel" | wc -l | tr -d ' ')
    has_viewmodel=$(grep -E "@StateObject.*ViewModel|@ObservedObject.*ViewModel" "$file" | wc -l | tr -d ' ')

    if [ "$has_model" -gt 0 ] && [ "$has_viewmodel" -eq 0 ]; then
        # Check if model properties are accessed directly
        model_access=$(grep -E "(Investment|Trade|Order|Invoice|User|MockTrader|DepotHolding)\." "$file" | grep -v "//" | grep -v "ViewModel" | wc -l | tr -d ' ')
        if [ "$model_access" -gt 0 ]; then
            error "$file: $view_name has model property but no ViewModel, and accesses model directly"
            echo "  → Consider creating a ${view_name}ViewModel to handle data transformation"
        fi
    fi

    # Check 2: Data formatting in View body
    formatting_in_view=$(grep -E "\.(formatted|formattedAs|formattedAsLocalized)" "$file" | grep -v "ViewModel" | grep -v "Model" | grep -v "Extension" | grep -v "//" | wc -l | tr -d ' ')
    if [ "$formatting_in_view" -gt 0 ]; then
        error "$file: $view_name contains data formatting in View (should be in ViewModel)"
        echo "  → Move formatting logic to ViewModel properties"
    fi

    # Check 3: Date formatting in View body
    date_formatting=$(grep -E "\.formatted\(date:" "$file" | grep -v "ViewModel" | grep -v "Model" | grep -v "Extension" | grep -v "//" | wc -l | tr -d ' ')
    if [ "$date_formatting" -gt 0 ]; then
        error "$file: $view_name contains date formatting in View (should be in ViewModel)"
        echo "  → Move date formatting to ViewModel properties"
    fi

    # Check 4: Business logic in View (filter, map, reduce, etc.)
    # Only match actual method calls (with parentheses or closures), not property names
    # Exclude ViewModel calls and property accesses (filters, maps, etc. as properties)
    business_logic=$(grep -E "\.(filter|map|reduce|sorted|grouped)\(|Dictionary\(grouping:" "$file" | \
        grep -viE "viewmodel|viewModel\." | \
        grep -vE "(\.filtered|\.filters|\.maps|\.reduces|\.sorteds)[^\(]*[,\)}]" | \
        grep -vE "\.filters\s*[,\)}]" | \
        grep -v "//" | \
        wc -l | tr -d ' ')
    if [ "$business_logic" -gt 0 ]; then
        error "$file: $view_name contains business logic (filter/map/reduce) in View (should be in ViewModel)"
        echo "  → Move data processing to ViewModel methods"
    fi

    # Check 5: ViewModel instantiation in body (should be in init)
    viewmodel_in_body=$(grep -E "@StateObject.*=.*ViewModel\(" "$file" | wc -l | tr -d ' ')
    if [ "$viewmodel_in_body" -gt 0 ]; then
        error "$file: $view_name creates ViewModel in property declaration (should be in init)"
        echo "  → Use: @StateObject private var viewModel: SomeViewModel with init() method"
    fi

    # Check 6: Direct service access
    direct_service=$(grep -E "AppServices\.live\." "$file" | grep -v "//" | wc -l | tr -d ' ')
    if [ "$direct_service" -gt 0 ]; then
        error "$file: $view_name uses AppServices.live directly (should use @Environment(\.appServices))"
        echo "  → Use dependency injection via @Environment(\.appServices)"
    fi
done

echo ""
log "Checking for corresponding ViewModels..."

# Check if Views have corresponding ViewModels
for file in $VIEW_FILES; do
    filename=$(basename "$file" .swift)
    view_name=$(grep -oE "struct\s+(\w+View|\w+Component)" "$file" | head -1 | awk '{print $2}' || echo "")
    [ -z "$view_name" ] && continue

    # Check if ViewModel exists
    expected_viewmodel="${view_name}ViewModel"
    viewmodel_file=$(find FIN1/Features -name "*${expected_viewmodel}.swift" -o -name "*${expected_viewmodel}.swift" 2>/dev/null | head -1)

    # Check if view has model properties
    has_model=$(grep -E "let\s+\w+:\s*(Investment|Trade|Order|Invoice|User|MockTrader|DepotHolding)" "$file" | grep -v "ViewModel" | wc -l | tr -d ' ')
    has_viewmodel_ref=$(grep -E "@StateObject.*ViewModel|@ObservedObject.*ViewModel" "$file" | wc -l | tr -d ' ')

    # If view has model but no ViewModel reference, check if ViewModel file exists
    if [ "$has_model" -gt 0 ] && [ "$has_viewmodel_ref" -eq 0 ]; then
        if [ -z "$viewmodel_file" ]; then
            warn "$file: $view_name has model properties but no ViewModel found"
            echo "  → Consider creating $expected_viewmodel.swift"
        fi
    fi
done

echo ""
log "Summary:"
if [ $VIOLATIONS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    pass "No MVVM violations found!"
    exit 0
elif [ $VIOLATIONS -eq 0 ]; then
    warn "Found $WARNINGS warning(s) - review recommended"
    exit 0
else
    error "Found $VIOLATIONS violation(s) and $WARNINGS warning(s)"
    echo ""
    echo "Please fix the violations before committing."
    exit 1
fi

