# Release — iOS Re-Consent, Depot Buy, Buy-Order L2 (2026-06-29)

**Typ:** iOS-only (kein Backend-/Admin-Deploy)  
**Git-Ref:** `9de2368` auf `origin/main`  
**Umgebung:** Staging iobox (`https://192.168.178.24/parse`)

---

## Enthaltene Commits

| Commit | Inhalt |
|--------|--------|
| `0a6f97d` | Re-Consent-Modal stabil, Dashboard nach Login |
| `dc5ab07` | Trader Buy/Sell File-Size-Split (CI) |
| `d604301` | Depot KAUFEN via shared `buyOrderSheet`-Coordinator |
| `9de2368` | `AuthenticationView`-Split (File-Size CI), `BuyOrderDependencies`/`Factory`, L2 Slice 1 |

---

## Deploy-Status

| Schritt | Status | Aktion |
|---------|--------|--------|
| Git push `main` | ✅ | `origin/main` = `9de2368` |
| GitHub CI | ✅ | Manuell bestätigt (File-Size, ResponsiveDesign, Parse-Smokes) |
| Parse Cloud deploy | ⏭️ Nicht nötig | Keine Änderungen unter `backend/parse-server/cloud/` |
| Admin-Portal deploy | ⏭️ Nicht nötig | Keine Änderungen unter `admin-portal/` |
| Staging Parse health | ✅ | `GET /parse/health` → HTTP 200 |
| Post-Deploy-Smoke | ⚠️ Teilweise | Admin + Commission OK; `legalAppName` 4-eyes E2E flaky (unabhängig von dieser Welle) |
| Manuelle iOS-Abnahme | ✅ | Re-Consent, Dashboard, Depot KAUFEN, Fresh Sign-up (#6) |
| **iOS App auf Gerät** | 📱 Manuell | Xcode → Run auf Device oder Archive → TestFlight |

---

## iOS-Build (Gerät / TestFlight)

1. Xcode öffnen, Scheme **FIN1**, Branch **`main`** @ `9de2368`.
2. **Product → Run** auf physischem Gerät (Staging-Parse ist Default in `ConfigurationService`).
3. Optional **Product → Archive** → Distribute → TestFlight / Ad-Hoc.

Kein Server-Schritt vor dem iOS-Build erforderlich.

---

## Abnahme-Referenz

- Re-Consent Epic: [`RELEASE_ABNAHME_RE_CONSENT.md`](RELEASE_ABNAHME_RE_CONSENT.md) — Go 2026-06-29
- Depot Buy (L1): manuell KAUFEN aus Depot bestätigt (`d604301`)

---

## Backlog (bewusst offen)

| Item | Status |
|------|--------|
| L2.2–L2.4 Buy-Order Presentation/Wrapper | Deferred |
| L3 Paired-Buy Backend-Saga | Deferred (nur bei Prod-Incident) |

---

## Ergebnis

**Go** — iOS-Welle freigegeben; Server unverändert.
