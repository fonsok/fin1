#!/usr/bin/env python3
"""
Seed FIN1 Parse `TermsContent` documents (terms/privacy/imprint) with minimal content.

Runs on the FIN1 Ubuntu server and reads secrets from:
  /home/io/fin1-server/backend/.env

This script is intentionally minimal and safe:
- It only creates a document if no active one exists for (documentType, language).
- It prints created objectIds, but never prints secrets.
"""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlencode
import urllib.request


def _unquote(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
        return v[1:-1]
    return v


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if (not line) or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = _unquote(v)
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
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def post(self, path: str, payload: dict) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base}{path}", data=data, headers=self.headers, method="POST"
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    env_path = Path("/home/io/fin1-server/backend/.env")
    if not env_path.exists():
        raise SystemExit(f"Missing {env_path}")

    env = load_env(env_path)
    app_id = env.get("PARSE_SERVER_APPLICATION_ID") or env.get("PARSE_APPLICATION_ID")
    master_key = env.get("PARSE_SERVER_MASTER_KEY") or env.get("PARSE_MASTER_KEY")
    if not app_id or not master_key:
        raise SystemExit("Missing PARSE_SERVER_APPLICATION_ID or PARSE_SERVER_MASTER_KEY in .env")

    client = ParseClient(base="http://127.0.0.1:1338/parse", app_id=app_id, master_key=master_key)

    seeds = [
        # Terms (DE/EN)
        {
            "documentType": "terms",
            "language": "de",
            "version": "1.0",
            "effectiveDate": {"__type": "Date", "iso": "2024-01-01T00:00:00.000Z"},
            "isActive": True,
            "sections": [
                {
                    "id": "intro",
                    "title": "Nutzungsbedingungen",
                    "content": "Seed (Server-driven). Provision: {{COMMISSION_RATE}}%.",
                    "icon": "doc.text",
                }
            ],
        },
        {
            "documentType": "terms",
            "language": "en",
            "version": "1.0",
            "effectiveDate": {"__type": "Date", "iso": "2024-01-01T00:00:00.000Z"},
            "isActive": True,
            "sections": [
                {
                    "id": "intro",
                    "title": "Terms of Service",
                    "content": "Seed (server-driven). Commission: {{COMMISSION_RATE}}%.",
                    "icon": "doc.text",
                }
            ],
        },
        # Privacy (DE/EN)
        {
            "documentType": "privacy",
            "language": "de",
            "version": "1.0",
            "effectiveDate": {"__type": "Date", "iso": "2024-01-01T00:00:00.000Z"},
            "isActive": True,
            "sections": [
                {
                    "id": "intro",
                    "title": "Datenschutzerklärung",
                    "content": "Seed (Server-driven).",
                    "icon": "hand.raised",
                }
            ],
        },
        {
            "documentType": "privacy",
            "language": "en",
            "version": "1.0",
            "effectiveDate": {"__type": "Date", "iso": "2024-01-01T00:00:00.000Z"},
            "isActive": True,
            "sections": [
                {
                    "id": "intro",
                    "title": "Privacy Policy",
                    "content": "Seed (server-driven).",
                    "icon": "hand.raised",
                }
            ],
        },
        # Imprint (DE) – optional (UI can be added later)
        {
            "documentType": "imprint",
            "language": "de",
            "version": "1.0",
            "effectiveDate": {"__type": "Date", "iso": "2024-01-01T00:00:00.000Z"},
            "isActive": True,
            "sections": [
                {
                    "id": "imprint",
                    "title": "Impressum",
                    "content": "Seed (server-driven). Bitte ersetzen durch die echten Angaben.",
                    "icon": "building.2",
                }
            ],
        },
    ]

    for seed in seeds:
        where = json.dumps(
            {
                "documentType": seed["documentType"],
                "language": seed["language"],
                "isActive": True,
            }
        )
        existing = client.get("/classes/TermsContent", params={"where": where, "limit": 1})
        if existing.get("results"):
            print(f"SKIP {seed['documentType']} {seed['language']}: active exists")
            continue
        created = client.post("/classes/TermsContent", seed)
        print(f"CREATED {seed['documentType']} {seed['language']} objectId={created.get('objectId')}")

    print("DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

