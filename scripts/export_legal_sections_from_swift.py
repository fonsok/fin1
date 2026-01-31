#!/usr/bin/env python3
"""
Export FIN1 bundled Terms/Privacy sections from Swift source into JSON payloads
compatible with Parse `TermsContent.sections`.

This script runs locally (macOS dev machine) and DOES NOT need any secrets.
It outputs 4 JSON files:
  - terms_en.json
  - terms_de.json
  - privacy_en.json
  - privacy_de.json

Notes:
- Converts Swift string interpolations like `\\(LegalIdentity.platformName)` into
  placeholders like `{{LEGAL_PLATFORM_NAME}}`, which the app will replace at runtime.
- Converts `\\(commissionPercentage)` into `{{COMMISSION_RATE}}`.
"""

from __future__ import annotations

import argparse
import json
import re
import textwrap
from dataclasses import dataclass
from pathlib import Path


def camel_to_upper_snake(name: str) -> str:
    # platformName -> PLATFORM_NAME, companyLegalName -> COMPANY_LEGAL_NAME
    out = []
    for i, ch in enumerate(name):
        if ch.isupper() and i != 0 and (not name[i - 1].isupper()):
            out.append("_")
        out.append(ch.upper())
    return "".join(out)


def normalize_content(text: str) -> str:
    # Dedent Swift triple-quoted strings and strip trailing whitespace lines.
    text = textwrap.dedent(text)
    # Normalize Windows line endings just in case
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return text.strip()


def replace_placeholders(text: str) -> str:
    # Replace commission percentage interpolation with template placeholder.
    text = re.sub(r"\\\(\s*commissionPercentage\s*\)", "{{COMMISSION_RATE}}", text)

    # Replace LegalIdentity interpolations with placeholders.
    def repl(m: re.Match) -> str:
        prop = m.group(1)
        return "{{LEGAL_" + camel_to_upper_snake(prop) + "}}"

    text = re.sub(r"\\\(\s*LegalIdentity\.([A-Za-z0-9_]+)\s*\)", repl, text)

    # Replace common bracket placeholders in Privacy templates with LegalIdentity placeholders
    replacements = {
        "[Registrierte Adresse]": "{{LEGAL_COMPANY_ADDRESS_LINE}}",
        "[Registered Address]": "{{LEGAL_COMPANY_ADDRESS_LINE}}",
        "[Registernummer]": "{{LEGAL_COMPANY_REGISTER_NUMBER}}",
        "[Registration Number]": "{{LEGAL_COMPANY_REGISTER_NUMBER}}",
    }
    for k, v in replacements.items():
        text = text.replace(k, v)

    return text


@dataclass(frozen=True)
class ParsedSection:
    name: str
    id: str
    title: str
    content: str
    icon: str | None

    def to_json(self) -> dict:
        payload = {
            "id": self.id,
            "title": self.title,
            "content": self.content,
        }
        if self.icon:
            payload["icon"] = self.icon
        return payload


def extract_bracket_block(src: str, start_idx: int) -> tuple[str, int]:
    """Extract content of [...] starting at start_idx which must be '['."""
    assert src[start_idx] == "["
    i = start_idx + 1
    depth = 1
    in_string = False
    in_triple = False
    while i < len(src):
        if not in_string and not in_triple and src.startswith('"""', i):
            in_triple = True
            i += 3
            continue
        if in_triple and src.startswith('"""', i):
            in_triple = False
            i += 3
            continue

        ch = src[i]
        if not in_triple:
            if not in_string and ch == '"':
                in_string = True
                i += 1
                continue
            if in_string:
                if ch == "\\":
                    i += 2
                    continue
                if ch == '"':
                    in_string = False
                    i += 1
                    continue
        if not in_string and not in_triple:
            if ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    return src[start_idx + 1 : i], i + 1
        i += 1
    raise ValueError("Unterminated [ ... ] block")


def parse_ordered_names(src: str) -> list[str]:
    # Find the first sections list: either "static func sections" or "static var sections"
    m = re.search(r"static\s+(?:func|var)\s+sections\b", src)
    if not m:
        raise ValueError("No sections() definition found")
    # IMPORTANT: the return type often contains `-> [Section]` / `: [Section]`.
    # We need the array literal inside the function/body, so first jump to `{`.
    body_start = src.find("{", m.end())
    if body_start < 0:
        raise ValueError("No '{' found after sections()")
    list_start = src.find("[", body_start)
    if list_start < 0:
        raise ValueError("No '[' found after sections()")
    inner, _ = extract_bracket_block(src, list_start)

    names: list[str] = []
    for raw in inner.split(","):
        item = raw.strip()
        if not item:
            continue
        # investmentSection(commissionRate: commissionRate) -> investmentSection
        fn_match = re.match(r"([A-Za-z0-9_]+)\s*\(", item)
        if fn_match:
            names.append(fn_match.group(1))
            continue
        # plain identifier: introSection
        id_match = re.match(r"([A-Za-z0-9_]+)$", item)
        if id_match:
            names.append(id_match.group(1))
    return names


