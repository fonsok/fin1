# Release-Abnahme — iOS Notifications → Documents (Beleg-Inbox)

**Ziel:** Profile → Notifications → **Documents** zeigt dieselben Buchungsbelege wie Kontoauszug-Deep-Links (Investor Collection Bill, Trader TBC + Gutschrift).

**Referenzen:** `Documentation/ACCOUNT_STATEMENT_ARCHITECTURE.md` (Abschnitte Beleg-Links + Notifications → Documents), `Documentation/FAQ_SUPPORT.md` (Documents and Notifications).

---

## 1) Vor Test (Deploy)

| Check | Erwartung |
|-------|-----------|
| Parse Cloud deploy inkl. `getUserDocumentInbox` | `userDocumentInbox.js`, `trading.js` auf Ziel-Host |
| iOS Build mit Hardening-Stand | `DocumentInboxPolicy`, `DocumentService.applyInboxSnapshot` |
| Parse Server healthy | `curl -sk https://<host>/parse/health` → OK |

---

## 2) Manuelle Abnahme (Gerät / Simulator)

### Investor

1. Als Investor einloggen, abgeschlossenen Pool-Trade mit Collection Bill vorhanden.
2. **Profile → Notifications → Documents**
3. Erwartung: mindestens eine **Investor Collection Bill** (Titel **CB-…**, nicht nur `CollectionBill_…`-Dateiname).
4. Kontoauszug: Tap auf Beleg-Link → gleicher Beleg öffnet sich.
5. Notifications schließen und erneut öffnen → Belege bleiben sichtbar (auch wenn gelesen).

### Trader

1. Als Trader einloggen, abgeschlossener Trade mit Provision.
2. **Profile → Notifications → Documents**
3. Erwartung: **Verkaufs-/Collection Bill** und **Gutschrift** (Titel **CN-…** / **CB-…**), nicht nur TBC; Dateiname `CreditNote_Trade…` ist ok.
4. Kontoauszug: CN-Link funktioniert wie in Documents.

### Nach neuem Trade (optional)

1. Trade abschließen (Backend-Settlement).
2. Notifications öffnen oder kurz warten (`userDocumentInboxShouldRefresh`).
3. Neue Belege erscheinen ohne App-Neustart.

---

## 3) Logs (Xcode, optional)

- Erfolg: `getUserDocumentInbox` / `Inbox page` ohne `falling back to legacy fetch`
- Settlement: `merged N backend settlement document(s)` mit `traderCreditNote` wenn Provision > 0

---

## 4) Go / No-Go

| Kriterium | Go | No-Go |
|-----------|----|-------|
| Investor Documents nicht leer (wenn CB auf Server) | ☐ | ☐ |
| Trader CN + TBC in Documents | ☐ | ☐ |
| Kein Legacy-Fallback im Normalfall | ☐ | ☐ |

**Datum / Tester:** _________________

**Ergebnis:** ☐ Go  ☐ No-Go  ☐ Go mit Auflagen
