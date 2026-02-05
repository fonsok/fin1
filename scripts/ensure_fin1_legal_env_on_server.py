#!/usr/bin/env python3
"""
Ensure FIN1_LEGAL_* variables exist in /home/io/fin1-server/backend/.env (Ubuntu server).

- Adds a well-scoped block if missing
- Does NOT modify existing FIN1_LEGAL_* values
- Prints only counts (no secrets)
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Pair:
    key: str
    value: str


LEGAL_VARS: list[Pair] = [
    Pair("FIN1_LEGAL_COMMISSION_RATE_PERCENT", "10"),
    Pair("FIN1_LEGAL_PLATFORM_NAME", "FIN1"),
    Pair("FIN1_LEGAL_COMPANY_LEGAL_NAME", "FIN1 Investing GmbH"),
    Pair("FIN1_LEGAL_COMPANY_ADDRESS", "Hauptstraße 100"),
    Pair("FIN1_LEGAL_COMPANY_CITY", "60311 Frankfurt am Main"),
    Pair("FIN1_LEGAL_COMPANY_ADDRESS_LINE", "Hauptstraße 100, 60311 Frankfurt am Main"),
    Pair("FIN1_LEGAL_COMPANY_REGISTER_NUMBER", "HRB 123456"),
    Pair("FIN1_LEGAL_COMPANY_VAT_ID", "DE123456789"),
    Pair("FIN1_LEGAL_COMPANY_MANAGEMENT", "Max Mustermann"),
    Pair("FIN1_LEGAL_BANK_NAME", "FIN1 Bank AG"),
    Pair("FIN1_LEGAL_BANK_IBAN", "DE89 3704 0044 0532 0130 00"),
    Pair("FIN1_LEGAL_BANK_BIC", "COBADEFFXXX"),
    Pair("FIN1_LEGAL_COMPANY_EMAIL", "info@fin1-investing.com"),
    Pair("FIN1_LEGAL_COMPANY_PHONE", "+49 (0) 69 12345678"),
    Pair("FIN1_LEGAL_COMPANY_WEBSITE", "www.fin1-investing.com"),
]


def main() -> int:
    env_path = Path("/home/io/fin1-server/backend/.env")
    if not env_path.exists():
        raise SystemExit(f"Missing {env_path}")

    existing_lines = env_path.read_text(encoding="utf-8").splitlines()
    existing_keys = set()
    for line in existing_lines:
        line = line.strip()
        if (not line) or line.startswith("#") or "=" not in line:
            continue
        k = line.split("=", 1)[0].strip()
        existing_keys.add(k)

    missing = [p for p in LEGAL_VARS if p.key not in existing_keys]
    if not missing:
        print(f"OK: FIN1_LEGAL_* already present ({len(LEGAL_VARS)} keys)")
        return 0

    block_lines: list[str] = []
    block_lines.append("")
    block_lines.append("# ============================================")
    block_lines.append("# Legal Identity (Audit-clean server-side rendering)")
    block_lines.append("# ============================================")
    block_lines.append("# IMPORTANT (Audit): Changing these values requires a new TermsContent version (append-only).")
    for p in missing:
        block_lines.append(f"{p.key}={p.value}")

    updated = "\n".join(existing_lines).rstrip() + "\n" + "\n".join(block_lines) + "\n"
    env_path.write_text(updated, encoding="utf-8")
    print(f"UPDATED: added {len(missing)} FIN1_LEGAL_* keys (total now {len(existing_keys) + len(missing)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

