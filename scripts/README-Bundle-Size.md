# Bundle Size Check Script

## Overview

The `check-bundle-size.sh` script monitors iOS app bundle size to prevent bloat and ensure App Store compliance.

## Usage

```bash
# Check Release build (default)
./scripts/check-bundle-size.sh Release

# Check Debug build
./scripts/check-bundle-size.sh Debug
```

## Thresholds

| Threshold | Size | Action |
|-----------|------|--------|
| **Warning** | 50MB | Warns but allows build |
| **Error** | 100MB | Fails build |
| **Critical** | 180MB | Fails build (near App Store limit) |

## App Store Limits

- **200MB**: Maximum size for over-the-air downloads
- **Larger apps**: Require WiFi connection to download
- **Current app**: ~40MB (well within limits)

## CI Integration

The script runs automatically in CI (`.github/workflows/ci.yml`) on every build to catch size regressions early.

## Manual Checks

Run locally before committing large changes:

```bash
./scripts/check-bundle-size.sh Release
```

## Reducing Bundle Size

If bundle size exceeds thresholds:

1. **Check large assets**: Images, videos, fonts
2. **Remove unused dependencies**: Check `Package.swift` and CocoaPods
3. **Optimize images**: Use compressed formats, remove duplicates
4. **Enable bitcode**: For App Store builds (if supported)
5. **Review frameworks**: Remove unused Swift packages
6. **Check debug symbols**: Ensure Release builds strip symbols

## Monitoring

Track bundle size over time by checking CI logs or running:

```bash
./scripts/check-bundle-size.sh Release | grep "Size:"
```

















