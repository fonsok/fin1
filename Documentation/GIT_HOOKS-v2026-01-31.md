## Git Hooks (Local) — v2026-01-31

This repo includes opinionated pre-commit checks in `.githooks/pre-commit`.

### Install

Run:

```bash
./scripts/install-githooks-v2026-01-31.sh
```

This copies `.githooks/pre-commit` into `.git/hooks/pre-commit` and ensures it is executable.

### What it enforces

- `scripts/check-xcode-display-name-v2026-01-31.sh` (blocks committing test `CFBundleDisplayName` values)
- ResponsiveDesign checks
- SwiftLint / SwiftFormat
- MVVM validation
- Duplicate file detection

