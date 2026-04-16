#!/usr/bin/env python3
"""
One-off: build English TermsContent sections matching active DE terms from a
legal-documents-backup JSON (same shape as Admin «Export (Backup)»).

DE must have at least one section. EN uses `en_by_id` per section `id`; any `id`
without a mapping falls back to **German** title/content (stderr warning) until
you add translations — unless you pass **`--strict-en`**, then the script exits
with an error if any `id` is missing from `en_by_id`.

Output:
- scripts/generated/terms_en_34_2026-04-16.json (dated; name kept for history)
- scripts/generated/terms_en.json (deploy_updated_legal_docs.py --only terms_en)
- scripts/generated/terms_de.json (DE from backup; deploy --only terms_de)
- scripts/generated/legal-active-import-terms-de-en-2026-04-16.json
  → Admin **Import active (as new)**: terms de + en, same section count as DE.
- scripts/generated/legal-active-import-terms-en-2026-04-16.json (EN only)
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def normalize_de_sections_for_export(sections: list) -> list[dict]:
    """Same shape as deploy/import; replace literal branding placeholder bbb → {{APP_NAME}}."""
    out: list[dict] = []
    for s in sections:
        title = (s.get("title") or "").replace("bbb", "{{APP_NAME}}")
        content = (s.get("content") or "").replace("bbb", "{{APP_NAME}}")
        out.append(
            {
                "id": s.get("id") or "",
                "title": title,
                "content": content,
                "icon": s.get("icon") or "",
            }
        )
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backup",
        type=Path,
        default=Path("/Users/ra/Downloads/legal-documents-backup-2026-04-16_14-13-10.json"),
        help="Full legal export JSON (same shape as Admin Export Backup).",
    )
    parser.add_argument(
        "--strict-en",
        action="store_true",
        help="Fail if any DE section id has no English entry in en_by_id (no DE→EN fallback).",
    )
    args = parser.parse_args()
    backup_path = args.backup
    if not backup_path.is_file():
        raise SystemExit(f"Backup not found: {backup_path}\nPass --backup /path/to/legal-documents-backup-....json")

    base_out = Path(__file__).resolve().parents[1] / "scripts" / "generated"
    out_path = base_out / "terms_en_34_2026-04-16.json"
    out_path_alias = base_out / "terms_en.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    data = json.loads(backup_path.read_text(encoding="utf-8"))
    de_doc = next(
        d
        for d in data["documents"]
        if d.get("documentType") == "terms" and d.get("language") == "de" and d.get("isActive") is True
    )
    de_sections = de_doc["sections"]
    if not de_sections:
        raise SystemExit("Active DE terms must contain at least one section (sections array empty).")

    # English titles + bodies: aligned by id order with DE; placeholders preserved.
    en_by_id: dict[str, dict[str, str]] = {
        "introduction": {
            "title": "1. Introduction & Definitions",
            "content": """{{APP_NAME}} is a technology app that facilitates securities trading and wealth management / investment management services. The app connects traders and investors and enables investment opportunities in securities trading activities, including derivatives.

**Definitions:**
- **App** or **Service**: The {{APP_NAME}} application and related services
- **User**: Any individual or entity using the App
- **Trader**: Users who execute securities trades on the App
- **Investor**: Users who invest capital with traders through the App
- **Investment**: Capital allocated by investors to traders for investment activities
- **Securities**: Financial instruments traded on the App""",
        },
        "acceptance": {
            "title": "2. Acceptance of Terms",
            "content": """By accessing or using the {{APP_NAME}} app, you agree to be bound by these Terms of Service. If you do not agree to these Terms, you must not use the App.

**Changes:**
We reserve the right to modify these Terms at any time. Material changes will be communicated with at least 30 days' notice. Continued use of the App after changes constitutes acceptance of the modified Terms.

**Eligibility:**
You must be at least 18 years old and have legal capacity to enter into binding agreements. You must comply with all applicable laws and regulations in your jurisdiction.""",
        },
        "regulatory": {
            "title": "3. Regulatory Compliance",
            "content": """Tax compliance:
