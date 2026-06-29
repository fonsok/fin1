# Release-Abnahme — Post-Onboarding Re-Consent (FIN1-LEGAL-RECONSENT)

**Epic:** [`FIN1_APP_DOCS/EPIC_POST_ONBOARDING_RE_CONSENT.md`](FIN1_APP_DOCS/EPIC_POST_ONBOARDING_RE_CONSENT.md)
**Datum:** ___________
**Tester:** ___________
**Umgebung:** ☐ Staging ☐ Production

---

## URLs (Staging / iobox)

| Zweck | URL |
|-------|-----|
| **Admin-Portal Login** | `https://192.168.178.24/admin/login` |
| **AGB & Rechtstexte** | `https://192.168.178.24/admin/terms` |
| **Parse REST** | `https://192.168.178.24/parse` |
| **Parse Dashboard** (optional) | `https://192.168.178.24/dashboard/` — siehe [`DASHBOARD_ANLEITUNG.md`](../DASHBOARD_ANLEITUNG.md) |
| **SSH** | `io@192.168.178.24` oder `io@192.168.178.20` (gleicher Host) |

**Application ID:** `fin1-app-id` (nicht `fin1`).

**Hinweis:** `.20` und `.24` sind derselbe Docker-Stack — [`OPERATIONAL_DEPLOY_HOSTS.md`](OPERATIONAL_DEPLOY_HOSTS.md).

---

## Staging Klick-Anleitung (Minimal-Test)

### Phase 0 — Voraussetzungen prüfen

- [ ] Parse Cloud mit PR #11 deployed (`getRequiredReConsents`, `productAccessGate`)
- [ ] iOS-App von `main` **nach** PR #12 (Re-Consent UI)
- [ ] App zeigt auf Staging-Parse (`https://192.168.178.24/parse` — Standard in `ConfigurationService`)

### Phase 1 — Baseline: User ohne Drift

**Testuser (Seed, kein Sign-up nötig):**

| Rolle | E-Mail | Passwort |
|-------|--------|----------|
| Investor | `investor1@test.com` | `TestPassword123!` |
| Trader | `trader1@test.com` | `TestPassword123!` |

Seed setzt u. a. `onboardingCompleted=true`, `acceptedTermsVersion=1.0`, `acceptedInvestorAgreementVersion=1.0`.

**Login + API-Baseline (Terminal):**

```bash
HOST='https://192.168.178.24'
APP_ID='fin1-app-id'

# 1) Session holen
LOGIN=$(curl -sk -X POST "$HOST/parse/login" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "Content-Type: application/json" \
  -d '{"username":"investor1@test.com","password":"TestPassword123!"}')

SESSION=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin)['sessionToken'])")
echo "sessionToken: ${SESSION:0:20}…"

# 2) getUserMe — vor dem Version-Bump
curl -sk -X POST "$HOST/parse/functions/getUserMe" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Session-Token: $SESSION" \
  -H "Content-Type: application/json" \
  -d '{}' | python3 -m json.tool
```

**Erwartung vor Bump:** `acceptedTermsVersion` z. B. `"1.0"`, `requiredReConsents` leer `[]`.

Optional nur Backend:

```bash
curl -sk -X POST "$HOST/parse/functions/getRequiredReConsents" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Session-Token: $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"language":"de"}' | python3 -m json.tool
```

### Phase 2 — Admin: neue Version anlegen und aktivieren

1. Browser: `https://192.168.178.24/admin/login` — z. B. `admin@fin1.de` (Passwort laut [`DEV_LOGIN_ACCOUNTS.md`](DEV_LOGIN_ACCOUNTS.md) / Server-Setup).
2. Sidebar: **AGB & Rechtstexte** → oder direkt `/admin/terms`.
3. Berechtigung: Rolle `admin` oder `customer_service` mit `manageTemplates`.

**Szenario A — AGB (Device Gate):**

1. Filter: Dokumenttyp **AGB / Terms**, Sprache **de**.
2. Zeile mit Badge **aktiv** (z. B. v`1.0`) → **Klonen (neue Version)**.
3. Im Editor: Version **`2.0`** (muss höher als User-Version `1.0` sein) → Speichern (zunächst inaktiv).
4. In der Liste bei v`2.0` → **Als aktiv setzen** bestätigen.

**Szenario B — Investor Agreement (neues Re-Consent-Modal mit Scroll):**

1. Filter: **Alle Typen**, Sprache **de**.
2. Zeile `investor_agreement` (aktiv, z. B. v`1.0`) → **Klonen** → Version **`2.0`** → Speichern.
3. **Als aktiv setzen** (AGB unverändert lassen).

**Reihenfolge:** User einmal eingeloggt gehabt → **dann** aktivieren → App neu starten / erneut einloggen.

**API nach Bump (ohne Accept in der App):**

```bash
curl -sk -X POST "$HOST/parse/functions/getUserMe" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Session-Token: $SESSION" \
  -H "Content-Type: application/json" \
  -d '{}' | python3 -m json.tool
```

**Erwartung:** `requiredReConsents` enthält z. B.:

```json
{
  "consentType": "terms_of_service",
  "documentType": "terms",
  "activeVersion": "2.0",
  "userVersion": "1.0",
  "blocking": true,
  "requiresScrollToAccept": false
}
```

(bzw. `investor_agreement` mit `requiresScrollToAccept: true` bei Szenario B)

### Phase 3 — iOS-App

