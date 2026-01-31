# Duplicate File Prevention Strategy

## Problem

Duplicate files cause Xcode build errors:
```
error: Multiple commands produce 'FileName.stringsdata'
```

This happens when the same file exists in multiple locations (e.g., `FIN1/Features/` and `FIN1/FIN1/Features/`).

## Solution: Multi-Layer Prevention

### Layer 1: Pre-commit Hook ✅

**Location**: `scripts/pre-commit-hook.sh`

Automatically runs before each commit:
- Detects duplicate Swift files
- Checks for nested `FIN1/FIN1/` directory structure
- Blocks commit if duplicates found

**Setup**:
```bash
./scripts/setup-git-hooks.sh
```

### Layer 2: Danger CI ✅

**Location**: `Dangerfile.swift`

Checks pull requests:
- **Fails PR** if files added to `FIN1/FIN1/Features/`
- **Warns** if files modified in nested structure

### Layer 3: Manual Detection Script ✅

**Location**: `scripts/detect-duplicate-files.sh`

Run manually anytime:
```bash
./scripts/detect-duplicate-files.sh
```

### Layer 4: Build Validation ✅

Xcode build automatically fails with clear error message if duplicates exist.

## Quick Reference

### ✅ Correct File Locations

| File Type | Location |
|-----------|----------|
| Source Code | `FIN1/Features/{Feature}/` |
| Shared Code | `FIN1/Shared/` |
| Unit Tests | `FIN1Tests/` |
| UI Tests | `FIN1UITests/` |

### ❌ Forbidden Locations

- `FIN1/FIN1/Features/` - Nested duplicate structure
- `FIN1/FIN1Tests/` - Nested test directory
- Any duplicate of existing files

## Before Committing Checklist

- [ ] Run `./scripts/detect-duplicate-files.sh` - should pass
- [ ] Verify no files in `FIN1/FIN1/` directory
- [ ] Check Xcode project navigator for duplicate file references
- [ ] Build succeeds: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 build`

## If Duplicates Are Found

1. **Identify which file is correct** (usually the one in `FIN1/Features/`)
2. **Remove duplicate** from filesystem
3. **Remove from Xcode project** if referenced
4. **Run detection script** to verify
5. **Rebuild** to confirm fix

## Related Files

- `scripts/detect-duplicate-files.sh` - Detection script
- `scripts/pre-commit-hook.sh` - Pre-commit validation
- `Dangerfile.swift` - CI validation
- `FIN1/Documentation/PROJECT_STRUCTURE_GUIDE.md` - Detailed guide