- Capital gains are subject to flat-rate withholding tax ({{TAX_RATE}} + solidarity surcharge) on realized gains.""",
        },
        "app": {
            "title": "4. App Description & Service Scope",
            "content": """**Nature of Service:**
{{APP_NAME}} is a **technology app** that facilitates securities trading and investment management. The App provides technology infrastructure, connects traders and investors, executes trades through licensed brokers, and provides transaction records.

**What We Do NOT Provide:**
- Investment advice or recommendations
- Guaranteed investment returns or performance
- Financial advisory services
- Guaranteed trader availability or investment opportunities
- Tax advice (users must consult tax advisors)

**Service Limitations:**
- The App acts as an intermediary, not as principal
- Users make independent investment decisions
- The App does not guarantee execution at displayed prices
- Service availability is not guaranteed to be uninterrupted""",
        },
        "account": {
            "title": "5. User Eligibility & Account Requirements",
            "content": """**Account Eligibility:**
To use the App, you must be at least 18 years old, have legal capacity, provide accurate information, complete identity verification (KYC), and comply with all applicable laws.

**Account Types:**
- **Trader accounts**: For users who execute securities trades
- **Investor accounts**: For users who invest capital with traders

**Account balance:**
- Initial balance: New accounts receive an initial balance of €1.00
- Minimum cash reserve: Accounts must maintain a minimum cash reserve of €20
- Purpose of balance: Account balances are for App use only""",
        },
        "trading": {
            "title": "6. Trading Terms & Conditions",
            "content": """**Order execution:**
- Orders are executed via licensed brokers and exchanges
- Execution prices are subject to market conditions
- The App does not guarantee execution at displayed prices

**Order fees & costs:**
- **Order fee**: 0.5% of the order value (minimum €5, maximum €50)
- **Exchange venue fee**: 0.1% of the order value (minimum €1, maximum €20)
- **Third-party costs**: €1.50 per transaction
- Fees are calculated on the total securities value and are non-refundable after execution

**Trading limits:**
Orders must meet minimum thresholds and sufficient balance must be available (including fees and minimum reserve).""",
        },
        "investment": {
            "title": "7. Investment Terms (Investor-Specific)",
            "content": """App service charge:
- Rate: {{APP_SERVICE_CHARGE_RATE}} of the investment amount (incl. {{VAT_RATE}} VAT).
- VAT: {{APP_SERVICE_CHARGE_RATE}} includes {{VAT_RATE}} VAT.
- Commissions: Trader commissions ({{TRADER_COMMISSION_RATE}}, configurable) are deducted from returns.""",
        },
        "tax": {
            "title": "8. Tax Obligations & Responsibilities",
            "content": """Tax withholding:
- Flat-rate withholding tax: {{TAX_RATE}} + solidarity surcharge applies to realized capital gains.
- Service charges are subject to {{VAT_RATE}} VAT.""",
        },
        "risks": {
            "title": "9. Risk Disclosures",
            "content": """**IMPORTANT: Investing in securities involves substantial risk of loss.**

**Investment risks:**
- **Capital loss risk**: You may lose part or all of your invested capital
- **Market volatility**: Securities prices fluctuate based on market conditions
- **No guarantee of returns**: Past performance does not guarantee future results
- **Trader performance risk**: Returns depend on trader performance, which varies
- **Liquidity risk**: Investments may not be immediately liquid

**App risks:**
- Technical failures, service interruptions, limitations in data accuracy
- Cybersecurity risks despite security measures

**Acknowledgment:**
By using the App, you confirm that you understand the risks involved, are capable of bearing the financial risks, and are making independent investment decisions.""",
        },
        "responsibilities": {
            "title": "10. User Responsibilities & Prohibited Activities",
            "content": """**User obligations:**
Users must provide accurate information, maintain secure credentials, comply with laws, report suspicious activities, and cooperate with App investigations.

**Prohibited activities:**
Users must not:
- Engage in fraudulent activities, market manipulation, or unauthorized access
- Circumvent App controls or provide false information
- Engage in money laundering, terrorist financing, or violate laws
- Interfere with App operations or other users

**Consequences:**
Violations may result in account suspension or termination, legal action, reporting to regulatory authorities, forfeiture of funds, or other remedies available under law.""",
        },
        "limitations": {
            "title": "11. App Limitations & Disclaimers",
            "content": """**Service availability:**
- The App does not guarantee uninterrupted or error-free service
- Scheduled and unscheduled maintenance may occur
- Service may be interrupted due to circumstances beyond our control