def extract_call_blocks(src: str, call_name: str) -> list[tuple[int, int, str]]:
    """Return list of (start_idx, end_idx_exclusive, call_text) for call_name(...)"""
    # Ensure we only match the call identifier itself (avoid matching `investmentSection(`, etc.)
    pattern = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(call_name)}\(")
    starts = [m.start() for m in pattern.finditer(src)]

    blocks: list[tuple[int, int, str]] = []
    for start in starts:
        j = start + len(call_name) + 1  # +1 for '('
        depth = 1
        in_string = False
        in_triple = False
        while j < len(src):
            if not in_string and not in_triple and src.startswith('"""', j):
                in_triple = True
                j += 3
                continue
            if in_triple and src.startswith('"""', j):
                in_triple = False
                j += 3
                continue

            ch = src[j]
            if not in_triple:
                if not in_string and ch == '"':
                    in_string = True
                    j += 1
                    continue
                if in_string:
                    if ch == "\\":
                        j += 2
                        continue
                    if ch == '"':
                        in_string = False
                        j += 1
                        continue

            if not in_string and not in_triple:
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        end = j + 1
                        blocks.append((start, end, src[start:end]))
                        break
            j += 1
        else:
            raise ValueError(f"Unterminated {call_name}(...) call")
    return blocks


def guess_section_name(src: str, call_start: int) -> str:
    # If it is a "static let name = Section(", use that name.
    prefix = src[max(0, call_start - 200) : call_start]
    let_names = re.findall(r"static\s+let\s+([A-Za-z0-9_]+)\s*=\s*$", prefix, re.MULTILINE)
    if let_names:
        return let_names[-1]
    # If it is inside a "static func name(" and we see "return Section(", map to that function name.
    func_names = re.findall(r"static\s+func\s+([A-Za-z0-9_]+)\s*\(", prefix, re.MULTILINE)
    if func_names:
        return func_names[-1]
    return "unknown"


def parse_swift_string_value(block: str, key: str) -> str | None:
    # Find "key:" then parse either """...""" or "..."
    m = re.search(rf"{re.escape(key)}\s*:\s*", block)
    if not m:
        return None
    i = m.end()
    if block.startswith('"""', i):
        i += 3
        end = block.find('"""', i)
        if end < 0:
            raise ValueError(f"Unterminated triple-quoted string for {key}")
        return block[i:end]
    if block.startswith('"', i):
        i += 1
        out = []
        while i < len(block):
            ch = block[i]
            if ch == "\\":
                if i + 1 < len(block):
                    out.append(block[i : i + 2])
                    i += 2
                    continue
            if ch == '"':
                return bytes("".join(out), "utf-8").decode("unicode_escape")
            out.append(ch)
            i += 1
        raise ValueError(f"Unterminated string for {key}")
    return None


def parse_sections_from_swift(swift_path: Path) -> list[ParsedSection]:
    src = swift_path.read_text(encoding="utf-8")
    ordered_names = parse_ordered_names(src)

    # Parse all Section(...) calls and index them by guessed name
    blocks = extract_call_blocks(src, "Section")
    parsed: dict[str, ParsedSection] = {}
    for start, _end, text in blocks:
        name = guess_section_name(src, start)
        section_id = parse_swift_string_value(text, "id")
        title = parse_swift_string_value(text, "title")
        content_raw = parse_swift_string_value(text, "content")
        icon = parse_swift_string_value(text, "icon")
        if not section_id or not title or content_raw is None:
            # Not a real Terms/Privacy section (or parse failure)
            continue
        content = replace_placeholders(normalize_content(content_raw))
        parsed[name] = ParsedSection(
            name=name,
            id=section_id,
            title=title,
            content=content,
            icon=icon,
        )

    ordered: list[ParsedSection] = []
    missing: list[str] = []
    for n in ordered_names:
        if n in parsed:
            ordered.append(parsed[n])
        else:
            missing.append(n)

    if missing:
        raise ValueError(f"Missing sections in {swift_path.name}: {missing}")

    # Guard: ensure there are no Swift interpolations left in server content
    leftover = [s for s in ordered if "\\(" in s.content]
    if leftover:
        ids = [s.id for s in leftover][:10]
        raise ValueError(f"Unresolved Swift interpolation in content (examples): {ids}")

    return ordered


def write_payload(out_path: Path, document_type: str, language: str, sections: list[ParsedSection]) -> None:
    payload = {
        "documentType": document_type,
        "language": language,
        "version": "1.0",
        "sections": [s.to_json() for s in sections],
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    repo_root: Path = args.repo_root
    out_dir: Path = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    terms_en = repo_root / "FIN1/Shared/Data/TermsOfServiceEnglishContent.swift"
    terms_de = repo_root / "FIN1/Shared/Data/TermsOfServiceGermanContent.swift"
    privacy_en = repo_root / "FIN1/Shared/Data/PrivacyPolicyAmericanContent.swift"
    privacy_de = repo_root / "FIN1/Shared/Data/PrivacyPolicyGermanContent.swift"

    terms_en_sections = parse_sections_from_swift(terms_en)
    terms_de_sections = parse_sections_from_swift(terms_de)
    privacy_en_sections = parse_sections_from_swift(privacy_en)
    privacy_de_sections = parse_sections_from_swift(privacy_de)

    write_payload(out_dir / "terms_en.json", "terms", "en", terms_en_sections)
    write_payload(out_dir / "terms_de.json", "terms", "de", terms_de_sections)
    write_payload(out_dir / "privacy_en.json", "privacy", "en", privacy_en_sections)
    write_payload(out_dir / "privacy_de.json", "privacy", "de", privacy_de_sections)

    print("OK:", out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

