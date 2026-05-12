# 🔐 Admin-Portal Login-Anleitung

**Datum:** 2026-04-04
**Status:** ✅ Aktuell

---

## 🌐 Zugriff auf das Admin-Portal

**URL:** `https://192.168.178.24/admin/`

**Alternative URLs:**
- HTTPS: `https://192.168.178.24/admin/` (Self-signed Zertifikat - Browser-Ausnahme erforderlich)
- Local Dev: `http://localhost:3000/` (wenn lokal gestartet)

---

## 🔑 Login-Zugangsdaten

### Option 1: Admin-User erstellen (empfohlen)

**1. Admin-User über Parse Dashboard erstellen:**

```bash
# 1. Parse Dashboard öffnen
https://localhost/dashboard/ (nur nach SSH-Tunnel: `ssh -L 443:127.0.0.1:443 io@192.168.178.24`)

# 2. Login mit Dashboard-Credentials:
# User: admin
# Password: [siehe backend/.env → DASHBOARD_PASSWORD]

# 3. In Dashboard: "Browser" → "_User" → "Add a new row"
# 4. Felder ausfüllen:
#    - username: admin@fin1.de (oder deine E-Mail)
#    - email: admin@fin1.de
#    - password: [dein-sicheres-passwort]
#    - role: admin
#    - status: active
# 5. Speichern
```

**2. Oder über Cloud Function (wenn verfügbar):**

```bash
# Via curl oder Parse Dashboard Cloud Code
curl -k -X POST https://192.168.178.24/parse/functions/createTestUsers \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json"
```

---

### Option 2: Test-User verwenden (Development)

**Falls Test-User bereits existieren:**

| E-Mail | Passwort / Quelle | Rolle | Portal-Zugang |
|--------|-------------------|-------|----------------|
| `admin@test.com` | `TestConstants.password` in `FIN1/Shared/Constants/TestUserConstants.swift` | admin | Ja (wenn Rolle `admin` und Status `active`) |
| `investor1@test.com` … `investor5@test.com` | dieselbe Konstante | investor | Nein (nur App) |
| `trader1@test.com` … `trader10@test.com` | dieselbe Konstante | trader | Nein (nur App) |

**Hinweis:** Passwort und Namen sind mit `FIN1/Shared/Constants/TestUserConstants.swift` und Backend-Seed `seedTestUsers` abgestimmt. User müssen existieren (z. B. über `seedTestUsers` oder manuelle Anlage). **Investor/Trader** können sich **nicht** im Admin-Web-Portal anmelden — nur über die iOS-App bzw. Parse-API.

---

### Option 3: Passwort zurücksetzen (Development)

**Falls User existiert, aber Passwort unbekannt:**

```bash
# Via Cloud Function (nur Development!)
curl -k -X POST https://192.168.178.24/parse/functions/resetDevUserPassword \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@test.com"}'

# Antwort enthält u.a.:
#   "newPassword": "<vom Server generiertes Passwort>"
```

Das zurückgesetzte Passwort liefert die Cloud Function **nur** in der Antwort (`newPassword`); nicht in Doku hardcoden.

---

## 📝 Login-Schritte

### 1. Admin-Portal öffnen

```
https://192.168.178.24/admin/
```

### 2. Login-Formular ausfüllen

- **E-Mail:** Deine Admin-E-Mail (z.B. `admin@fin1.de` oder `admin@test.com`)
- **Passwort:** Dein Passwort

### 3. Anmelden

- Klicke auf **"Anmelden"**
- Bei erfolgreicher Anmeldung wirst du zum Dashboard weitergeleitet

### 4. 2FA-Verifizierung (falls aktiviert)

- Nach dem Passwort erscheint die 2FA-Maske im Portal.
- **Authenticator:** 6-stelliger Code aus der Authenticator-App.
- **Backup-Code:** Umschalten auf „Backup-Code (8 Zeichen)“ und einen der beim Aktivieren gespeicherten **8-stelligen** Codes eingeben (alphanumerisch).

---

## 🔒 Unterstützte Rollen

Das Admin-Portal unterstützt folgende Rollen:

| Rolle | Zugriff |
|-------|---------|
| **admin** | Vollzugriff auf alle Funktionen |
| **business_admin** | Financial Dashboard, Korrekturen, Reports |
| **security_officer** | Security Dashboard, Session-Management |
| **compliance** | Compliance-Events, 4-Augen-Freigaben |
| **customer_service** | User-Support, Tickets |

**Hinweis:** Nur User mit Admin-Rolle (`admin`, `business_admin`, etc.) können sich anmelden.

---

## ⚠️ Häufige Probleme

### Problem: Account temporär gesperrt (Lockout)

Nach **3 fehlgeschlagenen** Login-Versuchen sperrt Parse Server das Konto für **5 Minuten** (Standard in `backend/parse-server/index.js`, `accountLockout`). Meldung oft auf Englisch (*locked … try again after 5 minute(s)*).

