# Documentation Archive

## Overview

This directory contains archived documentation files that are no longer actively maintained but are kept for historical reference.

## Archive Date

**Initial Archive**: December 2024
**Reorganized**: January 2026

---

## Directory Structure

```
Archive/
├── README.md              # This file
├── Phases/                # Historical phase implementation docs (27 files)
├── Fixes/                 # One-time bug fix documentation (9 files)
├── Implementation/        # Completed feature implementations (16 files)
├── Refactoring/           # Completed refactoring summaries (21 files)
├── Reviews/               # Historical code reviews (2 files)
├── Specifications/        # Unimplemented/stub specifications (6 files)
└── (legacy files)         # Original pot→pool terminology docs (4 files)
```

---

## Subdirectory Contents

### `Phases/` (27 files)
Historical documentation of compilation fixes and architecture evolution.

- **PHASE_5_*.md** - Compilation error fixes (authentication, models, switches)
- **PHASE_6_*.md** - Service architecture, DI improvements, final fixes
- **PHASE_7_*.md** - DI and warnings cleanup
- **PHASE_8_*.md** - Architecture completion

**Status**: All phases completed successfully. Kept for architectural decision history.

### `Fixes/` (9 files)
One-time bug fix documentation moved from project root.

- **FINAL_INVOICE_FIX_ROOT_CAUSE.md** - DI violation fix for invoice service
- **INVOICE_TRADE_LINKING_FIX.md** - Trade-invoice linking
- **TRADE_CONFIRMATION_OVERLAY_IMPLEMENTATION.md** - UI overlay implementation
- **SECURITIES_SEARCH_NAVIGATION_FIX.md** - Navigation bug fix
- And others...

**Status**: All fixes implemented. Kept for debugging reference if issues resurface.

### `Implementation/` (16 files)
Completed feature implementation summaries.

- **IMPLEMENTATION_Authentication_Flow.md** - Auth system implementation
- **IMPLEMENTATION_RiskClass.md** - Risk classification feature
- **IMPLEMENTATION_Signup_Summary_RiskClasses.md** - Sign-up flow with risk classes
- **IMPLEMENTATION_SUMMARY_PHASES_1-7-FIN1-Kopie51.md** - Consolidated phase summary
- And others...

**Status**: Features implemented. Kept for onboarding and feature understanding.

### `Refactoring/` (21 files)
Completed refactoring and reorganization summaries.

- **REFACTORING_PROGRESS.md** - SignUp view refactoring (100% complete)
- **FOLDER_REORGANIZATION_SUMMARY.md** - Project structure reorganization
- **CURSOR_RULES_UPDATE_SUMMARY.md** - Rules migration to .cursor/rules/
- **PROJEKTANALYSE.md** - German project analysis
- **REFACTORING_BEISPIELE.md** - German refactoring examples
- **RESPONSIVE_DESIGN_IMPLEMENTATION_SUMMARY.md** - ResponsiveDesign migration
- And others...

**Status**: All refactoring complete. Kept for understanding code evolution.

### `Reviews/` (2 files)
Historical code review documents.

- **MVVM_REVIEW_ANALYSIS.md** - Search implementation MVVM review
- **REVIEW_TraderPerformanceChart.md** - Trader performance chart review

**Status**: Reviews completed. Kept for reference on review criteria and standards.

### `Specifications/` (6 files)
Aspirational specifications that were never fully implemented.

- **CalculationKitAPI.swift** - Stub/placeholder
- **CalculationKitConstants.swift** - Stub/placeholder
- **CalculationKitDTOs.swift** - Stub/placeholder
- **CalculationKitFacade.swift** - Stub/placeholder
- **CalculationKitServices.swift** - Stub/placeholder
- **CalculationIntegrationGuide.md** - Integration guide referencing unimplemented CalculationKit

**Status**: These represent a planned "CalculationKit" abstraction that was never implemented. The actual calculation services exist but use a different architecture. Consider implementing the abstraction or removing entirely.

### Legacy Files (Root of Archive/)
Original "pot" → "pool" terminology migration docs.

- **POT_TRADING_*.md** files

**Status**: Terminology updated throughout codebase. Historical reference only.

---

## Current Documentation

For up-to-date documentation, see:

| Location | Contents |
|----------|----------|
| `.cursor/rules/` | Active cursor rules (architecture, testing, etc.) |
| `Documentation/` (root) | Active guides and references |
| `FIN1/Documentation/` | Active feature documentation |

---

## When to Reference Archives

Use these archives when:
1. Debugging a regression that may be related to a previous fix
2. Understanding historical architectural decisions
3. Onboarding and learning how features were implemented
4. Reviving or reimplementing a deprecated feature

---

## Notes

- These files are **not actively maintained**
- Code examples may reference outdated APIs
- File paths may not match current structure
- Implementation details may have changed

---

**Last Updated**: January 2026
