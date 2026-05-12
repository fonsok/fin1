# Parse Dashboard - Anleitung

**Status:** ✅ Dashboard ist aktiviert und erreichbar!

---

## 🔗 Dashboard-Zugriff

**Empfohlen (per SSH-Tunnel):**
```bash
ssh -L 443:127.0.0.1:443 io@192.168.178.24
```
Dann im Browser: **`https://localhost/dashboard/`**

**Login:**
- **User:** `admin`
- **Password:** `CHANGE-THIS-ADMIN-PASSWORD` (aus `.env`)

**Hinweis:** Das Passwort steht in `backend/.env` unter `DASHBOARD_PASSWORD`

### 403 Forbidden trotz SSH-Tunnel?

Nginx erlaubt `/dashboard/` nur von bestimmten Quell-IPs. Nach `ssh -L …:127.0.0.1:443` sieht der **Nginx-Container** die Verbindung oft als **Docker-Gateway** der Compose-Bridge (z. B. `172.19.0.1`, `172.18.0.1`, `172.17.0.1`), nicht als `127.0.0.1`. Im Repo sind typische Gateways in `backend/nginx/nginx.conf` freigegeben — nach Änderung **Nginx-Container neu laden**. Wenn es weiter 403 gibt: `docker inspect fin1-nginx` → `Networks` → `Gateway` prüfen und diese IP ergänzen; optional Access-Log.

---

## 📋 ComplianceEvent-Klasse erstellen

### Schritt-für-Schritt:

1. **Dashboard öffnen:** Zuerst SSH-Tunnel (siehe oben), dann `https://localhost/dashboard/`

2. **Login mit:**
   - User: `admin`
   - Password: `CHANGE-THIS-ADMIN-PASSWORD`

3. **Schema öffnen:**
   - Links im Menü: **"Schema"** klicken

4. **Neue Klasse erstellen:**
   - Button: **"Create a class"** klicken
   - Class Name: `ComplianceEvent`
   - Klicke: **"Create class"**

5. **Felder hinzufügen:**

   Für jedes Feld: **"Add a new column"** klicken

   | Feldname | Typ | Required | Default |
   |----------|-----|----------|---------|
   | `userId` | String | ✅ Yes | - |
   | `eventType` | String | ✅ Yes | - |
   | `description` | String | ✅ Yes | - |
   | `metadata` | Object | ❌ No | - |
   | `timestamp` | Date | ✅ Yes | - |
   | `regulatoryFlags` | Array | ❌ No | - |

6. **Fertig!** ✅

---

## 🎯 Dashboard-Features

Das Parse Dashboard bietet:

- **Schema Management:** Klassen erstellen, bearbeiten, löschen
- **Data Browser:** Daten anzeigen, bearbeiten, löschen
- **Cloud Code:** Cloud Functions verwalten
- **Jobs:** Background Jobs verwalten
- **Logs:** Server-Logs anzeigen
- **Settings:** Server-Einstellungen

---

## 🔒 Sicherheit

**Wichtig:** Das Dashboard ist jetzt auch in Production aktiviert.

**Empfehlung:**
1. Starkes Passwort in `.env` setzen:
   ```
   DASHBOARD_PASSWORD=dein-starkes-passwort-hier
   ```

2. Dashboard nur im lokalen Netzwerk zugänglich lassen (Firewall)

3. Bei Bedarf Dashboard wieder deaktivieren (Code ändern)

---

## 🧪 Testen

Nachdem die ComplianceEvent-Klasse erstellt wurde:

1. **App neu starten**
2. **Console-Logs prüfen:**
   - Sollte keine 500-Fehler mehr zeigen
   - Compliance Events sollten erfolgreich gespeichert werden

3. **Dashboard prüfen:**
   - Data Browser → ComplianceEvent
   - Sollte Objekte zeigen, die von der App erstellt wurden

---

## 📝 Alternative: API

Falls das Dashboard nicht funktioniert, kann die Klasse auch automatisch erstellt werden:

Parse Server erstellt Klassen automatisch beim ersten Objekt-Save. Die App wird die Klasse beim nächsten Compliance Event automatisch erstellen.
