# Stellenausschreibung: Experte für Netzwerk-, Backend- und Frontend-Integration

## Projektübersicht

Wir suchen einen erfahrenen Experten für die optimale Vernetzung und Integration unserer FIN1-Investmentplattform. Das Projekt umfasst die nahtlose Verbindung zwischen einem Ubuntu-Server-Backend, einer Fritzbox-Netzwerkinfrastruktur und einer iOS-Entwicklungsumgebung.

## Aktuelle Infrastruktur

### Hardware & Netzwerk
- **Ubuntu 24.04 LTS Server** mit FIN1-Backend-Services
- **Fritzbox OS 8.2** als Router/WLAN-Access-Point
- **Mac (Tahoe)** mit Xcode für iOS-App-Entwicklung
- **Alle Geräte im selben WLAN** verbunden

### Backend-Stack (Ubuntu Server)
- **Parse Server** - Haupt-API und Authentifizierung (Port 1337) ✅ running
- **MongoDB** - Primärdatenbank für Benutzerdaten und Transaktionen (Port 27017) ✅ running
- **PostgreSQL** - Analytics und Reporting-Datenbank (Port 5432) ✅ running
- **Redis** - Caching und Session-Speicher (Port 6379) ✅ running
- **MinIO** - Dateispeicher (S3-kompatibel) (Port 9000) ✅ running
- **Nginx** - Reverse Proxy und Load Balancer (Port 80) ⚠️ restarting (Problem!)
- **Market Data Service** - Echtzeit-Trading-Daten (Port 8080) ⚠️ restarting (Problem!)
- **Notification Service** - Push-Benachrichtigungen
- **Analytics Service** - Datenverarbeitung und Reporting

Alle Services laufen in **Docker-Containern** (Docker Compose).

### Server-Management
- **FIN1 Server Control Panel** - Python-basiertes GUI-Tool zur Verwaltung der Services
  - Service-Status-Übersicht mit Health-Checks
  - Start/Stop/Restart-Funktionen für einzelne Services
  - Logs-Anzeige
  - Automatische Status-Updates

### Frontend
- **iOS-App (FIN1)** - Swift/SwiftUI-Anwendung
- Läuft aktuell im **iOS Simulator** auf dem Mac
- Nutzt Parse Server SDK für Backend-Kommunikation
- Benötigt Verbindung zu Backend-API und WebSocket-Live-Query

## Aktuelle Probleme & Herausforderungen

### Service-Stabilität
- **Nginx (Port 80)** befindet sich im kontinuierlichen "restarting" Status
- **Market Data Service (Port 8080)** befindet sich im kontinuierlichen "restarting" Status
- Diese Services müssen stabil laufen, damit die iOS-App korrekt funktioniert

### Netzwerk-Verbindung
- iOS-App im Simulator muss zuverlässig mit dem Ubuntu-Server kommunizieren können
- WebSocket-Verbindungen für Live-Query müssen stabil funktionieren

## Aufgabenstellung

Der Experte soll die gesamte Infrastruktur optimal "verkabeln" und folgende Bereiche abdecken:

### 1. Netzwerk-Konfiguration
- **Fritzbox-Optimierung:**
  - Feste IP-Adressen für Server und Mac vergeben
  - Portfreigaben für Backend-Services konfigurieren
  - Firewall-Regeln für lokale Kommunikation optimieren
  - WLAN-Einstellungen für optimale Performance
  - Netzwerk-Sichtbarkeit und Geräteerkennung sicherstellen

- **Ubuntu-Server Netzwerk:**
  - Netzwerk-Interface-Konfiguration optimieren
  - Firewall (UFW) für Backend-Services konfigurieren
  - Port-Zugriff für lokales Netzwerk sicherstellen
  - Netzwerk-Performance-Tuning

### 2. Backend-Integration
- **Service-Stabilität:**
  - **Nginx (Port 80)** - Aktuell im "restarting" Status, Ursache identifizieren und beheben
  - **Market Data Service (Port 8080)** - Aktuell im "restarting" Status, Ursache identifizieren und beheben
  - Alle Services sollten stabil im "running" Status sein

- **Parse Server Konfiguration:**
  - Server-URLs für lokales Netzwerk anpassen
  - CORS-Einstellungen für iOS-App konfigurieren
  - WebSocket-Live-Query für lokale Verbindungen einrichten
  - SSL/TLS für lokale Entwicklung (optional)

- **Docker & Services:**
  - Docker-Compose-Konfiguration für lokales Netzwerk optimieren
  - Service-Discovery und Inter-Service-Kommunikation sicherstellen
  - Health-Checks und Monitoring einrichten
  - Logging und Debugging-Konfiguration
  - Service-Restart-Loops analysieren und beheben

- **FIN1 Server Control Panel:**
  - Control Panel-Funktionalität validieren
  - Health-Check-Logik optimieren
  - Logs-Integration verbessern
  - Service-Management-Funktionen testen

