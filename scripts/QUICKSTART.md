# FIN1 Server Setup - Schnellstart Anleitung

## Schritt-für-Schritt Anleitung

### Voraussetzungen prüfen

✅ Ubuntu 24.04 LTS Rechner im selben WLAN wie der Mac
✅ Beide Rechner nutzen die Fritzbox
✅ SSH-Zugriff auf Ubuntu (oder Zugriff auf Ubuntu-Terminal)

---

## Schritt 1: Fritzbox konfigurieren (5-10 Minuten)

**Ziel:** Ubuntu-Server im Netzwerk finden und feste IP vergeben

1. **Fritzbox öffnen:**
   - Browser: `http://fritz.box` oder `http://192.168.178.1`
   - Mit Admin-Zugangsdaten anmelden

2. **Ubuntu-Server finden:**
   - Menü: `Heimnetz` → `Netzwerk` → `Geräte und Benutzer`
   - Ubuntu-Server in der Liste finden (evtl. als "unbekanntes Gerät")
   - **IP-Adresse notieren!** (z.B. `192.168.178.50`)

3. **Feste IP vergeben:**
   - Auf Ubuntu-Server klicken → `Bearbeiten`
   - ✅ `Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen` aktivieren
   - IP-Adresse wählen (z.B. `192.168.178.50`)
   - `Übernehmen`

4. **Gerätenamen vergeben (optional):**
   - Gerätename: "FIN1-Server" oder "Ubuntu-Server"
   - Erleichtert spätere Identifikation

**✅ Fertig:** Ubuntu-Server hat jetzt eine feste IP-Adresse

---

## Schritt 2: SSH-Zugriff einrichten (2-3 Minuten)

**Ziel:** Vom Mac aus auf Ubuntu zugreifen können

### Option A: SSH-Key bereits vorhanden

```bash
# Testen ob SSH funktioniert
ssh user@192.168.178.50  # Ubuntu-IP einsetzen
```

### Option B: SSH-Key erstellen und kopieren

```bash
# 1. SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "fin1-deployment"
# Enter drücken für Standard-Speicherort
# Passphrase optional (Enter für keine)

# 2. Key auf Ubuntu kopieren
ssh-copy-id user@192.168.178.50  # Ubuntu-IP und User einsetzen

# 3. Verbindung testen
ssh user@192.168.178.50
```

**✅ Fertig:** SSH-Zugriff funktioniert ohne Passwort

---

## Schritt 3: Ubuntu-Server finden (automatisch) (1 Minute)

**Ziel:** IP-Adresse des Ubuntu-Servers bestätigen

```bash
cd /Users/ra/app/FIN1
./scripts/find-ubuntu-server.sh
```

Das Skript zeigt:
- Gefundene Ubuntu-Server im Netzwerk
- IP-Adressen
- Vorschlag für Deployment

**✅ Fertig:** Ubuntu-Server IP-Adresse bekannt

---

## Schritt 4: Server einrichten (automatisch) (5-10 Minuten)

**Ziel:** Docker installieren und Server vorbereiten

### Option A: All-in-One (Empfohlen)

```bash
cd /Users/ra/app/FIN1
./scripts/quick-deploy.sh
```

Das Skript führt automatisch durch:
- Ubuntu-Server finden
- Docker installieren
- Dateien kopieren
- Konfiguration anpassen
- Server starten

### Option B: Schrittweise

```bash
# 1. Deployment durchführen
cd /Users/ra/app/FIN1
./scripts/deploy-to-ubuntu.sh 192.168.178.50 ubuntu
# IP und User anpassen!

# 2. Auf Ubuntu: Docker-Gruppe aktivieren (falls nötig)
ssh ubuntu@192.168.178.50
newgrp docker
exit

# 3. Deployment erneut starten (falls nötig)
./scripts/deploy-to-ubuntu.sh 192.168.178.50 ubuntu
```

**✅ Fertig:** Server ist vorbereitet, Dateien sind kopiert

---

## Schritt 5: Passwörter ändern (WICHTIG!) (5 Minuten)

**Ziel:** Alle Standard-Passwörter durch sichere ersetzen

```bash
# Auf Ubuntu verbinden
ssh ubuntu@192.168.178.50  # IP anpassen

# .env-Datei bearbeiten
cd ~/fin1-server/backend
nano .env
```

