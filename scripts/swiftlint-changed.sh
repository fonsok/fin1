#!/usr/bin/env bash
# Run SwiftLint only on Swift files changed vs a base ref (default: origin/main).
# Use for incremental cleanup / “no new mess” before pushing.
# Example: ./scripts/swiftlint-changed.sh
# Example: ./scripts/swiftlint-changed.sh origin/develop
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
BASE_REF="${1:-origin/main}"
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="main"
fi
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "No git ref origin/main or main; running full swiftlint."
  exec swiftlint
fi
MB="$(git merge-base HEAD "$BASE_REF" 2>/dev/null || true)"
if [[ -z "${MB}" ]]; then
  echo "No merge-base with ${BASE_REF}; running full swiftlint."
  exec swiftlint
fi
args=()
while IFS= read -r f; do
  [[ -n "${f}" ]] || continue
  [[ "${f}" == *.swift ]] || continue
  [[ -f "${f}" ]] || continue
  args+=("${f}")
done < <(git diff --name-only --diff-filter=ACMRT "${MB}"...HEAD)
if [[ ${#args[@]} -eq 0 ]]; then
  echo "No Swift files in git diff ${MB}...HEAD (vs ${BASE_REF})."
  exit 0
fi
echo "SwiftLint on ${#args[@]} file(s) changed vs ${BASE_REF} (merge-base ${MB})."
exec swiftlint lint -- "${args[@]}"
