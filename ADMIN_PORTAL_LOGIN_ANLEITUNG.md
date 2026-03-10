# 🔐 Admin-Portal Login-Anleitung

**Datum:** 2026-02-05
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

| E-Mail | Passwort | Rolle | Status |
|--------|----------|-------|--------|
| `admin@test.com` | `Password123!` | admin | active |
| `trader1@test.com` | `Password123!` | trader | active |
| `investor1@test.com` | `Password123!` | investor | active |

**Hinweis:** Diese Test-User müssen zuerst erstellt werden (siehe Option 1 oder Cloud Function).

---

### Option 3: Passwort zurücksetzen (Development)

**Falls User existiert, aber Passwort unbekannt:**

```bash
# Via Cloud Function (nur Development!)
curl -k -X POST https://192.168.178.24/parse/functions/resetDevUserPassword \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@test.com"}'

# Antwort:
# {
#   "success": true,
#   "message": "Password reset for admin@test.com",
#   "newPassword": "DevTest123!Secure"
# }
```

**Neues Passwort:** `DevTest123!Secure`

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

- Wenn 2FA aktiviert ist, wird ein QR-Code oder Eingabefeld angezeigt
- Gib den 6-stelligen Code aus deiner Authenticator-App ein

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

### Problem: "Login fehlgeschlagen" / "Invalid credentials"

**Lösungen:**
1. **Prüfe, ob User existiert:**
   ```bash
   # Parse Dashboard → Browser → _User
   # Suche nach deiner E-Mail
   ```

2. **Prüfe Rolle:**
   - User muss eine Admin-Rolle haben (`admin`, `business_admin`, etc.)
   - Normale `investor` oder `trader` User können sich nicht anmelden

3. **Passwort zurücksetzen:**
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

### Via Cloud Function:

```bash
curl -k -X POST https://192.168.178.24/parse/functions/createTestUsers \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json"
```

**Erstellt:**
- `trader3@test.com` / `TestPassword123!Secure`
- `investor1@test.com` / `TestPassword123!Secure`
- `investor2@test.com` / `TestPassword123!Secure`

**Hinweis:** Diese User haben keine Admin-Rolle! Für Admin-Portal-Zugriff muss Rolle auf `admin` gesetzt werden.

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

**Falls Test-User gewünscht:**
- E-Mail: `admin@test.com`
- Passwort: `Password123!` (muss zuerst erstellt werden)
- Rolle: `admin` (muss gesetzt werden)

---

**Bei Problemen:** Prüfe Parse Dashboard → `_User` Klasse, ob User existiert und korrekte Rolle hat.