**Mindestens diese Passwörter ändern:**

```bash
# Starke Passwörter generieren (auf Mac)
openssl rand -base64 32

# In .env ändern:
PARSE_SERVER_MASTER_KEY=<generiertes-passwort>
MONGO_INITDB_ROOT_PASSWORD=<generiertes-passwort>
POSTGRES_PASSWORD=<generiertes-passwort>
REDIS_PASSWORD=<generiertes-passwort>
JWT_SECRET=<generiertes-passwort>
ENCRYPTION_KEY=<32-zeichen-langer-string>
```

**Speichern:** `Ctrl+O`, `Enter`, `Ctrl+X`

**✅ Fertig:** Alle Passwörter sind sicher

---

## Schritt 6: Server starten (2-3 Minuten)

**Ziel:** Alle Services starten und testen

```bash
# Auf Ubuntu
cd ~/fin1-server
docker compose -f docker-compose.production.yml up -d
```

**Services prüfen:**

```bash
# Status anzeigen
docker compose ps

# Logs anzeigen
docker compose logs -f

# Nach ein paar Sekunden: Logs beenden mit Ctrl+C
```

**✅ Fertig:** Alle Services laufen

---

## Schritt 7: Server testen (1 Minute)

**Ziel:** Prüfen ob alles funktioniert

### Vom Mac aus:

```bash
# Health Check
curl http://192.168.178.50/health  # Ubuntu-IP einsetzen

# Parse Server
curl http://192.168.178.50:1338/parse/health
```

### Im Browser:

- **Health Check:** `http://192.168.178.50/health`
- **Parse Dashboard:** `http://192.168.178.50:1338/dashboard`
- **MinIO Console:** `http://192.168.178.50:9001`

**✅ Fertig:** Server läuft und antwortet

---

## Schritt 8: iOS-App konfigurieren (später)

**Ziel:** App auf Server zeigen

In der iOS-App die API-URL ändern:
- Von: `http://localhost:1337/parse`
- Zu: `http://192.168.178.50:1338/parse` (Ubuntu-IP einsetzen)

---

## Zusammenfassung - Checkliste

- [ ] **Schritt 1:** Fritzbox konfiguriert, feste IP vergeben
- [ ] **Schritt 2:** SSH-Zugriff funktioniert
- [ ] **Schritt 3:** Ubuntu-Server gefunden
- [ ] **Schritt 4:** Server eingerichtet, Dateien kopiert
- [ ] **Schritt 5:** Passwörter geändert
- [ ] **Schritt 6:** Services gestartet
- [ ] **Schritt 7:** Server getestet, Health Check OK
- [ ] **Schritt 8:** iOS-App konfiguriert (später)

---

## Nützliche Befehle

### Services verwalten

```bash
# Auf Ubuntu
cd ~/fin1-server

# Status
docker compose ps

# Logs
docker compose logs -f

# Neu starten
docker compose restart

# Stoppen
docker compose down

# Starten
docker compose up -d
```

### Vom Mac aus

```bash
# Logs anzeigen
ssh ubuntu@192.168.178.50 'cd ~/fin1-server && docker compose logs -f'

# Services neu starten
ssh ubuntu@192.168.178.50 'cd ~/fin1-server && docker compose restart'
```

---

## Troubleshooting

### SSH-Verbindung fehlgeschlagen

```bash
# Prüfen ob Ubuntu im Netzwerk ist
ping 192.168.178.50

# SSH-Service auf Ubuntu prüfen
ssh ubuntu@192.168.178.50 'sudo systemctl status ssh'
```

### Docker nicht verfügbar

```bash
# Auf Ubuntu
newgrp docker
# Oder neu einloggen
```

### Services starten nicht

```bash
# Logs prüfen
docker compose logs parse-server

# Container neu erstellen
docker compose up -d --force-recreate
```

---

## Hilfe

- **Detaillierte Anleitung:** `scripts/UBUNTU_SERVER_SETUP.md`
- **Fritzbox-Setup:** `scripts/FRITZBOX_SETUP.md`
- **Deployment-Doku:** `scripts/README-UBUNTU-DEPLOYMENT.md`
