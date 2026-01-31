#!/bin/bash
set -euo pipefail

# v2026-01-31
# Guard against accidentally committing temporary/test app names.
#
# Why: `AppBrand.appName` reads `CFBundleDisplayName`. If a developer sets
# `INFOPLIST_KEY_CFBundleDisplayName` to a test value (e.g. "testtttname"),
# the wrong name will show up in the app UI and any copy using AppBrand.

PBXPROJ="FIN1.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
  exit 0
fi

display_names="$(
  /usr/bin/grep -E "INFOPLIST_KEY_CFBundleDisplayName[[:space:]]*=" "$PBXPROJ" \
    | /usr/bin/sed -E 's/.*=[[:space:]]*([^;]+);.*/\1/' \
    | /usr/bin/tr -d '[:space:]' \
    | /usr/bin/sort -u
)"

if [[ -z "$display_names" ]]; then
  exit 0
fi

if echo "$display_names" | /usr/bin/grep -Eiq '^(test|tttt|mmmm|xxx|demo)'; then
  echo "❌ Refusing commit: suspicious CFBundleDisplayName detected in $PBXPROJ"
  echo "Found:"
  echo "$display_names" | /usr/bin/sed 's/^/  - /'
  echo
  echo "Fix: set Target → General → Identity → Display Name to the real app name."
  exit 1
fi

exit 0

