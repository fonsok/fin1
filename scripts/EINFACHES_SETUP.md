# FIN1 Einfaches Setup mit Cursor auf Ubuntu

## Schritt-für-Schritt Anleitung

### Schritt 1: Projekt in Cursor öffnen

1. **Cursor auf Ubuntu öffnen**
2. **Datei** → **Ordner öffnen** (oder `Ctrl+K Ctrl+O`)
3. Navigieren zu: `/home/io/fin1-server`
4. **Öffnen** klicken

### Schritt 2: Terminal in Cursor öffnen

1. **Terminal öffnen:**
   - Menü: **Terminal** → **Neues Terminal**
   - Oder Tastenkürzel: `Ctrl+Shift+`` (Backtick-Taste)
   - Oder unten auf **"Terminal"** klicken

2. **Terminal sollte unten erscheinen**

### Schritt 3: Passwörter automatisch setzen

**Im Terminal (ein einziger Befehl!):**

```bash
cd ~/fin1-server
bash auto-setup-passwords.sh
```

**Das war's!** Das Skript macht alles automatisch:
- ✅ Generiert sichere Passwörter
- ✅ Erstellt Backup der .env Datei
- ✅ Setzt alle Passwörter automatisch

### Schritt 4: Server starten

**Im Terminal:**

```bash
cd ~/fin1-server
docker compose -f docker-compose.production.yml up -d
```

**Warten Sie ca. 1-2 Minuten**, bis alle Services gestartet sind.

### Schritt 5: Status prüfen

**Im Terminal:**

```bash
# Services anzeigen
docker compose ps

# Sollte zeigen: alle Services "Up" (grün)
```

### Schritt 6: Testen

**Im Terminal:**

```bash
# Health Check
curl -sk https://192.168.178.20/health

# Sollte eine Antwort zurückgeben
```

## Falls das Skript nicht vorhanden ist

**Option A: Skript erstellen**

1. In Cursor: **Datei** → **Neue Datei** (`Ctrl+N`)
2. Name: `auto-setup-passwords.sh`
3. Inhalt: Siehe `scripts/auto-setup-passwords.sh` vom Mac
4. Speichern in: `~/fin1-server/`
5. Im Terminal: `chmod +x auto-setup-passwords.sh`

**Option B: Manuell (falls Skript nicht funktioniert)**

```bash
cd ~/fin1-server/backend
nano .env
```

Dann die Zeilen mit `CHANGE-THIS` durch zufällige Passwörter ersetzen.

## Troubleshooting

### "docker compose" nicht gefunden

```bash
# Docker-Gruppe aktivieren
newgrp docker

# Oder neu einloggen
exit
# Dann wieder einloggen
```

### Services starten nicht

```bash
# Logs anzeigen
docker compose logs parse-server

# Alle Logs
docker compose logs -f
```

### Port bereits belegt

```bash
# Port prüfen
sudo lsof -i :1337

# Prozess beenden (falls nötig)
sudo kill -9 <PID>
```

## Zusammenfassung - Die 3 Befehle

```bash
# 1. Passwörter setzen
cd ~/fin1-server && bash auto-setup-passwords.sh

# 2. Server starten
docker compose -f docker-compose.production.yml up -d

# 3. Testen
curl -sk https://192.168.178.20/health
```

**Das war's!** 🎉