- **Datenbank-Verbindungen:**
  - MongoDB, PostgreSQL und Redis für lokale Zugriffe konfigurieren
  - Verbindungs-Pooling optimieren
  - Backup-Strategien dokumentieren

### 3. Frontend-Integration
- **iOS-App Konfiguration:**
  - Parse Server URL auf Ubuntu-Server-IP umstellen
  - WebSocket-Verbindungen für Live-Query testen
  - Netzwerk-Fehlerbehandlung implementieren
  - Debugging-Tools für Netzwerk-Traffic einrichten

- **Entwicklungsumgebung:**
  - Xcode-Simulator-Netzwerk-Konfiguration
  - API-Testing-Tools einrichten
  - Netzwerk-Monitoring für App-Verbindungen

### 4. Dokumentation & Testing
- **Vollständige Dokumentation:**
  - Netzwerk-Architektur-Diagramm
  - Konfigurations-Anleitung für alle Komponenten
  - Troubleshooting-Guide
  - Schritt-für-Schritt-Setup-Anleitung

- **Testing & Validierung:**
  - End-to-End-Tests der Verbindungen
  - Performance-Tests
  - Stabilitätstests über längere Zeiträume
  - Fehlerbehandlung und Recovery-Tests

## Anforderungen an den Experten

### Technische Expertise
- **Netzwerk-Administration:**
  - Tiefgreifende Kenntnisse in TCP/IP, DNS, DHCP
  - Erfahrung mit Fritzbox-Konfiguration (OS 8.x)
  - Firewall-Management (UFW, iptables)
  - WLAN-Optimierung und Troubleshooting

- **Backend-Entwicklung:**
  - Docker und Docker Compose
  - Parse Server oder ähnliche BaaS-Lösungen
  - Node.js/JavaScript
  - Nginx-Konfiguration
  - Datenbank-Administration (MongoDB, PostgreSQL, Redis)

- **iOS-Entwicklung:**
  - Swift/SwiftUI-Grundkenntnisse
  - Parse SDK Integration
  - Netzwerk-Debugging in iOS
  - Xcode-Simulator-Konfiguration

- **DevOps & System-Administration:**
  - Linux-System-Administration (Ubuntu)
  - Service-Konfiguration und -Management
  - Docker-Container-Troubleshooting (Restart-Loops, Health-Checks)
  - Logging und Monitoring
  - Scripting (Bash, Python)
  - GUI-Entwicklung (Python/Tkinter optional, für Control Panel)

### Soft Skills
- **Kommunikation:**
  - Klare Dokumentation in deutscher Sprache
  - Erklärungen für technische und nicht-technische Stakeholder
  - Proaktive Kommunikation bei Problemen

- **Problemlösung:**
  - Systematische Fehlersuche
  - Kreative Lösungsansätze
  - Geduld bei komplexen Netzwerk-Problemen

## Erwartete Deliverables

1. **Funktionierende Integration:**
   - iOS-App kann erfolgreich mit Backend kommunizieren
   - Alle Backend-Services sind erreichbar und funktionsfähig
   - **Alle Services im stabilen "running" Status** (keine Restart-Loops)
   - Nginx und Market Data Service laufen stabil
   - Live-Query (WebSocket) funktioniert stabil
   - FIN1 Server Control Panel zeigt korrekte Status-Informationen

2. **Konfigurationsdateien:**
   - Optimierte Docker-Compose-Konfiguration
   - Nginx-Konfiguration
   - Parse Server-Konfiguration
   - Fritzbox-Einstellungen (Dokumentation)

3. **Dokumentation:**
   - Setup-Anleitung (Schritt-für-Schritt)
   - Netzwerk-Architektur-Diagramm
   - Troubleshooting-Guide
   - Konfigurations-Referenz

4. **Testing & Validierung:**
   - Test-Report mit allen validierten Verbindungen
   - Performance-Metriken
   - Service-Stabilitätstests (keine Restart-Loops)
   - Control Panel-Funktionalitätstests
   - Bekannte Probleme und Workarounds

## Projektumfang & Zeitrahmen

- **Geschätzter Aufwand:** 1-2 Tage (je nach Komplexität)
- **Arbeitsweise:** Remote oder Vor-Ort möglich
- **Zugriff:** SSH-Zugriff auf Ubuntu-Server, Zugriff auf Fritzbox-Weboberfläche, Zugriff auf Mac (optional)

## Bewerbung

Bitte senden Sie uns:
- Kurze Beschreibung Ihrer relevanten Erfahrung
- Referenzen zu ähnlichen Projekten (optional)
- Verfügbarkeit und geschätzte Kosten
- Bevorzugte Kommunikationsmethode

## Kontakt

Bei Interesse oder Fragen kontaktieren Sie uns bitte mit folgenden Informationen:
- Verfügbarkeit
- Geschätzte Kosten
- Vorgehensweise

---

**Hinweis:** Dies ist ein einmaliges Projekt zur optimalen Konfiguration der bestehenden Infrastruktur. Langfristige Wartung kann optional vereinbart werden.
