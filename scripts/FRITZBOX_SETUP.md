# Fritzbox Konfiguration für FIN1 Server Setup

Diese Anleitung beschreibt die notwendigen Fritzbox-Einstellungen, um den Ubuntu-Server im WLAN zu finden und optimal zu konfigurieren.

## Voraussetzungen

- Fritzbox OS 8.3 oder höher
- Zugriff auf die Fritzbox-Weboberfläche
- Admin-Zugangsdaten

## Schritt 1: Fritzbox-Weboberfläche öffnen

1. **Fritzbox-IP ermitteln:**
   ```bash
   # Auf Mac: Standard-IPs
   # http://fritz.box
   # http://192.168.178.1
   # http://192.168.1.1
   ```

2. **Weboberfläche öffnen:**
   - Browser öffnen
   - URL eingeben: `http://fritz.box` oder `http://192.168.178.1`
   - Mit Admin-Zugangsdaten anmelden

## Schritt 2: Ubuntu-Server im Netzwerk identifizieren

### Option A: Über Geräteliste (Empfohlen)

1. **Menü öffnen:**
   - `Heimnetz` → `Netzwerk` → `Geräte und Benutzer`

2. **Ubuntu-Server finden:**
   - Liste durchsuchen nach:
     - Gerätenamen mit "ubuntu" oder "linux"
     - Unbekannten Geräten
     - Geräten mit aktivem SSH (Port 22)

3. **Gerät identifizieren:**
   - Auf Gerät klicken → Details anzeigen
   - IP-Adresse notieren
   - MAC-Adresse notieren (für feste IP)

### Option B: Über WLAN-Geräte

1. **Menü öffnen:**
   - `WLAN` → `Funkkanal` → `WLAN-Geräte`

2. **Verbundene Geräte anzeigen:**
   - Alle WLAN-Geräte werden angezeigt
   - Ubuntu-Server durch MAC-Adresse oder Namen identifizieren

## Schritt 3: Feste IP-Adresse vergeben

**WICHTIG:** Dies erleichtert das Auffinden und die Konfiguration erheblich!

1. **Menü öffnen:**
   - `Heimnetz` → `Netzwerk` → `Geräte und Benutzer`

2. **Ubuntu-Server bearbeiten:**
   - Ubuntu-Server in der Liste finden
   - Auf Gerät klicken → `Bearbeiten` (Stift-Symbol)

3. **Feste IP konfigurieren:**
   - ✅ `Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen` aktivieren
   - IP-Adresse wählen (z.B. `192.168.178.50`)
   - **IP-Adresse notieren!** (wird für Deployment benötigt)
   - `Übernehmen` klicken

4. **Gerätenamen vergeben (optional, aber empfohlen):**
   - `Gerätename` eingeben: z.B. "FIN1-Server" oder "Ubuntu-Server"
   - Erleichtert die spätere Identifikation

## Schritt 4: Netzwerk-Sichtbarkeit aktivieren

### WLAN-Geräte sichtbar machen

1. **Menü öffnen:**
   - `WLAN` → `Funknetz` → `Funknetz-Name (SSID)`

2. **Einstellungen prüfen:**
   - SSID sollte sichtbar sein (für Netzwerk-Scans)
   - `WLAN-Geräte anzeigen` aktivieren

### Netzwerk-Scan aktivieren

1. **Menü öffnen:**
   - `Heimnetz` → `Netzwerk` → `Netzwerkübersicht`

2. **Geräte-Scan:**
   - Alle verbundenen Geräte werden angezeigt
   - Ubuntu-Server sollte hier erscheinen

## Schritt 5: Firewall-Einstellungen

### Lokale Verbindungen erlauben

1. **Menü öffnen:**
   - `Internet` → `Filter` → `Kindersicherung`

2. **Ubuntu-Server konfigurieren:**
   - Ubuntu-Server zur Liste der erlaubten Geräte hinzufügen
   - Oder: Kindersicherung für Server deaktivieren

### Firewall-Regeln (falls nötig)

1. **Menü öffnen:**
   - `Internet` → `Filter` → `Firewall`

2. **Einstellungen prüfen:**
   - Firewall sollte aktiviert sein
   - Lokale Verbindungen sollten standardmäßig erlaubt sein

## Schritt 6: Portfreigaben (Optional, für externen Zugriff)

**Hinweis:** Für lokales Netzwerk normalerweise nicht nötig, aber für späteren externen Zugriff hilfreich.

1. **Menü öffnen:**
   - `Internet` → `Freigaben` → `Portfreigaben`

2. **Neue Portfreigabe erstellen:**
   - `Neue Portfreigabe` klicken
   - **Gerät:** Ubuntu-Server auswählen
   - **Port:** `80` (HTTP)
   - **Protokoll:** TCP
   - `Übernehmen`

3. **Weitere Ports (optional):**
   - Port `443` (HTTPS)
   - Port `1337` (Parse Server)
   - Port `22` (SSH) - **Nur wenn externer SSH-Zugriff gewünscht!**

## Schritt 7: WLAN-Einstellungen optimieren

### WLAN-Sichtbarkeit für Netzwerk-Scans

1. **Menü öffnen:**
   - `WLAN` → `Funknetz` → `Funknetz-Name (SSID)`

2. **Einstellungen:**
   - SSID sollte nicht versteckt sein
   - `WLAN-Geräte anzeigen` aktivieren