**Data accuracy:**
- Market data, prices, and calculations are provided \"as is\"
- We do not guarantee accuracy, completeness, or timeliness
- Users should verify critical information independently

**Liability limitations:**
To the maximum extent permitted by law:
- App liability is limited to direct damages
- We are not liable for indirect, consequential, incidental, or punitive damages
- Total liability is limited to fees paid in the 12 months preceding the claim
- We are not liable for losses due to market conditions or user decisions""",
        },
        "ip": {
            "title": "12. Intellectual Property",
            "content": """**App intellectual property:**
- All App content, software, designs, and materials are proprietary
- Users are granted a limited, non-exclusive, non-transferable license to use the App
- Users may not copy, modify, distribute, or create derivative works
- All rights reserved

**User data:**
- Users retain ownership of their data
- Users grant the App a license to process data for service provision
- Data processing is governed by our Privacy Policy and GDPR / the German Federal Data Protection Act (BDSG), where applicable

**Trademarks:**
- {{APP_NAME}} and related trademarks are the property of the App
- Users may not use trademarks without written permission""",
        },
        "privacy": {
            "title": "13. Data Protection & Privacy",
            "content": """**GDPR compliance:**
The App complies with the GDPR. Please refer to our Privacy Policy for:
- Legal basis of processing
- User rights (access, rectification, erasure, portability)
- Retention periods
- International data transfers (if applicable)
- Contact information for data protection inquiries

**Data security:**
- We implement industry-standard security measures (AES-256 encryption, TLS 1.3)
- Data is stored securely (Keychain for sensitive data)
- However, no system is 100% secure
- Users must maintain secure credentials

**Data sharing:**
- Data may be shared with brokers, exchanges, and service providers as necessary
- Data may be shared for regulatory compliance (KYC/AML)
- Data sharing is governed by our Privacy Policy""",
        },
        "termination": {
            "title": "14. Account Termination & Suspension",
            "content": """**Termination by user:**
Users may terminate accounts at any time by contacting App support, following account closure procedures, and settling all outstanding obligations.

**Termination by App:**
The App may terminate accounts for violation of Terms, suspicious activity, regulatory requirements, non-compliance with KYC/AML, or other reasons.

**Account suspension:**
Accounts may be suspended pending investigation, for security reasons, for regulatory compliance, or for non-payment of fees.

**Post-termination:**
Outstanding obligations must be settled, data retention policies apply, and access to App services ceases.""",
        },
        "disputes": {
            "title": "15. Dispute Resolution & Governing Law",
            "content": """**Governing law:**
These Terms are governed by German law.

**Jurisdiction:**
Disputes shall be subject to the exclusive jurisdiction of German courts.

**Dispute resolution process:**
1. Informal resolution: contact App support first
2. Mediation: parties may agree to mediation
3. Arbitration: if applicable, disputes may be resolved through arbitration
4. Court proceedings: if other methods fail, disputes may proceed to court

**Regulatory complaints:**
Users may file complaints with BaFin (Federal Financial Supervisory Authority) or other regulatory authorities as appropriate.""",
        },
        "changes": {
            "title": "16. Changes to Terms",
            "content": """**Modification rights:**
The App reserves the right to modify these Terms at any time.

**Notice requirements:**
- Material changes: at least 30 days' notice
- Notification methods: email, in-app notification, or App notice
- Effective date: changes become effective on the specified date

**Acceptance:**
- Continued use of the App after changes constitutes acceptance
- Users may terminate accounts if they do not agree to changes
- Terms are versioned and dated, with previous versions archived""",
        },
        "contact": {
            "title": "17. Contact Information & Support",
            "content": """**Support channels:**
- Help Center: available in-app with FAQs and support articles
- Contact support: in-app support messaging
- Response times: we aim to respond within reasonable timeframes

**Legal notices:**
Company information, registration details, regulatory authorizations, and registered address are available upon request.

**Data protection officer:**
Contact information for data protection inquiries is available through the Privacy Policy.""",
        },
        "special": {
            "title": "18. Special Provisions",
            "content": """**Anti-money laundering prevention:**
- KYC requirements: identity verification is required
- AML compliance: anti-money laundering procedures apply
- Transaction monitoring: transactions are monitored for suspicious activity
- Reporting: suspicious activities are reported to authorities
- User cooperation: users must cooperate with KYC/AML procedures

