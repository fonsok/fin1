#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_ROOT="$ROOT/backend/parse-server/cloud/functions/admin/reports"

if [[ ! -d "$REPORTS_ROOT" ]]; then
  echo "SKIP: $REPORTS_ROOT not found."
  exit 0
fi

python3 - "$ROOT" "${1:-}" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
reports_root = root / "backend" / "parse-server" / "cloud" / "functions" / "admin" / "reports"

mode = "changed"
if len(sys.argv) > 2 and sys.argv[2] == "--all":
    mode = "all"

allowed_files = {
    "backend/parse-server/cloud/functions/admin/reports/summaryReportAggregateKey.js",
}

pattern = re.compile(r"\brow(?:\?\.)?\.(?:_id|objectId)\b")
violations = []

def all_report_files():
    out = []
    for p in sorted(reports_root.rglob("*.js")):
        rel = p.relative_to(root).as_posix()
        if "/__tests__/" in rel:
            continue
        if p.name.endswith(".test.js") or p.name.endswith(".spec.js"):
            continue
        out.append(rel)
    return out

if mode == "all":
    files = all_report_files()
else:
    diff = subprocess.run(
        [
            "git", "diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--",
            "backend/parse-server/cloud/functions/admin/reports/**/*.js",
        ],
        cwd=root,
        text=True,
        capture_output=True,
        check=True,
    )
    files = [line.strip() for line in diff.stdout.splitlines() if line.strip()]
    if not files:
        print("OK: no changed admin report files to validate.")
        sys.exit(0)

for rel in files:
    if rel in allowed_files:
        continue
    p = root / rel
    if not p.exists() or not p.is_file():
        continue
    content = p.read_text(encoding="utf-8", errors="ignore")
    for idx, line in enumerate(content.splitlines(), start=1):
        if pattern.search(line):
            violations.append(f"{rel}:{idx}: direct aggregate key access '{line.strip()}'")

if violations:
    print("ERROR: direct aggregate key access detected.")
    print("Use readAggregateGroupKey() or readAggregateGroupPayload() from summaryReportAggregateKey.js")
    for v in violations:
        print(f" - {v}")
    sys.exit(1)

print("OK: aggregate key access guard passed.")
PY
