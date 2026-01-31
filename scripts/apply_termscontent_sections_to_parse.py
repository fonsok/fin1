#!/usr/bin/env python3
"""
Apply one JSON payload to Parse `TermsContent.sections`.

Runs on the FIN1 Ubuntu server (expects):
  /home/io/fin1-server/backend/.env   (contains Parse Application ID + Master Key)
  Parse available locally at:         http://127.0.0.1:1338/parse

Input JSON shape:
  {
    "documentType": "terms" | "privacy" | "imprint",
    "language": "en" | "de",
    "sections": [ { "id": "...", "title": "...", "content": "...", "icon": "..." }, ... ]
  }
"""

from __future__ import annotations

import argparse
import json
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

    def put(self, path: str, payload: dict) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base}{path}", data=data, headers=self.headers, method="PUT"
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()

    env = load_env(Path("/home/io/fin1-server/backend/.env"))
    app_id = env.get("PARSE_SERVER_APPLICATION_ID") or env.get("PARSE_APPLICATION_ID")
    master_key = env.get("PARSE_SERVER_MASTER_KEY") or env.get("PARSE_MASTER_KEY")
    if not app_id or not master_key:
        raise SystemExit("Missing PARSE_SERVER_APPLICATION_ID or PARSE_SERVER_MASTER_KEY in server .env")

    payload = json.loads(args.input.read_text(encoding="utf-8"))
    doc_type = payload["documentType"]
    lang = payload["language"]
    sections = payload["sections"]
    if not isinstance(sections, list) or not sections:
        raise SystemExit("sections must be a non-empty array")

    client = ParseClient(base="http://127.0.0.1:1338/parse", app_id=app_id, master_key=master_key)
    where = json.dumps({"documentType": doc_type, "language": lang, "isActive": True})
    res = client.get("/classes/TermsContent", params={"where": where, "limit": 1, "order": "-effectiveDate"})
    results = res.get("results") or []
    if not results:
        raise SystemExit(f"No active TermsContent found for documentType={doc_type} language={lang}")

    obj_id = results[0]["objectId"]
    client.put(f"/classes/TermsContent/{obj_id}", {"sections": sections})
    print(f"UPDATED TermsContent {doc_type} {lang}: objectId={obj_id} sections={len(sections)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