**Lösungen:** Warten oder Passwort mit Master-Key per `createAdminUser` und `forcePasswordReset: true` setzen (siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`, Abschnitt Account-Lockout und Business Admin).

### Problem: Business Admin (`finance@fin1.de`) – Passwort unbekannt

Das Skript `scripts/create-business-admin.sh` setzt das Passwort nur, wenn `createAdminUser`/`forcePasswordReset` greift; **`BA_PASSWORD` ist Pflicht** beim Aufruf. Auf bestehenden Servern weicht das Live-Passwort oft ab. **Zurücksetzen:** `createAdminUser` mit `role: "business_admin"` und `forcePasswordReset: true` (vollständiges `curl`-Beispiel in `WEB_PANEL_LOGIN_CREDENTIALS.md`).

### Problem: "Login fehlgeschlagen" / "Invalid credentials"

**Lösungen:**
1. **Application ID bei API-Calls:** `fin1-app-id` verwenden (nicht `fin1`), siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`.
2. **Prüfe, ob User existiert:**
   ```bash
   # Parse Dashboard → Browser → _User
   # Suche nach deiner E-Mail
   ```

3. **Prüfe Rolle:**
   - User muss eine Admin-Rolle haben (`admin`, `business_admin`, etc.)
   - Normale `investor` oder `trader` User können sich nicht anmelden

4. **Passwort zurücksetzen:**
   - Siehe Option 3 oben (Development)
   - Oder über Parse Dashboard: User bearbeiten → Passwort ändern

### Problem: "User not found"

**Lösung:**
- User muss zuerst erstellt werden (siehe Option 1)

### Problem: "Insufficient permissions"

**Lösung:**
- User-Rolle muss eine Admin-Rolle sein
- Prüfe in Parse Dashboard: `_User` → `role` Feld

---

## 🧪 Test-User erstellen (Development)

### Investoren + Trader mit vollem Profil (empfohlen)

Cloud Function **`seedTestUsers`** (Master-Key, Admin-Kontext): legt **5 Investoren** und **10 Trader** mit abgeschlossenem Onboarding an; Passwort wie in `TestUserConstants.swift` / Seed-Code. Siehe `backend/parse-server/cloud/functions/seed/users.js`.

### Legacy / andere Skripte

Falls in eurer Umgebung noch **`createTestUsers`** o. Ä. existiert: Dokumentation der erzeugten Mails/Passwörter der jeweiligen Funktion im Repo prüfen — kanonisch für die aktuelle App sind **`TestUserConstants.swift`** und `seedTestUsers` (keine Klartext-Passwörter in Markdown).

**Hinweis:** Investor/Trader haben **keine** Admin-Rolle und **keinen** Web-Portal-Login. Für das Portal weiterhin **`createAdminUser`** oder Dashboard mit Rolle `admin` verwenden.

---

## 📋 Quick-Start Checkliste

- [ ] Admin-Portal öffnen: `https://192.168.178.24/admin/`
- [ ] Parse Dashboard öffnen: `https://localhost/dashboard/` (nur nach SSH-Tunnel: `ssh -L 443:127.0.0.1:443 io@192.168.178.24`)
- [ ] Admin-User erstellen (falls nicht vorhanden)
- [ ] Rolle auf `admin` setzen
- [ ] Status auf `active` setzen
- [ ] Im Admin-Portal anmelden
- [ ] 2FA einrichten (falls erforderlich)

---

## 🔐 Sicherheitshinweise

### Production:

1. **Starkes Passwort verwenden:**
   - Mindestens 12 Zeichen
   - Groß-/Kleinbuchstaben, Zahlen, Sonderzeichen

2. **2FA aktivieren:**
   - Für alle Admin-Rollen empfohlen
   - Über Admin-Portal → Einstellungen → 2FA Setup

3. **Session-Management:**
   - Automatischer Logout nach 30 Minuten Inaktivität
   - Logout-Button in Navigation

4. **Passwort-Reset:**
   - Über Admin-Portal → Einstellungen
   - Oder über Parse Dashboard

---

## 📚 Referenzen

- **Admin-Portal README:** `admin-portal/README.md`
- **Web-Panel / CSR Login-Übersicht:** `WEB_PANEL_LOGIN_CREDENTIALS.md`
- **Parse Dashboard:** `DASHBOARD_ANLEITUNG.md`
- **Authentication:** `Documentation/AUTHENTICATION_ARCHITECTURE.md`
- **Admin Roles:** `Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md`

---

## ✅ Zusammenfassung

**Schnellste Methode:**

1. Parse Dashboard öffnen: `https://localhost/dashboard/` (nur nach SSH-Tunnel: `ssh -L 443:127.0.0.1:443 io@192.168.178.24`)
2. Admin-User erstellen mit Rolle `admin`
3. Admin-Portal öffnen: `https://192.168.178.24/admin/`
4. Mit erstellten Credentials anmelden

**Falls Test-Admin gewünscht:**
- E-Mail: `admin@test.com`
- Passwort: wie `TestConstants.password` in `TestUserConstants.swift` nach Seed/Mock; sonst wie von `createAdminUser` gesetzt
- Rolle: `admin` (muss gesetzt werden)

---

**Bei Problemen:** Prüfe Parse Dashboard → `_User` Klasse, ob User existiert und korrekte Rolle hat.
