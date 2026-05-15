#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLOUD_ROOT="$ROOT/backend/parse-server/cloud"

if [[ ! -d "$CLOUD_ROOT" ]]; then
  echo "SKIP: $CLOUD_ROOT not found."
  exit 0
fi

python3 - "$ROOT" "${1:-}" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
cloud_root = root / "backend" / "parse-server" / "cloud"

verb_prefixes = (
    "get", "list", "create", "update", "delete", "upsert",
    "confirm", "cancel", "activate", "record", "book",
    "repair", "backfill", "reconcile", "cleanup", "run",
    "calculate", "execute", "place", "discover", "audit",
    "import", "export", "reset", "approve", "reject",
    "withdraw", "request", "search", "send", "verify",
    "enable", "disable", "setup", "mark", "complete",
    "save", "resolve", "close", "assign", "escalate",
    "reply", "respond", "seed", "force", "unlock",
    "terminate", "migrate", "check", "encrypt", "set",
    "log", "render", "review", "regenerate",
    "initialize", "benchmark",
)

bad_path_tokens = ("/tmp/", "/.tmp/", "/backup/", "/copy/")
bad_name_fragments = (".tmp", "backup", "copy", "_old", "old_")
file_name_ok = re.compile(r"^[a-z][A-Za-z0-9]*\.(js|ts)$")
cloud_define = re.compile(r"Parse\.Cloud\.define\(\s*['\"]([A-Za-z0-9_]+)['\"]")
lower_camel = re.compile(r"^[a-z][A-Za-z0-9]*$")

# Öffentliche / Legacy-Cloud-Funktionen ohne passenden Verbprefix (Kompatibilität, Dev-only).
legacy_cloud_function_allowlist = frozenset({
    "traderActivateReservedInvestment",
    "health",
    "testEmailConfig",
    "devResetTradingTestData",
    "devResetLegalDocumentsBaseline",
    "devResetFAQsBaseline",
    "syncCSRRolesFromCanonical",
})

# Dateinamen mit zulässigem „backup“-Substring (fachlicher Name, kein Temp-File).
legacy_filename_fragment_exceptions = frozenset({
    "backend/parse-server/cloud/functions/templates/backupAndMaintenance.js",
    "backend/parse-server/cloud/functions/legal/legalImportExportBackupInput.js",
    "backend/parse-server/cloud/functions/twoFactor/twoFactorRegenerateBackupCodes.js",
})


def collect_all_cloud_source_files():
    """Alle vorhandenen Cloud-Quellen auf der Platte (nicht git ls-files — vermeidet gelöschte Index-Einträge)."""
    out = []
    for p in sorted(cloud_root.rglob("*")):
        if not p.is_file():
            continue
        if p.suffix not in (".js", ".ts"):
            continue
        rel = p.relative_to(root).as_posix()
        rel_slash = f"/{rel}/"
        if "/__tests__/" in rel_slash:
            continue
        if p.name.endswith(".test.js") or p.name.endswith(".spec.js"):
            continue
        out.append(rel)
    return out


mode = "changed"
if len(sys.argv) > 2 and sys.argv[2] == "--all":
    mode = "all"

if mode == "all":
    files = collect_all_cloud_source_files()
else:
    diff = subprocess.run(
        [
            "git",
            "diff",
            "--name-only",
            "--diff-filter=ACMR",
            "HEAD",
            "--",
            "backend/parse-server/cloud/**/*.js",
            "backend/parse-server/cloud/**/*.ts",
        ],
        cwd=root,
        text=True,
        capture_output=True,
        check=True,
    )
    files = [line.strip() for line in diff.stdout.splitlines() if line.strip()]
    if not files:
        print("OK: no changed Parse Cloud JS/TS files to validate.")
        sys.exit(0)

violations = []

def added_define_names_for_file(rel_path: str):
    diff = subprocess.run(
        ["git", "diff", "--unified=0", "HEAD", "--", rel_path],
        cwd=root,
        text=True,
        capture_output=True,
        check=True,
    )
    names = []
    for line in diff.stdout.splitlines():
        if not line.startswith("+") or line.startswith("+++"):
            continue
        m = cloud_define.search(line)
        if m:
            names.append(m.group(1))
    return names

for rel in files:
    p = Path(rel)
    filename = p.name
    rel_norm = "/" + str(p).replace("\\", "/")

    if "/__tests__/" in rel_norm or filename.endswith(".test.js") or filename.endswith(".spec.js"):
        continue

    if any(token in rel_norm for token in bad_path_tokens):
        violations.append(f"[PATH] Legacy/temp path token found: {rel}")

    lower_name = filename.lower()
    if any(fragment in lower_name for fragment in bad_name_fragments):
        if rel not in legacy_filename_fragment_exceptions:
            violations.append(f"[FILE] Legacy/temp filename fragment found: {rel}")

    if not file_name_ok.match(filename):
        violations.append(f"[FILE] Not lowerCamelCase filename: {rel}")

    file_path = root / rel
    try:
        content = file_path.read_text(encoding="utf-8", errors="ignore")
    except Exception as exc:
        violations.append(f"[READ] Could not read {rel}: {exc}")
        continue

    candidate_names = []
    if mode == "all":
        candidate_names = [m.group(1) for m in cloud_define.finditer(content)]
    else:
        candidate_names = added_define_names_for_file(rel)

    for fn_name in candidate_names:
        if fn_name in legacy_cloud_function_allowlist:
            continue
        if not lower_camel.match(fn_name):
            violations.append(f"[CLOUD] Not lowerCamelCase function name '{fn_name}' in {rel}")
            continue
        if not fn_name.startswith(verb_prefixes):
            violations.append(f"[CLOUD] Missing approved verb prefix in '{fn_name}' ({rel})")

if violations:
    print("ERROR: Parse Cloud naming convention violations detected:")
    for v in violations:
        print(f" - {v}")
    print("")
    print("See Documentation/PARSE_CLOUD_NAMING_CONVENTIONS.md")
    sys.exit(1)

print("OK: Parse Cloud naming conventions passed.")
PY
