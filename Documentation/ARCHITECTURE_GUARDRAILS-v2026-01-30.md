# Architecture Guardrails & Improvement Protection

This document outlines all automated checks and guardrails that protect architectural improvements and prevent regressions.

## 🛡️ Protected Improvements

### 1. Separation of Concerns ✅

**What's Protected:**
- Views only contain UI logic
- ViewModels handle business logic
- Services handle data/network operations
- Proper file organization (Views in Views/, ViewModels in ViewModels/)

**Automated Checks:**
- ✅ **SwiftLint Rules**: Detects service calls, business logic, and formatting in Views
- ✅ **Pre-commit Hook**: `validate-separation-of-concerns.sh` runs before every commit
- ✅ **CI/CD**: Runs in GitHub Actions on every PR
- ✅ **Danger**: Warns on PRs if Views contain service calls or business logic
- ✅ **Danger**: Fails PRs if Views are in Models/ directory or ViewModels in Views/

**How It Works:**
```bash
# Runs automatically on commit
./scripts/validate-separation-of-concerns.sh

# Checks:
# - Views don't call services directly
# - Views don't contain business logic (filter, map, reduce, etc.)
# - Views are in Views/ directory, not Models/
# - ViewModels are in ViewModels/ directory, not Views/
```

### 2. MVVM Architecture ✅

**What's Protected:**
- ViewModels coordinate logic (not Views)
- Dependency injection via protocols
- No singletons outside composition root
- Data formatting in ViewModels

**Automated Checks:**
- ✅ **SwiftLint Rules**: 15+ custom rules for MVVM violations
- ✅ **Pre-commit Hook**: `validate-mvvm-architecture.sh` runs before every commit
- ✅ **CI/CD**: Runs in GitHub Actions
- ✅ **Danger**: Warns if ViewModels changed without tests

**How It Works:**
```bash
# Runs automatically on commit
./scripts/validate-mvvm-architecture.sh

# Checks:
# - No data formatting in Views
# - No direct service access in Views
# - ViewModels created in init(), not property declaration
# - Proper dependency injection patterns
```

### 3. File Size Limits ✅

**What's Protected:**
- Classes ≤ 400 lines
- Functions ≤ 50 lines
- Large types split into extensions

**Automated Checks:**
- ✅ **Pre-commit Hook**: `check-file-sizes.sh` runs before every commit
- ✅ **CI/CD**: Runs in GitHub Actions
- ✅ **Danger**: Warns on PRs if files exceed 400 lines

**How It Works:**
```bash
# Runs automatically on commit
./scripts/check-file-sizes.sh

# Checks:
# - All Swift files ≤ 400 lines
# - All functions ≤ 50 lines
```

### 4. Bundle Size Monitoring ✅

**What's Protected:**
- App bundle stays under App Store limits
- Early detection of size regressions

**Automated Checks:**
- ✅ **CI/CD**: `check-bundle-size.sh` runs in GitHub Actions
- ✅ **Thresholds**: Warning (50MB), Error (100MB), Critical (180MB)

**How It Works:**
```bash
# Runs in CI on every build
./scripts/check-bundle-size.sh Release

# Checks:
# - Bundle size < 50MB (warning)
# - Bundle size < 100MB (error)
# - Bundle size < 180MB (critical - near App Store limit)
```

### 5. ResponsiveDesign System ✅

**What's Protected:**
- Consistent spacing, fonts, and design tokens
- No fixed values in UI code

**Automated Checks:**
- ✅ **SwiftLint Rules**: 5 custom rules catch violations
- ✅ **Pre-commit Hook**: `check-responsive-design.sh` runs before every commit
- ✅ **CI/CD**: Runs in GitHub Actions

### 6. Code Quality ✅

**What's Protected:**
- Code formatting consistency
- Linting compliance
- No duplicate files

**Automated Checks:**
- ✅ **SwiftFormat**: Checks formatting before commit
- ✅ **SwiftLint**: Strict mode enforcement
- ✅ **Pre-commit Hook**: `detect-duplicate-files.sh` prevents duplicates

## 📋 Complete Check List

### Pre-Commit (Local)
Runs automatically before every commit:

1. ✅ ResponsiveDesign compliance
2. ✅ Main view spacing validation
3. ✅ SwiftLint (strict mode)
4. ✅ SwiftFormat check
5. ✅ MVVM architecture validation
6. ✅ Duplicate file detection
7. ✅ **Separation of concerns validation** ← NEW
8. ✅ **File size validation** ← NEW

### CI/CD (GitHub Actions)
Runs on every PR and push:

1. ✅ SwiftFormat
2. ✅ SwiftLint
3. ✅ Build & Test
4. ✅ **Bundle size check** ← NEW
5. ✅ **Separation of concerns validation** ← NEW
6. ✅ **File size validation** ← NEW
7. ✅ Danger (PR review)

### Danger (PR Review)
Runs on every PR:

1. ✅ Nested test folder prevention
2. ✅ Duplicate directory structure detection
3. ✅ Singleton usage detection
4. ✅ ViewModel test requirements
5. ✅ Securities search filter protection
6. ✅ **Views in Models/ detection** ← NEW
7. ✅ **ViewModels in Views/ detection** ← NEW
8. ✅ **Service calls in Views warning** ← NEW
9. ✅ **Large file warnings** ← NEW

## 🚨 What Happens When Violations Are Detected

### Pre-Commit Hook
- **Blocks commit** until violations are fixed
- Shows specific error messages
- Provides fix suggestions

### CI/CD
- **Fails build** if critical violations found
- **Warns** on non-critical violations
- Prevents merge until fixed

### Danger (PR)
- **Fails PR** for critical violations (Views in wrong directory)
- **Warns** on potential issues (large files, service calls in Views)
- Provides context and fix suggestions

## 📖 Documentation

All improvements are documented:

- **Architecture Rules**: `.cursor/rules/architecture.md`
- **MVVM Guide**: `Documentation/MVVM_VALIDATION_GUIDE.md`
- **ResponsiveDesign**: `Documentation/ResponsiveDesign.md`
- **Bundle Size**: `scripts/README-Bundle-Size.md`
- **This Document**: `Documentation/ARCHITECTURE_GUARDRAILS.md`

## 🔧 Manual Checks

You can run any check manually:

```bash
# Separation of concerns
./scripts/validate-separation-of-concerns.sh

# File sizes
./scripts/check-file-sizes.sh

# Bundle size
./scripts/check-bundle-size.sh Release

# MVVM architecture
./scripts/validate-mvvm-architecture.sh

# ResponsiveDesign
./scripts/check-responsive-design.sh
```

## ✅ Summary

**All improvements are now protected by automated checks that:**
1. ✅ Run before every commit (pre-commit hook)
2. ✅ Run on every PR (CI/CD + Danger)
3. ✅ Provide clear error messages and fix suggestions
4. ✅ Prevent regressions from being merged
5. ✅ Are documented and easy to understand

**Result**: Architectural improvements cannot be accidentally reversed. All changes must pass validation before being committed or merged.

