# Release-Abnahme — Company KYB Product Gate (FIN1-KYB-GATE)

**Epic:** [`FIN1_APP_DOCS/EPIC_KYB_REGULATED_PRODUCT_GATE.md`](FIN1_APP_DOCS/EPIC_KYB_REGULATED_PRODUCT_GATE.md)  
**Datum:** ___________  
**Tester:** ___________  
**Umgebung:** ☐ Staging ☐ Production  

---

## Voraussetzungen

- [ ] Parse Cloud Code deployed (`productAccessGate.js` mit KYB-Check)
- [ ] Testuser angelegt via `node backend/scripts/seed-company-test-users.js`:
  - `company1-pending@test.com` — KYB `pending_review`
  - `company1-approved@test.com` — KYB `approved`
  - `company1-draft@test.com` — KYB Wizard (optional)
- [ ] Passwort: `TestConstants.password` / iOS DEBUG Landing → **Company Investors (KYB)**
- [ ] Admin-Zugang `/kyb-review`

---

## Tests

| # | Schritt | Erwartung | OK |
|---|---------|-----------|-----|
| 1 | KYB eingereicht, Status `pending_review` | `createInvestmentSplits` → `OPERATION_FORBIDDEN`, Message enthält „pending“ / „review“ | ☐ |
| 2 | iOS: Investment-Button / Discovery | Hinweis „Firmenunterlagen werden geprüft“ (oder gleichwertig) | ☐ |
| 3 | Admin: `reviewCompanyKyb` → `approved` | User-Feld `companyKybStatus=approved` | ☐ |
| 4 | App: Refresh / Re-Login | Investment möglich (Cash/RK vorausgesetzt) | ☐ |
| 5 | Admin: `more_info_requested` mit Notes | iOS zeigt Resubmit-Hinweis; Gate blockiert | ☐ |
| 6 | **`individual`-Investor Regression** | Unverändert investierbar (ohne KYB-Felder) | ☐ |

---

## Ergebnis

| | |
|---|---|
| **Go / No-Go** | ☐ Go ☐ No-Go |
| **Bemerkungen** | |

---

## Referenzen

- Backend: `backend/parse-server/cloud/utils/productAccessGate.js`
- Tests: `backend/parse-server/cloud/utils/__tests__/productAccessGate.test.js`
