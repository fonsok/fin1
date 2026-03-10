#!/usr/bin/env python3
"""
Deploy updated legal sections to Parse `TermsContent` as new immutable versions.

Audit-safe: creates NEW TermsContent records (never edits existing ones),
then deactivates the previous active version.

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


def deploy_one(client: ParseClient, payload: dict, new_version: str | None, reason: str, deployed_by: str) -> None:
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

    only_filter = None
    if args.only:
        only_filter = {s.strip() for s in args.only.split(",")}

    print(f"Deploying legal docs from {input_dir} ...")
    print(f"  Reason: {args.reason}")
    print(f"  Deployed by: {args.deployed_by}")
    for fp in files:
        stem = fp.stem
        if only_filter and stem not in only_filter:
            print(f"  SKIPPED {fp.name} (not in --only filter)")
            continue
        payload = json.loads(fp.read_text(encoding="utf-8"))
        deploy_one(client, payload, args.new_version, args.reason, args.deployed_by)

    print("DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
