# FIN1 Setup mit Cursor auf Ubuntu

Diese Anleitung zeigt, wie Sie die restlichen Schritte mit Cursor auf Ubuntu erledigen.

## Schritt 1: Projekt in Cursor öffnen

1. **Cursor auf Ubuntu öffnen**
2. **Datei** → **Ordner öffnen**
3. Navigieren zu: `~/fin1-server`
4. Öffnen

## Schritt 2: Passwörter automatisch setzen

### Option A: Mit Skript (Empfohlen)

1. **Terminal in Cursor öffnen** (Terminal → Neues Terminal)
2. **Skript ausführen:**

```bash
cd ~/fin1-server
# Skript vom Mac kopieren (falls noch nicht vorhanden)
# Oder manuell die Passwörter generieren:
```

### Option B: Manuell in Cursor

1. **Datei öffnen:** `backend/.env`
2. **Passwörter generieren** (im Terminal):

```bash
# Im Cursor-Terminal auf Ubuntu
openssl rand -base64 32
```

3. **In .env ersetzen:**
   - `PARSE_SERVER_MASTER_KEY=` → neues Passwort
   - `MONGO_INITDB_ROOT_PASSWORD=` → neues Passwort
   - `POSTGRES_PASSWORD=` → neues Passwort
   - `REDIS_PASSWORD=` → neues Passwort
   - `JWT_SECRET=` → neues Passwort
   - `ENCRYPTION_KEY=` → neues Passwort (32 Zeichen)

**Wichtig:** Jedes Passwort muss unterschiedlich sein!

## Schritt 3: Server starten

Im Cursor-Terminal auf Ubuntu:

```bash
cd ~/fin1-server
docker compose -f docker-compose.production.yml up -d
```

## Schritt 4: Status prüfen

```bash
# Services prüfen
docker compose ps

# Logs anzeigen
docker compose logs -f
# Mit Ctrl+C beenden
```

## Schritt 5: Testen

Im Cursor-Terminal:

```bash
# Health Check
curl http://192.168.178.20/health

# Parse Server
curl http://192.168.178.20:1338/parse/health
```

## Tipps für Cursor

- **Dateien suchen:** `Cmd+P` (oder `Ctrl+P`)
- **Terminal:** `Ctrl+`` (Backtick)
- **Datei öffnen:** `Cmd+P` → `.env` eingeben
- **Suchen/Ersetzen:** `Cmd+Shift+F`

## Troubleshooting

### Docker nicht verfügbar

```bash
# Docker-Gruppe aktivieren
newgrp docker
```

### Services starten nicht

```bash
# Logs prüfen
docker compose logs parse-server

# Container neu erstellen
docker compose up -d --force-recreate
```

### Port bereits belegt

```bash
# Port prüfen
sudo lsof -i :1337

# Prozess beenden
sudo kill -9 <PID>
```
