# Duplicate File Prevention

## Overview

This directory contains scripts to prevent and detect duplicate files in the project, which can cause build errors like "Multiple commands produce".

## Scripts

### `detect-duplicate-files.sh`

Detects duplicate Swift files by checking for:
- Files with the same basename in different locations
- Nested `FIN1/FIN1/` directory structure

**Usage**:
```bash
./scripts/detect-duplicate-files.sh
```

**Exit Codes**:
- `0`: No duplicates found
- `1`: Duplicates detected

**Integration**:
- Automatically runs in pre-commit hook
- Can be run manually before committing
- Used in CI/CD pipeline

## Prevention Mechanisms

### 1. Pre-commit Hook

Automatically runs duplicate detection before each commit (installed via `scripts/install-githooks.sh`):
```bash
./scripts/install-githooks.sh
```

### 2. Danger CI

Checks PRs for:
- Files added to `FIN1/FIN1/Features/` (fails PR)
- Files modified in nested structure (warns)

### 3. Build Validation

Xcode build will fail with clear error if duplicates exist.

## Common Scenarios

### Scenario 1: Accidental Copy

**Problem**: Developer copies file to wrong location
```bash
cp MyFile.swift FIN1/FIN1/Features/Trader/  # Wrong!
```

**Detection**: Pre-commit hook catches it
**Fix**: Remove duplicate, use correct location

### Scenario 2: Nested Directory Creation

**Problem**: Developer creates nested structure
```bash
mkdir -p FIN1/FIN1/Features/NewFeature  # Wrong!
```

**Detection**: Script detects nested `FIN1/FIN1/` directory
**Fix**: Use `FIN1/Features/NewFeature` instead

### Scenario 3: Xcode Project Issue

**Problem**: Same file added to project twice from different locations

**Detection**: Build fails with "Multiple commands produce"
**Fix**: Remove duplicate reference in Xcode project

## Best Practices

1. **Always check location** before adding files
2. **Run detection script** before committing
3. **Use Xcode's "Add Files"** dialog (ensures correct location)
4. **Don't ignore build warnings** about duplicates
5. **Clean up immediately** if duplicates are found

## Troubleshooting

If script fails to detect duplicates:
1. Check script has execute permission: `chmod +x scripts/detect-duplicate-files.sh`
2. Verify script runs: `./scripts/detect-duplicate-files.sh`
3. Check for files in build directories (they're excluded)
4. Manually verify file locations


