#!/usr/bin/env bash
# Schreibt ein JSON-Deploy-Manifest (Git-SHA, Branch, Dirty-Flag, Zeit, optional Inhaltshash).
# Schritt 1 „moderner Deploy“: Reproduzierbarkeit ohne Registry (siehe Documentation/MODERN_DEPLOY_BEST_PRACTICES.md).
#
# Usage (Repo-Root = Git-Checkout):
#   ./scripts/write-deploy-manifest.sh --component parse-cloud
#   ./scripts/write-deploy-manifest.sh --component parse-cloud --output /tmp/manifest.json
#
# Umgebung:
#   DEPLOY_MANIFEST_GIT_REF (optional, default HEAD) — z. B. Tag nach Release
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPONENT=""
OUT_PATH=""
GIT_REF="${DEPLOY_MANIFEST_GIT_REF:-HEAD}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component)
      COMPONENT="${2:-}"
      shift 2
      ;;
    --output|-o)
      OUT_PATH="${2:-}"
      shift 2
      ;;
    --help|-h)
      sed -n '1,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$COMPONENT" ]]; then
  echo "write-deploy-manifest: --component required (e.g. parse-cloud)" >&2
  exit 2
fi

cd "$PROJECT_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "write-deploy-manifest: not a git repository: ${PROJECT_ROOT}" >&2
  exit 1
fi

COMMIT="$(git rev-parse "$GIT_REF")"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
if git diff --quiet && git diff --cached --quiet 2>/dev/null; then
  DIRTY="false"
else
  DIRTY="true"
fi

# Inhaltshash der per rsync/deploy übertragenen Parse-Cloud (nur versionierte Pfade in Git).
TREE_HASH=""
if git cat-file -e "${COMMIT}:backend/parse-server/cloud" 2>/dev/null; then
  TREE_HASH="$(git archive --format=tar "${COMMIT}" backend/parse-server/cloud 2>/dev/null | openssl dgst -sha256 2>/dev/null | awk '{print $2}' || true)"
fi

ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

export MANIFEST_COMPONENT="$COMPONENT"
export MANIFEST_COMMIT="$COMMIT"
export MANIFEST_BRANCH="$BRANCH"
export MANIFEST_DIRTY="$DIRTY"
export MANIFEST_GIT_REF="$GIT_REF"
export MANIFEST_ISO="$ISO"
export MANIFEST_TREE_HASH="$TREE_HASH"

JSON="$(python3 <<'PY'
import json
import os

def b(name: str) -> bool:
    return os.environ.get(name, "false").lower() in ("1", "true", "yes")

obj = {
    "schemaVersion": 1,
    "component": os.environ["MANIFEST_COMPONENT"],
    "gitCommit": os.environ["MANIFEST_COMMIT"],
    "gitBranch": os.environ["MANIFEST_BRANCH"],
    "gitTreeDirty": b("MANIFEST_DIRTY"),
    "gitRef": os.environ["MANIFEST_GIT_REF"],
    "generatedAtUtc": os.environ["MANIFEST_ISO"],
}
h = os.environ.get("MANIFEST_TREE_HASH", "").strip()
if h:
    obj["sourceTreeSha256"] = h
print(json.dumps(obj, indent=2, ensure_ascii=False))
PY
)"

if [[ -n "$OUT_PATH" ]]; then
  printf '%s\n' "$JSON" >"$OUT_PATH"
else
  printf '%s\n' "$JSON"
fi
