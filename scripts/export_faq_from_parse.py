#!/usr/bin/env python3
"""
Export FAQCategory + FAQ from Parse into the repo JSON shape used by
`apply_faqs_to_parse.py` and tracked as `scripts/faq_export.json`.

Use after `forceReseedFAQData` and/or Admin-Portal edits so Git matches the DB.

Environment (optional file: --env-file, default ../backend/.env from scripts/):
  PARSE_SERVER_APPLICATION_ID  (or PARSE_APPLICATION_ID)
  PARSE_SERVER_MASTER_KEY      (or PARSE_MASTER_KEY)

CLI overrides:
  --parse-url   Base URL including /parse (default: http://127.0.0.1:1338/parse)

Example:
  cd scripts
  python3 export_faq_from_parse.py --output faq_export.json
  python3 export_faq_from_parse.py --parse-url https://192.168.178.24/parse --env-file ../backend/.env
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode
import ssl
import urllib.error
import urllib.request


def load_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.is_file():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.strip().strip('"').strip("'")
        env[k.strip()] = v
    return env


def pointer_object_id(value) -> str | None:
    if isinstance(value, dict) and value.get("__type") == "Pointer":
        return value.get("objectId")
    if isinstance(value, str) and value:
        return value
    return None


def _ssl_context(insecure: bool) -> ssl.SSLContext | None:
    if not insecure:
        return None
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


class ParseClient:
    def __init__(self, base: str, app_id: str, master_key: str, *, insecure_tls: bool = False) -> None:
        self.base = base.rstrip("/")
        self._ssl = _ssl_context(insecure_tls)
        self.headers = {
            "X-Parse-Application-Id": app_id,
            "X-Parse-Master-Key": master_key,
            "Content-Type": "application/json",
        }

    def get_classes(self, class_name: str, limit: int = 500) -> list[dict]:
        out: list[dict] = []
        skip = 0
        while True:
            qs = urlencode({"limit": limit, "skip": skip, "order": "sortOrder"})
            url = f"{self.base}/classes/{class_name}?{qs}"
            req = urllib.request.Request(url, headers=self.headers, method="GET")
            try:
                with urllib.request.urlopen(req, timeout=60, context=self._ssl) as resp:
                    batch = json.loads(resp.read().decode("utf-8"))
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", errors="replace")
                raise SystemExit(f"Parse HTTP {e.code} for {class_name}: {body}") from e
            rows = batch.get("results") or []
            out.extend(rows)
            if len(rows) < limit:
                break
            skip += limit
        return out


def normalize_category(row: dict) -> dict:
    return {
        "slug": row.get("slug") or "",
        "title": row.get("title") or row.get("displayName") or "",
        "displayName": row.get("displayName") or row.get("title") or "",
        "icon": row.get("icon") or "",
        "sortOrder": int(row.get("sortOrder") or 0),
        "isActive": bool(row.get("isActive", True)),
        "showOnLanding": bool(row.get("showOnLanding", False)),
        "showInHelpCenter": bool(row.get("showInHelpCenter", False)),
        "showInCSR": bool(row.get("showInCSR", True)),
    }


def primary_category_id(faq: dict) -> str | None:
    ids = faq.get("categoryIds")
    if isinstance(ids, list) and ids:
        first = ids[0]
        return pointer_object_id(first) or (first if isinstance(first, str) else None)
    return pointer_object_id(faq.get("categoryId"))


def normalize_faq(row: dict, slug_by_category_object_id: dict[str, str]) -> dict | None:
    faq_id = (row.get("faqId") or "").strip()
    if not faq_id:
        return None
    cat_oid = primary_category_id(row)
    if not cat_oid:
        return None
    slug = slug_by_category_object_id.get(cat_oid)
    if not slug:
        return None

    out: dict = {
        "faqId": faq_id,
        "question": row.get("question") or "",
        "answer": row.get("answer") or "",
        "categorySlug": slug,
        "sortOrder": int(row.get("sortOrder") or 0),
        "isPublished": bool(row.get("isPublished", True)),
        "isArchived": bool(row.get("isArchived", False)),
        "isPublic": bool(row.get("isPublic", False)),
        "isUserVisible": bool(row.get("isUserVisible", True)),
        "source": row.get("source") or "seed",
    }
    if row.get("questionEn"):
        out["questionEn"] = row["questionEn"]
    if row.get("answerEn"):
        out["answerEn"] = row["answerEn"]
    tr = row.get("targetRoles")
    if isinstance(tr, list) and tr:
        out["targetRoles"] = tr
    ctx = row.get("contexts")
    if isinstance(ctx, list) and ctx:
        out["contexts"] = ctx
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Export Parse FAQs to repo JSON.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "faq_export.json",
        help="Output file (default: scripts/faq_export.json)",
    )
    parser.add_argument(
        "--parse-url",
        default=os.environ.get("PARSE_EXPORT_URL", "http://127.0.0.1:1338/parse"),
        help="Parse API base URL ending with /parse",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "backend" / ".env",
        help="Path to backend .env for application id and master key",
    )
    parser.add_argument(
        "--filter-source",
        default="",
        help="If set, only export FAQs where source equals this string (e.g. help_center)",
    )
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Do not verify TLS (self-signed cert, e.g. https://localhost:8443 via SSH -L)",
    )
    args = parser.parse_args()

    file_env = load_env_file(args.env_file)
    app_id = (
        os.environ.get("PARSE_SERVER_APPLICATION_ID")
        or os.environ.get("PARSE_APPLICATION_ID")
        or file_env.get("PARSE_SERVER_APPLICATION_ID")
        or file_env.get("PARSE_APPLICATION_ID")
    )
    master_key = (
        os.environ.get("PARSE_SERVER_MASTER_KEY")
        or os.environ.get("PARSE_MASTER_KEY")
        or file_env.get("PARSE_SERVER_MASTER_KEY")
        or file_env.get("PARSE_MASTER_KEY")
    )
    if not app_id or not master_key:
        print(
            "Missing Parse credentials. Set PARSE_SERVER_APPLICATION_ID and "
            "PARSE_SERVER_MASTER_KEY in the environment or in backend/.env",
            file=sys.stderr,
        )
        return 1

    client = ParseClient(args.parse_url, app_id, master_key, insecure_tls=args.insecure)
    raw_cats = client.get_classes("FAQCategory")
    raw_faqs = client.get_classes("FAQ")

    slug_by_oid = {}
    categories_out = []
    for row in raw_cats:
        oid = row.get("objectId")
        slug = (row.get("slug") or "").strip().lower()
        if oid and slug:
            slug_by_oid[oid] = slug
        categories_out.append(normalize_category(row))

    categories_out.sort(key=lambda c: (c.get("sortOrder", 0), c.get("slug", "")))

    faqs_out = []
    for row in raw_faqs:
        n = normalize_faq(row, slug_by_oid)
        if n is None:
            continue
        if args.filter_source and n.get("source") != args.filter_source:
            continue
        faqs_out.append(n)

    faqs_out.sort(key=lambda f: (f.get("sortOrder", 0), f.get("faqId", "")))

    payload = {
        "exportedAt": datetime.now(timezone.utc).isoformat(),
        "exportNote": "Generated by scripts/export_faq_from_parse.py — import with apply_faqs_to_parse.py or Admin importFAQBackup (format differs).",
        "categories": categories_out,
        "faqs": faqs_out,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(categories_out)} categories, {len(faqs_out)} FAQs → {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