**Regulatory reporting:**
- The App may be required to report to regulatory authorities
- User information may be shared for regulatory compliance
- Users must provide accurate information for regulatory purposes""",
        },
        "severability": {
            "title": "19. Severability & Miscellaneous",
            "content": """**Severability:**
If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions shall remain in full force and effect.

**Entire agreement:**
These Terms, together with the Privacy Policy, constitute the entire agreement between users and the App.

**Waiver:**
Failure to enforce any provision does not constitute a waiver of that provision.

**Assignment:**
Users may not assign these Terms without App consent. The App may assign these Terms.

**Language:**
These Terms are provided in German and English. In case of conflict, the German version shall prevail.""",
        },
        "dashboard_risk_note": {
            "title": "Dashboard risk notice",
            "content": "Note: never expose more than {{MAX_RISK_PERCENT}} % of your assets to risk.",
        },
        "order_legal_warning_buy": {
            "title": "Buy order legal notice",
            "content": "By tapping 'Buy' you agree to the general terms and conditions and confirm that you understand the risks of securities trading. This transaction is subject to fees.",
        },
        "order_legal_warning_sell": {
            "title": "Sell order legal notice",
            "content": "By tapping 'Sell' you agree to the general terms and conditions and confirm that you understand the risks of securities trading. This transaction is subject to fees.",
        },
        "doc_tax_note_sell": {
            "title": "Tax note (sell)",
            "content": "On sale, taxation is applied in accordance with flat-rate withholding tax (currently {{TAX_RATE}}) on the realized gain.",
        },
        "doc_tax_note_buy": {
            "title": "Tax note (buy)",
            "content": "No tax is deducted on purchase. Taxation occurs on sale in accordance with flat-rate withholding tax (currently {{TAX_RATE}}).",
        },
        "doc_legal_note_wphg": {
            "title": "Legal note (WpHG)",
            "content": "Taxation is based on gain realization under current regulation (Section 20 German Income Tax Act, EStG).\n\nThis statement is prepared in accordance with the German Securities Trading Act (WpHG) and the Securities Trading Ordinance (WpDVerOV).",
        },
        "doc_tax_note_service_charge": {
            "title": "Tax note (service charge)",
            "content": "The app service charge is subject to VAT ({{VAT_RATE}}).",
        },
        "riskclass7_max_loss_warning": {
            "title": "Risk class 7 – total loss",
            "content": "The risk of loss of up to 100% of the capital invested is acknowledged.",
        },
        "riskclass7_experienced_only": {
            "title": "Risk class 7 – suitability",
            "content": "This risk class is only suitable for experienced investors.",
        },
        "doc_collection_bill_reference_info": {
            "title": "Collection Bill reference text",
            "content": """The difference between the sum of the result before taxes and the amount transferred to your account results from tax withholding. This is carried out in accordance with legal requirements and shown transparently in your account statements and tax documents.
