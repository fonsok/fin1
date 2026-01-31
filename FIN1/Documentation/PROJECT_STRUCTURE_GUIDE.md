# Project Structure Guide

## Overview

This document outlines the correct project structure for FIN1 to prevent duplicate files and build errors.

## Correct Directory Structure

```
FIN1/
├── FIN1/                          # Main app source code
│   ├── Features/                  # ✅ CORRECT: Feature modules
│   │   ├── Trader/
│   │   ├── Investor/
│   │   ├── Dashboard/
│   │   └── Authentication/
│   ├── Shared/                   # ✅ CORRECT: Shared code
│   ├── Assets.xcassets/
│   └── FIN1App.swift
├── FIN1Tests/                    # ✅ CORRECT: Test files at root
├── FIN1UITests/                  # ✅ CORRECT: UI test files
└── scripts/                      # ✅ CORRECT: Build and validation scripts
```

## ❌ FORBIDDEN: Duplicate Directory Structures

### Do NOT Create:

```
FIN1/
└── FIN1/
    └── FIN1/                     # ❌ FORBIDDEN: Nested FIN1/FIN1/
        └── Features/             # ❌ This causes duplicate file errors
```

### Why This Causes Problems

1. **Build Errors**: Xcode tries to compile the same file twice
   - Error: `Multiple commands produce 'FileName.stringsdata'`
2. **Confusion**: Developers don't know which file is the "real" one
3. **Maintenance**: Changes must be made in multiple places
4. **Git Issues**: Duplicate files tracked separately

## Common Mistakes

### ❌ Mistake 1: Copying Files to Wrong Location

```bash
# ❌ WRONG: Copying to nested directory
cp MyFile.swift FIN1/FIN1/Features/Trader/

# ✅ CORRECT: Copying to correct location
cp MyFile.swift FIN1/Features/Trader/
```

### ❌ Mistake 2: Creating Nested Directories

```bash
# ❌ WRONG: Creating nested structure
mkdir -p FIN1/FIN1/Features/NewFeature

# ✅ CORRECT: Creating in correct location
mkdir -p FIN1/Features/NewFeature
```

### ❌ Mistake 3: Adding Files to Xcode Project Twice

- Adding the same file from different locations
- Xcode shows file in both `FIN1/Features/` and `FIN1/FIN1/Features/`

## Detection and Prevention

### Automated Detection

1. **Pre-commit Hook**: Automatically checks for duplicates before commit
   ```bash
   ./scripts/detect-duplicate-files.sh
   ```

2. **Danger CI**: Checks PRs for files in nested directories
   - Fails if files added to `FIN1/FIN1/Features/`
   - Warns if files modified in nested structure

3. **Build Validation**: Xcode build will fail with clear error message

### Manual Checks

Before committing, verify:
- [ ] No files in `FIN1/FIN1/Features/` directory
- [ ] All source files are in `FIN1/Features/`
- [ ] All test files are in `FIN1Tests/` (not `FIN1/FIN1Tests/`)
- [ ] Run `./scripts/detect-duplicate-files.sh` passes

## How to Fix Duplicates

### Step 1: Identify Duplicates

```bash
./scripts/detect-duplicate-files.sh
```

### Step 2: Determine Which File is Correct

- Check file modification dates
- Check git history
- Check which one is in Xcode project
- Usually: `FIN1/Features/` is correct, `FIN1/FIN1/Features/` is duplicate

### Step 3: Remove Duplicate

```bash
# Remove duplicate file
rm FIN1/FIN1/Features/Trader/DuplicateFile.swift

# Or remove entire duplicate directory if empty
rm -rf FIN1/FIN1/
```

### Step 4: Verify Build

```bash
xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator build
```

### Step 5: Update Xcode Project (if needed)

1. Open Xcode
2. Right-click on duplicate file → Delete
3. Choose "Remove Reference" (not "Move to Trash")
4. Verify file is removed from project navigator

## Best Practices

### ✅ DO:

1. **Always use `FIN1/Features/`** for source code
2. **Check directory structure** before adding files
3. **Run duplicate detection** before committing
4. **Use Xcode's "Add Files"** dialog to ensure correct location
5. **Verify file location** in project navigator

### ❌ DON'T:

1. **Don't create nested `FIN1/FIN1/` directories**
2. **Don't copy files manually** without checking location
3. **Don't add same file twice** to Xcode project
4. **Don't ignore build warnings** about duplicate files
5. **Don't commit** if duplicate detection fails

## File Location Rules

| File Type | Correct Location | Wrong Location |
|-----------|------------------|----------------|
| Trader Views | `FIN1/Features/Trader/Views/` | `FIN1/FIN1/Features/Trader/Views/` |
| Investor Services | `FIN1/Features/Investor/Services/` | `FIN1/FIN1/Features/Investor/Services/` |
| Shared Extensions | `FIN1/Shared/Extensions/` | `FIN1/FIN1/Shared/Extensions/` |
| Unit Tests | `FIN1Tests/` | `FIN1/FIN1Tests/` |
| UI Tests | `FIN1UITests/` | `FIN1/FIN1UITests/` |

## Troubleshooting

### Build Error: "Multiple commands produce"

**Symptom**: Build fails with error about duplicate output files

**Solution**:
1. Run `./scripts/detect-duplicate-files.sh`
2. Remove duplicate files
3. Clean build folder: `xcodebuild clean`
4. Rebuild

### Xcode Shows File Twice

**Symptom**: Same file appears twice in project navigator

**Solution**:
1. Check if file exists in both locations on disk
2. Remove duplicate from Xcode (Remove Reference)
3. Delete duplicate file from filesystem
4. Re-add file from correct location if needed

### Git Shows Duplicate Files

**Symptom**: Git tracks same file from different paths

**Solution**:
1. Remove duplicate from git: `git rm FIN1/FIN1/Features/File.swift`
2. Delete duplicate file
3. Commit removal
4. Verify only one file remains tracked

## Related Documentation

- `.cursor/rules/dry-constants.md` - DRY principles
- `scripts/detect-duplicate-files.sh` - Duplicate detection script
- `Dangerfile.swift` - CI checks for duplicates


