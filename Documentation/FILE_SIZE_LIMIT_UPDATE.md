# File Size Limit Update

## Change Summary

**Date**: Updated
**Change**: Class file size limit reduced from **500 lines** to **400 lines**

## Updated Limits

| Type | Previous Limit | New Limit | Status |
|------|----------------|-----------|--------|
| **General Classes** | 500 lines | **400 lines** | ✅ Updated |
| **Functions** | 50 lines | 50 lines | ✅ Unchanged |
| **Models** | 200 lines | 200 lines | ✅ Unchanged |
| **Views** | 300 lines | 300 lines | ✅ Unchanged |
| **ViewModels** | 400 lines | 400 lines | ✅ Already compliant |
| **Services** | 400 lines | 400 lines | ✅ Already compliant |

## Rationale

- **Better separation of concerns**: Smaller files are easier to understand and maintain
- **Reduced merge conflicts**: Smaller files reduce the chance of conflicts
- **Easier code reviews**: Reviewers can understand smaller files more quickly
- **Consistency**: Aligns with tiered limits already in place for ViewModels/Services

## Updated Files

All automated checks have been updated:

1. ✅ `scripts/check-file-sizes.sh` - Changed MAX_CLASS_LINES from 500 to 400
2. ✅ `Dangerfile.swift` - Updated warning threshold from 500 to 400
3. ✅ `scripts/pre-commit-hook.sh` - Updated comment
4. ✅ `Documentation/ARCHITECTURE_GUARDRAILS.md` - Updated documentation
5. ✅ `Documentation/IMPROVEMENT_PROTECTION_SUMMARY.md` - Updated summary
6. ✅ `.cursor/rules/architecture.md` - Updated architecture rules

## Enforcement

The new limit is enforced by:

- ✅ **Pre-commit hook**: Blocks commits if files exceed 400 lines
- ✅ **CI/CD**: Fails build if violations found
- ✅ **Danger**: Warns on PRs if files exceed 400 lines
- ✅ **Automated script**: `./scripts/check-file-sizes.sh`

## Current Violations

Some files currently exceed the 400-line limit. These should be refactored:

- `InvoiceViewModel.swift` (411 lines)
- `QRCodeGenerator.swift` (436 lines)
- `TradeStatementDisplayDataBuilder.swift` (409 lines)
- `MockDataGenerator.swift` (431 lines)
- `UnifiedOrderService.swift` (401 lines)
- `ConfigurationSettingsView.swift` (443 lines)
- `InvestmentsViewModel.swift` (408 lines)
- `Investment.swift` (422 lines)
- `CompletedInvestmentsTable.swift` (461 lines)

## Refactoring Strategy

For files exceeding 400 lines:

1. **Extract subcomponents** - Break Views into smaller reusable components
2. **Extract services** - Move business logic from ViewModels to dedicated services
3. **Use extensions** - Split large types into focused extensions
4. **Split by responsibility** - One file = one clear responsibility

## Migration

The limit change is **immediately active**. All new code must comply with the 400-line limit.

Existing files that exceed 400 lines should be refactored when:
- The file is being modified
- During code reviews
- When adding new features to the file

## Verification

Run the check manually:

```bash
./scripts/check-file-sizes.sh
```

The check will:
- ✅ Pass if all files are ≤ 400 lines
- ❌ Fail and list violations if any files exceed 400 lines

















