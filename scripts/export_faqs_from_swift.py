#!/usr/bin/env python3
"""
Export bundled FAQ content from Swift sources into a JSON payload suitable for seeding Parse.

Runs locally (macOS dev machine) and DOES NOT need any secrets.

Inputs:
  - FIN1/Shared/Data/FAQDataProvider.swift
  - FIN1/Shared/Data/LandingFAQProvider.swift

Output:
  - faq_export.json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class FAQ:
    faqId: str
    question: str
    answer: str
    categoryCase: str  # e.g. "platformOverview"
    source: str        # "landing" | "help_center"
    sortOrder: int


def unescape_swift_string(s: str) -> str:
    # Only handle common Swift escapes; leave \(... ) intact for placeholder conversion.
    s = s.replace("\\r", "\r").replace("\\n", "\n").replace("\\t", "\t")
    s = s.replace('\\"', '"').replace("\\\\", "\\")
    return s


def replace_placeholders(text: str) -> str:
    # Convert Swift interpolations into placeholders
    text = re.sub(r"\\\(\s*AppBrand\.appName\s*\)", "{{APP_NAME}}", text)
    text = re.sub(r"\\\(\s*LegalIdentity\.platformName\s*\)", "{{LEGAL_PLATFORM_NAME}}", text)
    return text


def camel_to_snake(name: str) -> str:
    # platformOverview -> platform_overview
    out: list[str] = []
    for ch in name:
        if ch.isupper():
            out.append("_")
            out.append(ch.lower())
        else:
            out.append(ch)
    s = "".join(out).lstrip("_")
    return s


def find_faqitem_blocks(text: str) -> list[str]:
    blocks: list[str] = []
    needle = "FAQItem("
    i = 0
    n = len(text)
    while True:
        start = text.find(needle, i)
        if start < 0:
            break
        j = start + len(needle)
        depth = 1
        in_string = False
        escape = False
        while j < n and depth > 0:
            ch = text[j]
            if in_string:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
            j += 1
        blocks.append(text[start:j])
        i = j
    return blocks


def extract_string_field(block: str, field: str) -> str:
    # Matches: field: "...."  (non-greedy, handles escaped quotes)
    m = re.search(rf"{re.escape(field)}\s*:\s*\"((?:\\.|[^\"\\])*)\"", block, flags=re.S)
    if not m:
        raise ValueError(f"Missing field {field}")
    return m.group(1)


def extract_category_case(block: str) -> str:
    m = re.search(r"category\s*:\s*\.([A-Za-z0-9_]+)", block)
    if not m:
        raise ValueError("Missing category")
    return m.group(1)


def parse_faqs(swift_path: Path, source: str) -> list[FAQ]:
    text = swift_path.read_text(encoding="utf-8")
    blocks = find_faqitem_blocks(text)
    faqs: list[FAQ] = []
    for idx, block in enumerate(blocks, start=1):
        faq_id_raw = unescape_swift_string(extract_string_field(block, "id"))
        q_raw = unescape_swift_string(extract_string_field(block, "question"))
        a_raw = unescape_swift_string(extract_string_field(block, "answer"))
        cat = extract_category_case(block)

        faq_id = replace_placeholders(faq_id_raw).strip()
        question = replace_placeholders(q_raw).strip()
        answer = replace_placeholders(a_raw).strip()

        faqs.append(
            FAQ(
                faqId=faq_id,
                question=question,
                answer=answer,
                categoryCase=cat,
                source=source,
                sortOrder=idx,
            )
        )
    return faqs


def category_case_to_display_name(case_name: str) -> str:
    # Must match FIN1/Shared/Models/FAQCategory.swift raw values
    mapping = {
        "gettingStarted": "Getting Started",
        "platformOverview": "Platform Overview",
        "investments": "Investments",
        "trading": "Trading",
        "portfolio": "Portfolio & Performance",
        "invoices": "Invoices & Statements",
        "security": "Security & Authentication",
        "notifications": "Notifications",
        "technical": "Technical Support",
    }
    if case_name not in mapping:
        raise ValueError(f"Unknown category case: {case_name}")
    return mapping[case_name]


def category_case_to_icon(case_name: str) -> str:
    mapping = {
        "gettingStarted": "arrow.right.circle.fill",
        "platformOverview": "star.fill",
        "investments": "dollarsign.circle.fill",
        "trading": "chart.line.uptrend.xyaxis",
        "portfolio": "chart.bar.fill",
        "invoices": "doc.text.fill",
        "security": "lock.shield.fill",
        "notifications": "bell.fill",
        "technical": "wrench.and.screwdriver.fill",
    }
    if case_name not in mapping:
        raise ValueError(f"Unknown category case: {case_name}")
    return mapping[case_name]


def category_case_to_sort_order(case_name: str) -> int:
    ordering = [
        "platformOverview",
        "gettingStarted",
        "investments",
        "trading",
        "portfolio",
        "invoices",
        "security",
        "notifications",
        "technical",
    ]
    return ordering.index(case_name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--faq-provider", type=Path, required=True)
    parser.add_argument("--landing-provider", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    help_center_faqs = parse_faqs(args.faq_provider, source="help_center")
    landing_faqs = parse_faqs(args.landing_provider, source="landing")

    all_faqs = help_center_faqs + landing_faqs

    # Categories used by either source
    used_cases = sorted({f.categoryCase for f in all_faqs})

    categories: list[dict[str, Any]] = []
    for case in used_cases:
        slug = camel_to_snake(case)
        categories.append(
            {
                "slug": slug,
                "title": category_case_to_display_name(case),
                "displayName": category_case_to_display_name(case),
                "icon": category_case_to_icon(case),
                "sortOrder": category_case_to_sort_order(case),
                "isActive": True,
                "showOnLanding": any(f.source == "landing" and f.categoryCase == case for f in all_faqs),
                "showInHelpCenter": any(f.source == "help_center" and f.categoryCase == case for f in all_faqs),
                "showInCSR": True,
            }
        )

    faqs_out: list[dict[str, Any]] = []
    for f in all_faqs:
        faqs_out.append(
            {
                "faqId": f.faqId,
                "question": f.question,
                "answer": f.answer,
                "categorySlug": camel_to_snake(f.categoryCase),
                "sortOrder": f.sortOrder,
                "isPublished": True,
                "isArchived": False,
                "isPublic": True,
                "isUserVisible": True,
                "source": f.source,
            }
        )

    payload = {"categories": categories, "faqs": faqs_out}
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"WROTE {args.output} categories={len(categories)} faqs={len(faqs_out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

