# Cursor Rules Update Summary

## Overview

Updated `.cursor/rules/architecture.md` to include guidance for the new calculation service pattern and data source hierarchy enforcement.

---

## Changes Made

### 1. Added Calculation Services Pattern Section

**Location**: `Service Architecture` section (after line 41)

**Added Content**:
- Pattern for creating dedicated calculation services
- Requirements for DTOs, validation, and error handling
- Code example showing the pattern
- Benefits of using calculation services

**Key Points**:
- ✅ Use dedicated calculation services for complex business calculations
- ✅ Define input/output DTOs for clear contracts
- ✅ Include validation in the service
- ✅ Document and enforce data source hierarchy
- ✅ Use throwing methods with specific error types
- ✅ Comprehensive unit tests required

### 2. Updated Documentation Section

**Location**: `Documentation` section (line 245-248)

**Added Requirements**:
- Use dedicated calculation services (not inline calculations in ViewModels)
- Enforce data source hierarchy: Investment.amount (capital) → Trade.entryPrice → Invoice (fees/prices)
- Document hierarchy in service

### 3. Updated Guardrails Section

**Location**: `Guardrails` section (line 289-290)

**Added Rules**:
- **No calculation logic in ViewModels**: Complex calculations must use dedicated calculation services
- **No duplicate calculation code**: Calculation logic must be in a single service

---

## Impact

### For Future Development

1. **New Calculation Services**: Developers will follow the documented pattern
2. **Data Source Hierarchy**: Clear guidance on which data sources to use
3. **Code Quality**: Prevents duplicate calculation code
4. **Testing**: Ensures comprehensive test coverage

### For Code Reviews

1. **Enforcement**: Guardrails will catch violations
2. **Pattern Compliance**: Clear pattern to follow
3. **Documentation**: Requirements documented

---

## Related Documentation

- `ARCHITECTURE_ANALYSIS_COLLECTION_BILL_COMPLEXITY.md` - Original analysis
- `COLLECTION_BILL_IMPROVEMENTS_SUMMARY.md` - Implementation summary
- `DATA_SOURCE_HIERARCHY.md` - Data source documentation
- `UNIT_TESTS_IMPLEMENTATION.md` - Test implementation guide

---

## Verification

✅ **Rules Updated**: `.cursor/rules/architecture.md`
✅ **Pattern Documented**: Calculation Services Pattern section added
✅ **Guardrails Added**: No duplicate calculation code, no calculation logic in ViewModels
✅ **Documentation Updated**: Data source hierarchy requirements added

---

## Next Steps

The cursor rules now reflect the new architecture:
- ✅ Calculation services pattern documented
- ✅ Data source hierarchy requirements added
- ✅ Guardrails prevent duplicate calculation code
- ✅ Clear guidance for future development

All future calculation services should follow this pattern.















