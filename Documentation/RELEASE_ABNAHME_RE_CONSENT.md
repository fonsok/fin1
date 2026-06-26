# Release-Abnahme — Post-Onboarding Re-Consent (FIN1-LEGAL-RECONSENT)

**Epic:** [`FIN1_APP_DOCS/EPIC_POST_ONBOARDING_RE_CONSENT.md`](FIN1_APP_DOCS/EPIC_POST_ONBOARDING_RE_CONSENT.md)  
**Datum:** ___________  
**Tester:** ___________  
**Umgebung:** ☐ Staging ☐ Production  

---

## Voraussetzungen

- [ ] Epic vollständig deployed (`getRequiredReConsents`, erweitertes `productAccessGate`, iOS Re-Consent UI)
- [ ] Staging-User mit abgeschlossenem Onboarding + Role Agreement
- [ ] Admin: neue `TermsContent`-Version vorbereitet (zunächst inaktiv)

---

## Tests

| # | Schritt | Erwartung | OK |
|---|---------|-----------|-----|
| 1 | User auf TOS v1.0, Admin aktiviert v2.0 | `getRequiredReConsents` listet TOS mit `blocking: true` | ☐ |
| 2 | App start / Login | Blocking Re-Consent Modal (TOS) | ☐ |
| 3 | Accept TOS v2.0 | `recordLegalConsent`, `_User.acceptedTermsVersion=2.0` | ☐ |
| 4 | `createInvestmentSplits` | Erfolg (sofern sonstige Gates passieren) | ☐ |
| 5 | Investor: neue `investor_agreement`-Version | Scroll-to-Accept + Checkbox, dann frei | ☐ |
| 6 | Frisch registrierter User (gleiche Version) | Kein redundantes Modal nach Gate 1 Mirror | ☐ |
| 7 | API ohne Accept | `productAccessGate` → `OPERATION_FORBIDDEN` | ☐ |
| 8 | `LegalConsent` Audit | Zeile mit `source: app`, Version, IP, deviceInstallId | ☐ |

---

## Ergebnis

| | |
|---|---|
| **Go / No-Go** | ☐ Go ☐ No-Go |
| **Bemerkungen** | |
