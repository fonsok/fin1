#!/usr/bin/env python3
"""
Deploy updated legal sections to Parse `TermsContent` as new immutable versions.

Audit-safe: creates NEW TermsContent records (never edits existing ones),
then deactivates the previous active version.

Optional maintenance (dangerous / audit-sensitive):
- `--purge-inactive-after` can hard-delete historical inactive rows via Parse REST DELETE.
  This requires Parse Cloud `TermsContent` delete guardrails to be explicitly enabled on the server:
  - `ALLOW_LEGAL_HARD_DELETE=true`
  - `ALLOW_LEGAL_MASTER_DELETE_NON_ACTIVE_TERMSCONTENT=true`
  - plus the existing production gate (`NODE_ENV` / `ALLOW_LEGAL_HARD_DELETE_IN_PRODUCTION`)

Runs on the FIN1 Ubuntu server (expects):
  /home/io/fin1-server/backend/.env   (contains Parse Application ID + Master Key)
  Parse available locally at:         http://127.0.0.1:1338/parse

Input:
  A directory containing JSON files produced by `export_legal_sections_from_swift.py`.
  Each JSON has: { "documentType": "...", "language": "...", "sections": [...] }
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode
import urllib.request


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if (not line) or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.strip().strip('"').strip("'")
        env[k.strip()] = v
    return env


class ParseClient:
    def __init__(self, base: str, app_id: str, master_key: str) -> None:
        self.base = base.rstrip("/")
        self.headers = {
            "X-Parse-Application-Id": app_id,
            "X-Parse-Master-Key": master_key,
            "Content-Type": "application/json",
        }

    def get(self, path: str, params: dict | None = None) -> dict:
        url = f"{self.base}{path}"
        if params:
            url = f"{url}?{urlencode(params)}"
        req = urllib.request.Request(url, headers=self.headers, method="GET")
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def post(self, path: str, payload: dict) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base}{path}", data=data, headers=self.headers, method="POST"
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def put(self, path: str, payload: dict) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base}{path}", data=data, headers=self.headers, method="PUT"
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def delete(self, path: str) -> None:
        req = urllib.request.Request(f"{self.base}{path}", headers=self.headers, method="DELETE")
        with urllib.request.urlopen(req, timeout=30) as resp:
            _ = resp.read()


def bump_version(version: str) -> str:
    v = version.strip()
    if not v:
        return "1.0.1"
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)$", v)
    if m:
        major, minor, patch = map(int, m.groups())
        return f"{major}.{minor}.{patch + 1}"
    m = re.match(r"^(\d+)\.(\d+)$", v)
    if m:
        major, minor = map(int, m.groups())
        return f"{major}.{minor}.1"
    return f"{v}.1"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_expected_section_counts(raw: str | None) -> dict[str, int]:
    """
    Format: "terms_de=34,terms_en=34,privacy_de=17"
    Keys are export filenames without extension, e.g. "terms_de".
    """
    if not raw:
        return {}
    out: dict[str, int] = {}
    for part in raw.split(","):
        item = part.strip()
        if not item:
            continue
        if "=" not in item:
            raise SystemExit(f"Invalid --expect-section-count entry (missing '='): {item!r}")
        k, v = item.split("=", 1)
        k = k.strip()
        v = v.strip()
        if not k:
            raise SystemExit(f"Invalid --expect-section-count entry (empty key): {item!r}")
        try:
            n = int(v)
        except ValueError as e:
            raise SystemExit(f"Invalid --expect-section-count value for {k!r}: {v!r}") from e
        if n <= 0:
            raise SystemExit(f"Invalid --expect-section-count value for {k!r}: must be > 0")
        out[k] = n
    return out


def deploy_one(client: ParseClient, payload: dict, new_version: str | None, reason: str, deployed_by: str) -> str:
    doc_type = payload["documentType"]
    lang = payload["language"]
    new_sections = payload["sections"]

    if not isinstance(new_sections, list) or not new_sections:
        raise SystemExit(f"sections must be a non-empty array for {doc_type} {lang}")

    where = json.dumps({"documentType": doc_type, "language": lang, "isActive": True})
    res = client.get("/classes/TermsContent", params={"where": where, "limit": 1, "order": "-effectiveDate"})
    results = res.get("results") or []
    if not results:
        print(f"  WARNING: No active TermsContent found for {doc_type} {lang} — creating initial version")
        current_version = "0.0"
        active_id = None
        old_hash = None
    else:
        active = results[0]
        active_id = active["objectId"]
        current_version = (active.get("version") or "").strip()
        old_hash = active.get("documentHash")

    target_version = new_version.strip() if new_version else bump_version(current_version)

    create_payload = {
        "version": target_version,
        "language": lang,
        "documentType": doc_type,
        "effectiveDate": {"__type": "Date", "iso": now_iso()},
        "isActive": True,
        "sections": new_sections,
    }

    created = client.post("/classes/TermsContent", create_payload)
    new_id = created["objectId"]

    if active_id:
        client.put(f"/classes/TermsContent/{active_id}", {"isActive": False})

    # GoB-compliant: create AuditLog entry for the deployment
    audit_payload = {
        "logType": "legal",
        "action": "legal_document_deployed_via_script",
        "resourceType": "TermsContent",
        "resourceId": new_id,
        "oldValues": {
            "previousObjectId": active_id,
            "previousVersion": current_version,
            "previousDocumentHash": old_hash,
        },
        "newValues": {
            "newObjectId": new_id,
            "newVersion": target_version,
            "language": lang,
            "documentType": doc_type,
            "sectionCount": len(new_sections),
        },
        "metadata": {
            "deployedBy": deployed_by,
            "reason": reason,
            "deployedAt": now_iso(),
            "source": "deploy_updated_legal_docs.py",
            "scriptVersion": "1.0.0",
        },
    }
    try:
        client.post("/classes/AuditLog", audit_payload)
        print(f"  AUDIT  {doc_type} {lang}: AuditLog entry created for deployment")
    except Exception as e:
        print(f"  WARNING: Failed to create AuditLog entry: {e}")

    print(f"  DEPLOYED {doc_type} {lang}: {active_id or '(none)'} ({current_version}) -> {new_id} ({target_version}) [{len(new_sections)} sections]")
    return new_id


def purge_inactive_termscontent(
    client: ParseClient,
    *,
    document_type: str | None,
    language: str | None,
) -> int:
    where: dict = {"isActive": False}
    if document_type:
        where["documentType"] = document_type
    if language:
        where["language"] = language

    deleted = 0
    page = 200
    # Always fetch page 1 again: deleting shifts results, `skip` pagination would miss rows.
    while True:
        params = {"where": json.dumps(where), "limit": page, "order": "createdAt"}
        res = client.get("/classes/TermsContent", params=params)
        batch = res.get("results") or []
        if not batch:
            break
        for row in batch:
            oid = row.get("objectId")
            if not oid:
                continue
            client.delete(f"/classes/TermsContent/{oid}")
            deleted += 1
    return deleted


def main() -> int:
    parser = argparse.ArgumentParser(description="Deploy updated legal docs to Parse TermsContent")
    parser.add_argument("--input-dir", type=Path, required=True,
                        help="Directory with JSON files from export_legal_sections_from_swift.py")
    parser.add_argument("--new-version", default=None,
                        help="Explicit version string (default: auto-bump patch)")
    parser.add_argument("--only", default=None,
                        help="Only deploy specific files (comma-separated, e.g. 'terms_en,terms_de')")
    parser.add_argument("--reason", required=True,
                        help="Reason for this deployment (required for audit trail / GoB compliance)")
    parser.add_argument("--deployed-by", required=True,
                        help="Name or identifier of the person deploying (required for audit trail)")
    parser.add_argument(
        "--expect-section-count",
        default=None,
        help=(
            "Fail if section counts don't match. Example: "
            "'terms_de=34,terms_en=34'. Keys are JSON stems like 'terms_de'."
        ),
    )
    parser.add_argument(
        "--purge-inactive-after",
        action="store_true",
        help=(
            "After deployment, hard-delete inactive TermsContent rows via Parse REST DELETE. "
            "Requires server env: ALLOW_LEGAL_HARD_DELETE=true AND "
            "ALLOW_LEGAL_MASTER_DELETE_NON_ACTIVE_TERMSCONTENT=true (and production override rules)."
        ),
    )
    parser.add_argument(
        "--purge-inactive-scope",
        choices=["deployed-only", "all"],
        default="deployed-only",
        help=(
            "Which inactive rows to purge after deploy. "
            "'deployed-only' purges per deployed (documentType,language). "
            "'all' purges every inactive TermsContent row."
        ),
    )
    args = parser.parse_args()

    env = load_env(Path("/home/io/fin1-server/backend/.env"))
    app_id = env.get("PARSE_SERVER_APPLICATION_ID") or env.get("PARSE_APPLICATION_ID")
    master_key = env.get("PARSE_SERVER_MASTER_KEY") or env.get("PARSE_MASTER_KEY")
    if not app_id or not master_key:
        raise SystemExit("Missing PARSE_SERVER_APPLICATION_ID or PARSE_SERVER_MASTER_KEY in server .env")

    client = ParseClient(base="http://127.0.0.1:1338/parse", app_id=app_id, master_key=master_key)

    input_dir: Path = args.input_dir
    files = sorted(input_dir.glob("*.json"))
    if not files:
        raise SystemExit(f"No JSON files found in {input_dir}")

    expected = parse_expected_section_counts(args.expect_section_count)

    only_filter = None
    if args.only:
        only_filter = {s.strip() for s in args.only.split(",")}

    print(f"Deploying legal docs from {input_dir} ...")
    print(f"  Reason: {args.reason}")
    print(f"  Deployed by: {args.deployed_by}")

    deployed_keys: list[tuple[str, str]] = []

    for fp in files:
        stem = fp.stem
        if only_filter and stem not in only_filter:
            print(f"  SKIPPED {fp.name} (not in --only filter)")
            continue
        payload = json.loads(fp.read_text(encoding="utf-8"))
        sections = payload.get("sections")
        if stem in expected:
            if not isinstance(sections, list):
                raise SystemExit(f"{fp.name}: sections must be a list")
            if len(sections) != expected[stem]:
                raise SystemExit(
                    f"{fp.name}: expected {expected[stem]} sections, got {len(sections)} "
                    f"(remove/adjust --expect-section-count or fix export)"
                )
        deploy_one(client, payload, args.new_version, args.reason, args.deployed_by)
        deployed_keys.append((payload["documentType"], payload["language"]))

    if args.purge_inactive_after:
        hard = str(env.get("ALLOW_LEGAL_HARD_DELETE", "")).lower() == "true"
        master_del = str(env.get("ALLOW_LEGAL_MASTER_DELETE_NON_ACTIVE_TERMSCONTENT", "")).lower() == "true"
        if not hard or not master_del:
            raise SystemExit(
                "Refusing --purge-inactive-after: set in server .env:\n"
                "  ALLOW_LEGAL_HARD_DELETE=true\n"
                "  ALLOW_LEGAL_MASTER_DELETE_NON_ACTIVE_TERMSCONTENT=true\n"
                "(and production override rules as enforced by Parse Cloud beforeDelete)"
            )

        print("Purging inactive TermsContent rows ...")
        total_deleted = 0
        if args.purge_inactive_scope == "all":
            total_deleted += purge_inactive_termscontent(client, document_type=None, language=None)
        else:
            # de-dupe keys while keeping stable order
            seen: set[tuple[str, str]] = set()
            for doc_type, lang in deployed_keys:
                key = (doc_type, lang)
                if key in seen:
                    continue
                seen.add(key)
                deleted = purge_inactive_termscontent(client, document_type=doc_type, language=lang)
                print(f"  PURGED inactive {doc_type} {lang}: deleted={deleted}")
                total_deleted += deleted
        print(f"  PURGE DONE: deleted={total_deleted}")

    print("DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
