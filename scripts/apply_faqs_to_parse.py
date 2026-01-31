#!/usr/bin/env python3
"""
Apply exported FAQ JSON to Parse classes `FAQCategory` and `FAQ`.

Runs on the FIN1 Ubuntu server (expects):
  /home/io/fin1-server/backend/.env   (contains Parse Application ID + Master Key)
  Parse available locally at:         http://127.0.0.1:1338/parse

Input:
  A JSON file produced by `export_faqs_from_swift.py`.
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


def upsert_category(client: ParseClient, category: dict) -> str:
    slug = category["slug"]
    where = json.dumps({"slug": slug})
    res = client.get("/classes/FAQCategory", params={"where": where, "limit": 1})
    results = res.get("results") or []

    payload = {
        "slug": slug,
        "title": category.get("title") or category.get("displayName") or slug,
        "displayName": category.get("displayName") or category.get("title") or slug,
        "icon": category.get("icon") or "",
        "sortOrder": int(category.get("sortOrder") or 0),
        "isActive": bool(category.get("isActive", True)),
        "showOnLanding": bool(category.get("showOnLanding", False)),
        "showInHelpCenter": bool(category.get("showInHelpCenter", False)),
        "showInCSR": bool(category.get("showInCSR", False)),
    }

    if results:
        obj_id = results[0]["objectId"]
        client.put(f"/classes/FAQCategory/{obj_id}", payload)
        return obj_id

    created = client.post("/classes/FAQCategory", payload)
    return created["objectId"]


def upsert_faq(client: ParseClient, faq: dict, category_id_by_slug: dict[str, str]) -> str:
    faq_id = faq["faqId"]
    cat_slug = faq["categorySlug"]
    category_id = category_id_by_slug[cat_slug]

    where = json.dumps({"faqId": faq_id})
    res = client.get("/classes/FAQ", params={"where": where, "limit": 1})
    results = res.get("results") or []

    payload = {
        "faqId": faq_id,
        "question": faq["question"],
        "answer": faq["answer"],
        # Store as string (matches current cloud function filter logic)
        "categoryId": category_id,
        "sortOrder": int(faq.get("sortOrder") or 0),
        "isPublished": bool(faq.get("isPublished", True)),
        "isArchived": bool(faq.get("isArchived", False)),
        "isPublic": bool(faq.get("isPublic", True)),
        "isUserVisible": bool(faq.get("isUserVisible", True)),
        "source": faq.get("source") or "seed",
    }

    if results:
        obj_id = results[0]["objectId"]
        client.put(f"/classes/FAQ/{obj_id}", payload)
        return obj_id

    created = client.post("/classes/FAQ", payload)
    return created["objectId"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()

    env = load_env(Path("/home/io/fin1-server/backend/.env"))
    app_id = env.get("PARSE_SERVER_APPLICATION_ID") or env.get("PARSE_APPLICATION_ID")
    master_key = env.get("PARSE_SERVER_MASTER_KEY") or env.get("PARSE_MASTER_KEY")
    if not app_id or not master_key:
        raise SystemExit("Missing PARSE_SERVER_APPLICATION_ID or PARSE_SERVER_MASTER_KEY in server .env")

    client = ParseClient(base="http://127.0.0.1:1338/parse", app_id=app_id, master_key=master_key)

    payload = json.loads(args.input.read_text(encoding="utf-8"))
    categories = payload.get("categories") or []
    faqs = payload.get("faqs") or []
    if not categories or not faqs:
        raise SystemExit("Input JSON must contain non-empty 'categories' and 'faqs'")

    category_id_by_slug: dict[str, str] = {}
    for cat in categories:
        obj_id = upsert_category(client, cat)
        category_id_by_slug[cat["slug"]] = obj_id
        print(f"UPSERT FAQCategory slug={cat['slug']} objectId={obj_id}")

    for faq in faqs:
        obj_id = upsert_faq(client, faq, category_id_by_slug=category_id_by_slug)
        print(f"UPSERT FAQ faqId={faq['faqId']} objectId={obj_id}")

    print("DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

