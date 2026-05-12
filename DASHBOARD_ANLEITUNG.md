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

### „Server not reachable“ / unable to connect to server

Das Dashboard lädt die **Parse-API-URL** aus `PARSE_DASHBOARD_SERVER_URL` (sonst `PARSE_SERVER_PUBLIC_SERVER_URL`) in **`backend/.env`** und ruft sie **vom Browser aus** auf — nicht vom Server.

| Du öffnest das Dashboard unter … | Der Browser muss dann `…/parse` unter derselben Basis erreichen können |
|-----------------------------------|---------------------------------------------------------------------------|
| `https://192.168.178.24/dashboard/` | `PARSE_DASHBOARD_SERVER_URL=https://192.168.178.24/parse` passt (Zertifikat im Browser akzeptieren). |
| `https://127.0.0.1:8443/dashboard/` (Tunnel) | `https://192.168.178.24/parse` geht nur, wenn dein Rechner **192.168.178.24** per HTTPS erreicht. Sonst: **Dashboard unter derselben Host-URL öffnen wie in `PARSE_DASHBOARD_SERVER_URL`**, oder Tunnel so legen, dass **`https://127.0.0.1:8443/parse`** wirklich auf den Server zeigt — dann in `backend/.env` z. B. `PARSE_DASHBOARD_SERVER_URL=https://127.0.0.1:8443/parse` setzen und **parse-server** neu starten (nur sinnvoll, wenn alle denselben Tunnel-Port nutzen). |

Empfehlung: **`https://192.168.178.24/dashboard/`** im LAN nutzen, oder **`ssh -L 443:127.0.0.1:443`** und **`https://localhost/dashboard/`** mit `PARSE_DASHBOARD_SERVER_URL=https://127.0.0.1/parse` (bzw. `https://localhost/parse`), damit Dashboard und API für den Browser **dieselbe Origin** haben.

### 403 Forbidden trotz SSH-Tunnel?

Nginx erlaubt `/dashboard/` nur von bestimmten Quell-IPs. Nach `ssh -L …:127.0.0.1:443` sieht der **Nginx-Container** die Verbindung oft als **Docker-Gateway** der Compose-Bridge (z. B. `172.19.0.1`, `172.18.0.1`, `172.17.0.1`), nicht als `127.0.0.1`. Zusätzlich sind **private LANs** (`192.168.0.0/16`, `10.0.0.0/8`) freigegeben, damit **`https://192.168.x.x/dashboard/`** vom Heimnetz aus funktioniert. Im Repo: `backend/nginx/nginx.conf` — nach Änderung **Nginx-Container neu laden**. Wenn es weiter 403 gibt: `docker inspect fin1-nginx` → `Networks` → `Gateway` prüfen und ggf. ergänzen; Access-Log für `$remote_addr`.

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
