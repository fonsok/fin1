#!/usr/bin/env bash
# Resolve a concrete iOS Simulator destination for xcodebuild test/build.
#
# GitHub macos-15 + Xcode 26 images may not ship iPhone 16 + OS=18.6 even when local
# dev machines still have that runtime. This script picks the best available simulator
# from `xcodebuild -showdestinations`, preferring a requested destination when present.
#
# Usage:
#   ./scripts/resolve-ios-sim-destination.sh
#   IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.6' ./scripts/resolve-ios-sim-destination.sh
#
# Env (optional):
#   IOS_PROJECT            default: FIN1.xcodeproj (relative to repo root)
#   IOS_RESOLVE_SCHEME     default: FIN1
#   IOS_TEST_DESTINATION   preferred destination (used when available on this machine)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${IOS_PROJECT:-FIN1.xcodeproj}"
SCHEME="${IOS_RESOLVE_SCHEME:-FIN1}"
REQUESTED="${IOS_TEST_DESTINATION:-}"

DESTINATIONS="$(
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null \
    | grep 'platform:iOS Simulator' \
    | grep -v placeholder \
    || true
)"

if [[ -z "$DESTINATIONS" ]]; then
  echo "resolve-ios-sim-destination: no iOS Simulator destinations from xcodebuild" >&2
  exit 1
fi

extract_field() {
  local line="$1"
  local key="$2"
  printf '%s' "$line" | sed -n "s/.*${key}:\\([^,}]*\\).*/\\1/p" | head -1 | xargs
}

format_destination() {
  local name="$1"
  local os="$2"
  printf 'platform=iOS Simulator,name=%s,OS=%s' "$name" "$os"
}

matches_requested() {
  local line="$1"
  local req_name req_os
  req_name="$(printf '%s' "$REQUESTED" | sed -n 's/.*name=\([^,]*\).*/\1/p')"
  req_os="$(printf '%s' "$REQUESTED" | sed -n 's/.*OS=\([^,]*\).*/\1/p')"
  [[ -n "$req_name" ]] || return 1
  local name os
  name="$(extract_field "$line" 'name')"
  os="$(extract_field "$line" 'OS')"
  [[ "$name" == "$req_name" ]] || return 1
  if [[ -n "$req_os" ]]; then
    [[ "$os" == "$req_os" ]]
  else
    return 0
  fi
}

pick_first_named() {
  local target="$1"
  local line name os
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="$(extract_field "$line" 'name')"
    if [[ "$name" == "$target" ]]; then
      os="$(extract_field "$line" 'OS')"
      format_destination "$name" "$os"
      return 0
    fi
  done <<< "$DESTINATIONS"
  return 1
}

pick_first_iphone() {
  local line name os
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="$(extract_field "$line" 'name')"
    if [[ "$name" == iPhone* ]]; then
      os="$(extract_field "$line" 'OS')"
      format_destination "$name" "$os"
      return 0
    fi
  done <<< "$DESTINATIONS"
  return 1
}

if [[ -n "$REQUESTED" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if matches_requested "$line"; then
      format_destination "$(extract_field "$line" 'name')" "$(extract_field "$line" 'OS')"
      exit 0
    fi
  done <<< "$DESTINATIONS"
  echo "resolve-ios-sim-destination: requested destination unavailable, falling back: $REQUESTED" >&2
fi

for candidate in "iPhone 16" "iPhone 16 Pro" "iPhone 16e" "iPhone 16 Plus" "iPhone 16 Pro Max"; do
  if dest="$(pick_first_named "$candidate")"; then
    printf '%s' "$dest"
    exit 0
  fi
done

if dest="$(pick_first_iphone)"; then
  printf '%s' "$dest"
  exit 0
fi

first_line="$(printf '%s\n' "$DESTINATIONS" | head -1)"
format_destination "$(extract_field "$first_line" 'name')" "$(extract_field "$first_line" 'OS')"