### WLAN-Kanal und Signal

1. **Menü öffnen:**
   - `WLAN` → `Funkkanal` → `Funkkanal-Einstellungen`

2. **Optimale Einstellungen:**
   - Automatische Kanalwahl aktivieren
   - 5 GHz und 2.4 GHz aktivieren (falls verfügbar)

## Schritt 8: Netzwerk-Informationen sammeln

### Wichtige Informationen notieren

Nach der Konfiguration sollten Sie folgende Informationen haben:

1. **Ubuntu-Server IP-Adresse:** `192.168.178.XX`
2. **Fritzbox IP-Adresse:** `192.168.178.1` (Standard)
3. **Netzwerk-Bereich:** `192.168.178.0/24`
4. **Ubuntu-Server MAC-Adresse:** (für Identifikation)
5. **Ubuntu-Server Hostname:** (falls vergeben)

### Informationen aus Fritzbox abrufen

1. **Menü öffnen:**
   - `Heimnetz` → `Netzwerk` → `Netzwerkübersicht`

2. **Netzwerk-Details:**
   - Alle verbundenen Geräte
   - IP-Adressen
   - MAC-Adressen
   - Verbindungsstatus

## Schritt 9: SSH-Zugriff vorbereiten

### Port 22 freigeben (nur für lokales Netzwerk)

1. **Menü öffnen:**
   - `Internet` → `Freigaben` → `Portfreigaben`

2. **SSH-Portfreigabe:**
   - **Gerät:** Ubuntu-Server
   - **Port:** `22`
   - **Protokoll:** TCP
   - **Nur für lokales Netzwerk:** Aktivieren

**Hinweis:** Für lokales Netzwerk ist dies normalerweise nicht nötig, da die Fritzbox lokale Verbindungen standardmäßig erlaubt.

## Schritt 10: Netzwerk-Scan testen

### Vom Mac aus testen

```bash
# Netzwerk scannen
cd /Users/ra/app/FIN1
./scripts/find-ubuntu-server-v2026-01-30.sh
```

### Manuell testen

```bash
# Ping-Test
ping 192.168.178.50  # Ubuntu-IP einsetzen

# SSH-Test
ssh user@192.168.178.50  # Ubuntu-IP einsetzen

# Port-Scan (falls nmap installiert)
nmap -p 22,80,1337 192.168.178.50
```

## Troubleshooting

### Ubuntu-Server wird nicht gefunden

1. **Geräteliste prüfen:**
   - Fritzbox: `Heimnetz` → `Netzwerk` → `Geräte und Benutzer`
   - Prüfen ob Ubuntu-Server verbunden ist

2. **WLAN-Verbindung prüfen:**
   - Auf Ubuntu: `ip addr` oder `ifconfig`
   - Prüfen ob WLAN-Interface aktiv ist

3. **IP-Adresse manuell ermitteln:**
   ```bash
   # Auf Ubuntu
   hostname -I
   ip addr show
   ```

4. **Netzwerk-Scan manuell:**
   ```bash
   # Vom Mac
   arp -a | grep -i ubuntu
   nmap -sn 192.168.178.0/24
   ```

### Feste IP funktioniert nicht

1. **DHCP-Einstellungen prüfen:**
   - Fritzbox: `Heimnetz` → `Netzwerk` → `Netzwerkeinstellungen`
   - DHCP-Bereich prüfen
   - Sicherstellen, dass vergebene IP außerhalb des DHCP-Bereichs liegt

2. **Ubuntu-Server neu verbinden:**
   - WLAN-Verbindung trennen und wieder verbinden
   - Oder: Netzwerk-Interface neu starten

### SSH-Verbindung fehlgeschlagen

1. **Firewall prüfen:**
   - Fritzbox: `Internet` → `Filter` → `Firewall`
   - Lokale Verbindungen sollten erlaubt sein

2. **Port 22 prüfen:**
   ```bash
   # Auf Ubuntu
   sudo systemctl status ssh
   sudo ufw status
   ```

3. **SSH-Service aktivieren:**
   ```bash
   # Auf Ubuntu
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```

## Nützliche Fritzbox-URLs

- **Weboberfläche:** `http://fritz.box` oder `http://192.168.178.1`
- **Geräteliste:** `http://fritz.box/?lp=netDevices`
- **Netzwerkübersicht:** `http://fritz.box/?lp=network`
- **Portfreigaben:** `http://fritz.box/?lp=fwPorts`

## Zusammenfassung der wichtigsten Einstellungen

✅ **Feste IP vergeben** - Erleichtert Auffinden und Konfiguration
✅ **Gerätenamen vergeben** - Erleichtert Identifikation
✅ **WLAN-Geräte anzeigen** - Für Netzwerk-Scans
✅ **Lokale Verbindungen erlauben** - Für SSH und Services
✅ **Portfreigaben** (optional) - Für späteren externen Zugriff

## Nächste Schritte

Nach der Fritzbox-Konfiguration:

1. **Ubuntu-Server finden:**
   ```bash
   ./scripts/find-ubuntu-server-v2026-01-30.sh
   ```

2. **Deployment durchführen:**
   ```bash
   ./scripts/deploy-to-ubuntu-v2026-01-30.sh [ubuntu-ip] [ubuntu-user]
   ```

3. **Server testen:**
   ```bash
   curl http://ubuntu-ip/health
   ```
