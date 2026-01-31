#!/usr/bin/env python3
"""
Clone active Parse `TermsContent` into a new immutable version.

Why:
- Backend/audit clean: Legal docs are append-only (no in-place edits).
- Creates a new TermsContent record, then deactivates the previous active one.

Runs on the FIN1 Ubuntu server (expects):
  /home/io/fin1-server/backend/.env   (contains Parse Application ID + Master Key)
  Parse available locally at:         http://127.0.0.1:1338/parse
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
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
    # Fallback: append .1
    return f"{v}.1"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def clone_one(client: ParseClient, document_type: str, language: str, new_version: str | None) -> None:
    where = json.dumps({"documentType": document_type, "language": language, "isActive": True})
    res = client.get("/classes/TermsContent", params={"where": where, "limit": 1, "order": "-effectiveDate"})
    results = res.get("results") or []
    if not results:
        raise SystemExit(f"No active TermsContent found for documentType={document_type} language={language}")

    active = results[0]
    active_id = active["objectId"]

    current_version = (active.get("version") or "").strip()
    target_version = new_version.strip() if new_version else bump_version(current_version)

    payload = {
        "version": target_version,
        "language": language,
        "documentType": document_type,
        "effectiveDate": {"__type": "Date", "iso": now_iso()},
        "isActive": True,
        "sections": active.get("sections") or [],
    }

    created = client.post("/classes/TermsContent", payload)
    new_id = created["objectId"]

    # Deactivate previous active
    client.put(f"/classes/TermsContent/{active_id}", {"isActive": False})

    print(
        f"CLONED TermsContent {document_type} {language}: {active_id} ({current_version}) -> {new_id} ({target_version})"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--document-type", required=True, choices=["terms", "privacy", "imprint"])
    parser.add_argument("--language", required=True, choices=["en", "de"])
    parser.add_argument("--new-version", default=None, help="Optional explicit version (e.g. 1.0.1)")
    args = parser.parse_args()

    env = load_env(Path("/home/io/fin1-server/backend/.env"))
    app_id = env.get("PARSE_SERVER_APPLICATION_ID") or env.get("PARSE_APPLICATION_ID")
    master_key = env.get("PARSE_SERVER_MASTER_KEY") or env.get("PARSE_MASTER_KEY")
    if not app_id or not master_key:
        raise SystemExit("Missing PARSE_SERVER_APPLICATION_ID or PARSE_SERVER_MASTER_KEY in server .env")

    client = ParseClient(base="http://127.0.0.1:1338/parse", app_id=app_id, master_key=master_key)
    clone_one(client, args.document_type, args.language, args.new_version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