Tax liability exists only if sale proceeds exceed acquisition costs. The calculation is based on the principle of offsetting purchase and sale costs (first-in-first-out or average cost). For details, see the tax report under transaction no.:""",
        },
        "doc_collection_bill_legal_disclaimer": {
            "title": "Collection Bill legal notice",
            "content": """We book the securities and the consideration in accordance with the statement with the specified value date. Please review this statement for correctness and completeness. Objections to this statement must be raised without undue delay upon receipt with the bank. If you fail to object in time, this constitutes approval. Please note any issuer information on early maturity, e.g. due to a knock-out, in the respective warrant terms and inform yourself in good time about the specific maturity rules for the securities you hold. Capital income is subject to income tax.""",
        },
        "doc_collection_bill_footer_note": {
            "title": "Collection Bill footer",
            "content": "This message is machine-generated and is not signed.\nFor further questions please contact your Fin1 service team.",
        },
        "account_statement_important_notice_de": {
            "title": "Account statement important notices (DE)",
            "content": """Please raise objections to individual postings without undue delay. Cheques, bills of exchange, and other direct debits are credited subject to receipt. The balance shown does not reflect the value date of postings (see above under \"Value date\").

Accordingly, interest may accrue if you use an agreed or tolerated overdraft facility.

The services charged are exempt from VAT as banking or financial services, unless VAT is shown separately. {{LEGAL_COMPANY_LEGAL_NAME}}, {{LEGAL_COMPANY_ADDRESS_LINE}}. VAT ID: {{LEGAL_COMPANY_VAT_ID}}.

Balances qualify as deposits eligible for compensation under the German Deposit Guarantee Act. Further information can be found in the \"Information sheet for the depositor\".""",
        },
        "account_statement_important_notice_en": {
            "title": "Account statement important notice (EN)",
            "content": """Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.

All deposits and credits are subject to final verification.

The ending balance may not reflect all pending transactions or holds on funds.

Overdrafts may result in fees or interest charges.

We are not responsible for delays in posting or for errors unless required by law.

Your account is subject to the terms and conditions governing your relationship with the bank.""",
        },
        "transaction_limit_warning_buy": {
            "title": "Transaction limit reached",
            "content": "Your daily transaction limit has been reached or exceeded. Please reduce the order amount or contact support to review your limit.",
        },
    }

    de_export_sections = normalize_de_sections_for_export(de_sections)
    out_sections: list[dict] = []
    for de_row in de_export_sections:
        sid = de_row.get("id") or ""
        if sid in en_by_id:
            en = en_by_id[sid]
            out_sections.append(
                {
                    "id": sid,
                    "title": en["title"],
                    "content": en["content"],
                    "icon": de_row.get("icon") or "",
                }
            )
        else:
            if args.strict_en:
                raise SystemExit(
                    f"Missing English mapping for section id={sid!r} (--strict-en). "
                    "Add an entry to en_by_id in this script."
                )
            print(
                f"WARNING: no EN mapping for section id={sid!r}; using German title/content — add to en_by_id.",
                file=sys.stderr,
            )
            out_sections.append(
                {
                    "id": sid,
                    "title": de_row["title"],
                    "content": de_row["content"],
                    "icon": de_row.get("icon") or "",
                }
            )

    payload_en = {"documentType": "terms", "language": "en", "sections": out_sections}
    text_en = json.dumps(payload_en, ensure_ascii=False, indent=2) + "\n"
    out_path.write_text(text_en, encoding="utf-8")
    out_path_alias.write_text(text_en, encoding="utf-8")

    payload_de = {"documentType": "terms", "language": "de", "sections": de_export_sections}
    terms_de_path = base_out / "terms_de.json"
    terms_de_path.write_text(json.dumps(payload_de, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    exported_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    version = "1.0.2"
    en_note = (
        "EN: all section ids translated via en_by_id (--strict-en)."
        if args.strict_en
        else "EN from en_by_id; missing ids used DE text as placeholder (see script stderr when building)."
    )
    active_import_both = {
        "exportedAt": exported_at,
        "version": "1.0",
        "note": f"Admin «Import active (as new)»: terms DE + EN, same section count as DE backup. {en_note} DE: bbb→{{APP_NAME}}.",
        "documents": [
            {
                "version": version,
                "language": "de",
                "documentType": "terms",
                "effectiveDate": exported_at,
                "sections": de_export_sections,
            },
            {
                "version": version,
                "language": "en",
                "documentType": "terms",
                "effectiveDate": exported_at,
                "sections": out_sections,
            },
        ],
    }
    active_import_both_path = base_out / "legal-active-import-terms-de-en-2026-04-16.json"
    active_import_both_path.write_text(json.dumps(active_import_both, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    active_import_en_only = {
        "exportedAt": exported_at,
        "version": "1.0",
        "note": f"Admin «Import active (as new)» — EN terms only (same section count as DE backup). {en_note}",
        "documents": [
            {
                "version": version,
                "language": "en",
                "documentType": "terms",
                "effectiveDate": exported_at,
                "sections": out_sections,
            }
        ],
    }
    active_import_path = base_out / "legal-active-import-terms-en-2026-04-16.json"
    active_import_path.write_text(json.dumps(active_import_en_only, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("Wrote", out_path, "&", out_path_alias, "sections=", len(out_sections))
    print("Wrote", terms_de_path, "sections=", len(de_export_sections))
    print("Wrote", active_import_both_path, "(Import active: DE + EN)")
    print("Wrote", active_import_path, "(Import active: EN only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