1. App **komplett beenden** (oder abmelden).
2. Mit `investor1@test.com` einloggen.
3. Kurz **Lade-Spinner** (`LegalConsentGatePlaceholder`).
4. **Modal-Reihenfolge:**
   - **Szenario A (nur AGB bump):** zuerst **Device Gate** (`TermsAcceptanceModalView` — „AGB/Datenschutz aktualisiert“). Das ist normal; Re-Consent-Modal für AGB kann danach leer sein.
   - **Szenario B (nur investor_agreement bump):** **ReConsentModalView** mit Scroll + Checkbox.
5. Alle Pflicht-Consents bestätigen → **Dashboard** (`MainTabView`).
6. Investment-Flow kurz öffnen (Discover / Neue Investition) — sollte nicht mehr blockieren.

### Phase 4 — Parse Dashboard: Daten prüfen

Öffnen: `https://192.168.178.24/dashboard/` (Login laut [`DASHBOARD_ANLEITUNG.md`](../DASHBOARD_ANLEITUNG.md)).

| Klasse | Was prüfen |
|--------|------------|
| **`_User`** | User `investor1@test.com` → nach Accept: `acceptedTermsVersion` = `2.0` (bzw. Agreement-Version) |
| **`TermsContent`** | Neue Zeile v`2.0`, `isActive: true`; alte Version `isActive: false` |
| **`LegalConsent`** | Neue Zeile: `consentType`, `version`, `source: app`, `deviceInstallId`, `userId` |

**Hinweis:** Cloud Functions wie `getUserMe` laufen im Dashboard nicht bequem — dafür die **curl-Befehle** aus Phase 1/2 nutzen.

### Phase 5 — API-Block ohne Accept (Checkliste #7)

Session **nach Bump**, **bevor** in der App bestätigt wurde (oder frische Session nach erneutem Login ohne Modal zu schließen):

```bash
curl -sk -X POST "$HOST/parse/functions/createInvestmentSplits" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Session-Token: $SESSION" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Erwartung:** HTTP 400, Parse-Code `119` (`OPERATION_FORBIDDEN`), Message z. B.
`Terms of Service must be re-accepted (version 2.0 required).`

(`assertProductAccessEligible` läuft **vor** Parameter-Validierung.)

### Phase 6 — Aufräumen nach Test

- In **AGB & Rechtstexte** die **vorherige Version** wieder **Als aktiv setzen** (oder Test-Version archiviert lassen).
- Optional: erneut in der App einloggen und prüfen, dass kein Block mehr besteht.

### Häufige Stolpersteine

| Symptom | Ursache |
|---------|---------|
| Kein Modal | User ohne `acceptedTermsVersion` / Agreement-Version (Legacy-Grandfather) |
| Kein Modal | Aktive Version = User-Version (Bump vergessen oder gleiche Nummer) |
| Nur Device Gate, kein Re-Consent bei AGB | Erwartetes Verhalten — Device Gate aktualisiert Konto zuerst |
| `requiredReConsents` leer trotz Bump | User-Version fehlt auf `_User` — in Dashboard prüfen |
| `unauthorized` bei curl | Falsche Application ID (`fin1-app-id` verwenden) |

---

## Voraussetzungen

- [x] Epic vollständig deployed (`getRequiredReConsents`, erweitertes `productAccessGate`, iOS Re-Consent UI) — PR #11, #12
- [x] Staging-User mit abgeschlossenem Onboarding + Role Agreement (`investor1@test.com`)
- [x] Admin: neue `TermsContent`-Version vorbereitet und aktiviert (Klonen → höhere Version → „Als aktiv setzen“)

---

## Tests

| # | Schritt | Erwartung | OK |
|---|---------|-----------|-----|
| 1 | User auf TOS v1.0, Admin aktiviert v2.0 | `getRequiredReConsents` listet TOS mit `blocking: true` | ☑ |
| 2 | App start / Login | Blocking Modal (Device-Gate und/oder Re-Consent) | ☑ |
| 3 | Accept TOS v2.0 | `recordLegalConsent`, `_User.acceptedTermsVersion=2.0` | ☑ |
| 4 | `createInvestmentSplits` | Erfolg (sofern sonstige Gates passieren) | ☑ |
| 5 | Investor: neue `investor_agreement`-Version | Scroll-to-Accept + Checkbox, dann frei | ☑ |
| 6 | Frisch registrierter User (gleiche Version) | Kein redundantes Modal nach Gate 1 Mirror | ☑ |
| 7 | API ohne Accept | `productAccessGate` → `OPERATION_FORBIDDEN` | ☑ |
| 8 | `LegalConsent` Audit | Zeile mit `source: app`, Version, IP, deviceInstallId | ☑ |

**Hinweis zu #2:** Bei reinem AGB-Bump erscheint oft das **Device Gate** statt `ReConsentModalView` — beides blockiert korrekt. Für gezielten Test der neuen UI → Checkliste #5 (nur `investor_agreement` bumpen).

---

## Ergebnis

| | |
|---|---|
| **Go / No-Go** | ☑ Go ☐ No-Go |
| **Datum** | 2026-06-29 |
| **Umgebung** | Staging (`192.168.178.24`) |
| **Bemerkungen** | Manuelle Abnahme + CI grün; iOS `main`: `0a6f97d` (Re-Consent/Dashboard), `dc5ab07` (file-size trader), `d604301` (Depot KAUFEN), `9de2368` (AuthView-Split + BuyOrder L2). Kein Parse-Cloud-/Admin-Deploy in dieser Welle. Parse health OK; Post-Deploy-Smoke admin + commission OK (`legalAppName` 4-eyes Flake — bekannt, nicht release-blockierend). |
