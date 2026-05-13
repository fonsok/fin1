#!/usr/bin/env bash
# Fail CI if production admin bundles are tracked in git (repo bloat + stale hashes).
# Source of truth: admin-portal/; build output is admin-portal/dist/ and server sync ~/fin1-server/admin/.
# Allow only optional documentation at repo root admin/ (see .gitignore: /admin/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

violations=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    admin/README.md) continue ;;
    *)
      violations+=("$f")
      ;;
  esac
done < <(git ls-files admin admin-portal/dist 2>/dev/null || true)

if ((${#violations[@]} > 0)); then
  echo "check-no-tracked-admin-spa-artifacts: tracked paths under admin/ or admin-portal/dist/ are not allowed (except admin/README.md)." >&2
  printf '%s\n' "${violations[@]}" >&2
  echo "Remove from the index: git rm -r --cached <paths> — build locally and deploy via admin-portal/deploy.sh / sync scripts only." >&2
  exit 1
fi

exit 0
