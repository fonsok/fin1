#!/usr/bin/env python3
"""File size baseline: grandfather existing large Swift files, block growth and new violations."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FIN1_ROOT = REPO_ROOT / "FIN1"
BASELINE_PATH = REPO_ROOT / "scripts" / "file-size-baseline.json"

MAX_NEW_FILE_LINES = 300
MAX_FUNCTION_LINES = 50
BASELINE_GROWTH_SLACK = 5
BASELINE_VERSION = 1

# Static legal copy — splitting reduces clarity (architecture.md exception).
EXEMPT_GLOBS = [
    "FIN1/Shared/Data/*PrivacyPolicy*",
    "FIN1/Shared/Data/*TermsOfService*",
]

SKIP_PATH_PARTS = frozenset({"Tests", "Preview", "Extension"})


def iter_swift_files() -> list[str]:
    paths: list[str] = []
    for path in sorted(FIN1_ROOT.rglob("*.swift")):
        if any(part in SKIP_PATH_PARTS for part in path.parts):
            continue
        paths.append(path.relative_to(REPO_ROOT).as_posix())
    return paths


def is_exempt(rel_path: str) -> bool:
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in EXEMPT_GLOBS)


def line_count(rel_path: str) -> int:
    text = (REPO_ROOT / rel_path).read_text(encoding="utf-8", errors="replace")
    if not text:
        return 0
    return len(text.splitlines())


def load_baseline() -> dict:
    if not BASELINE_PATH.is_file():
        print(f"❌ Missing baseline: {BASELINE_PATH}", file=sys.stderr)
        print("   Run: ./scripts/generate-file-size-baseline.sh", file=sys.stderr)
        sys.exit(1)
    return json.loads(BASELINE_PATH.read_text(encoding="utf-8"))


def cmd_generate() -> int:
    grandfathered: dict[str, int] = {}
    for rel in iter_swift_files():
        count = line_count(rel)
        if count > MAX_NEW_FILE_LINES:
            grandfathered[rel] = count

    payload = {
        "version": BASELINE_VERSION,
        "max_new_file_lines": MAX_NEW_FILE_LINES,
        "baseline_growth_slack": BASELINE_GROWTH_SLACK,
        "exempt_globs": EXEMPT_GLOBS,
        "files": grandfathered,
    }
    BASELINE_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"✅ Wrote {len(grandfathered)} grandfathered files to {BASELINE_PATH.relative_to(REPO_ROOT)}")
    exempt_count = sum(1 for rel in iter_swift_files() if is_exempt(rel))
    print(f"   Exempt (not in baseline): {exempt_count} file(s) matching legal static globs")
    return 0


def check_functions_strict(swift_files: list[str]) -> list[str]:
    """Approximate per-function line limits (strict mode only)."""
    violations: list[str] = []
    decl_re = re.compile(r"^\s*(?:@\w+\s+)*func\s+\w+", re.MULTILINE)
    next_decl_re = re.compile(
        r"^\s*(?:func|class|struct|enum|extension|init|var|let)\s+",
        re.MULTILINE,
    )

    for rel in swift_files:
        if is_exempt(rel):
            continue
        content = (REPO_ROOT / rel).read_text(encoding="utf-8", errors="replace")
        lines = content.splitlines()
        for match in decl_re.finditer(content):
            start_line = content[: match.start()].count("\n") + 1
            rest = content[match.end() :]
            next_match = next_decl_re.search(rest)
            if next_match:
                end_line = start_line + rest[: next_match.start()].count("\n")
            else:
                end_line = len(lines)
            func_lines = end_line - start_line + 1
            if func_lines > MAX_FUNCTION_LINES:
                name_match = re.search(r"func\s+(\w+)", match.group())
                name = name_match.group(1) if name_match else "?"
                violations.append(
                    f"⚠️  {rel}:{start_line} function '{name}': {func_lines} lines "
                    f"(exceeds {MAX_FUNCTION_LINES} line limit)"
                )
    return violations


def cmd_check(mode: str) -> int:
    baseline_data = load_baseline() if mode == "baseline" else None
    grandfathered: dict[str, int] = {}
    slack = BASELINE_GROWTH_SLACK
    if baseline_data:
        grandfathered = baseline_data.get("files", {})
        slack = int(baseline_data.get("baseline_growth_slack", BASELINE_GROWTH_SLACK))

    swift_files = iter_swift_files()
    violations: list[str] = []

    print("🔍 Checking file sizes…")
    print(f"   Mode: {mode}")
    if mode == "baseline":
        print(f"   New files: ≤ {MAX_NEW_FILE_LINES} lines")
        print(f"   Grandfathered: no growth > +{slack} lines vs baseline")
        print(f"   Exempt globs: {', '.join(EXEMPT_GLOBS)}")
    else:
        print(f"   All files: ≤ {MAX_NEW_FILE_LINES} lines")
    print()

    for rel in swift_files:
        if is_exempt(rel):
            continue

        count = line_count(rel)

        if mode == "baseline":
            if rel in grandfathered:
                allowed = grandfathered[rel] + slack
                if count > allowed:
                    violations.append(
                        f"❌ {rel}: {count} lines (baseline {grandfathered[rel]} + slack {slack} = {allowed} max)"
                    )
            elif count > MAX_NEW_FILE_LINES:
                violations.append(
                    f"❌ {rel}: {count} lines (new file; limit {MAX_NEW_FILE_LINES})"
                )
        elif count > MAX_NEW_FILE_LINES:
            violations.append(
                f"❌ {rel}: {count} lines (exceeds {MAX_NEW_FILE_LINES} line limit)"
            )

    if violations:
        print("📋 File size violations:")
        for line in violations:
            print(line)
            print("   💡 Split file or regenerate baseline only after intentional refactor")
        print()

    function_violations: list[str] = []
    if mode == "strict":
        print(f"📋 Checking function sizes (limit: {MAX_FUNCTION_LINES} lines)…")
        function_violations = check_functions_strict(swift_files)
        for line in function_violations:
            print(line)
        if function_violations:
            print()

    total = len(violations) + len(function_violations)
    if total == 0:
        print("✅ File size validation passed!")
        return 0

    print(f"❌ Found {total} violation(s)")
    print()
    print("📖 See .cursor/rules/architecture.md and scripts/file-size-baseline.json")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="FIN1 Swift file size baseline tooling")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("generate", help="Write scripts/file-size-baseline.json from current tree")

    check_parser = sub.add_parser("check", help="Validate file sizes")
    check_parser.add_argument(
        "--mode",
        choices=("baseline", "strict"),
        default="baseline",
        help="baseline=CI (grandfather + no growth); strict=all files ≤300",
    )

    args = parser.parse_args()
    if args.command == "generate":
        return cmd_generate()
    return cmd_check(args.mode)


if __name__ == "__main__":
    sys.exit(main())
