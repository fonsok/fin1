# Mac (Tahoe/Apple Silicon) Development Optimization Guide

## Übersicht

Für optimale Entwicklungserfahrung auf Apple Silicon Macs (Tahoe) sollten die Energiespareinstellungen angepasst werden, um konstante Performance und schnelle Builds zu gewährleisten.

## ⚡ Schnellstart

```bash
# Mac für Entwicklung optimieren
sudo ./scripts/optimize-mac-for-development.sh

# Aktuelle Einstellungen anzeigen
pmset -g

# Zurücksetzen (manuell über Systemeinstellungen)
# Systemeinstellungen > Energiesparmodus
```

## 🔧 Empfohlene Einstellungen für Entwicklung

### 1. Energiesparmodus deaktivieren

**Warum:** Low Power Mode reduziert CPU-Leistung um ~40%, was Build-Zeiten deutlich verlängert.

```bash
sudo pmset -a lowpowermode 0
```

**Manuell:** Systemeinstellungen > Batterie > Energiesparmodus: AUS

### 2. Ruhezustand optimieren

**Wichtig:** Es gibt zwei verschiedene Sleep-Modi:
- **Display Sleep:** Nur Bildschirm aus, Mac läuft weiter → Internet funktioniert ✅
- **System Sleep:** Mac geht komplett in Ruhezustand → Internet getrennt ❌

**Siehe:** `Documentation/SLEEP_MODES_EXPLAINED.md` für Details

**Bei Netzbetrieb:** System Sleep deaktivieren
- Verhindert unerwartete Unterbrechungen während Builds/Tests
- `sudo pmset -c sleep 0` (c = charger/AC power)

**Bei Batteriebetrieb:** System Sleep nach 15 Minuten
- Spart Batterie bei längeren Pausen
- **Wichtig:** Bei System Sleep funktioniert kein Internet mehr
- `sudo pmset -b sleep 15` (b = battery, 15 Minuten)

**Display Sleep:** Immer 15 Minuten
- Bildschirm geht aus, aber Mac läuft weiter
- Internet bleibt verbunden ✅
- `sudo pmset -a displaysleep 15`

**Manuell:** Systemeinstellungen > Energiesparmodus
- Bei Netzbetrieb: "Ruhezustand" auf "Nie"
- Bei Batteriebetrieb: "Ruhezustand" auf "15 Minuten"
- "Bildschirm ausschalten": "15 Minuten"

### 3. Display-Ruhezustand verlängern

**Warum:** Mehr Zeit für Code-Review und Debugging ohne ständige Bildschirmsperre.

```bash
sudo pmset -a displaysleep 15  # 15 Minuten
```

### 4. Festplatten-Ruhezustand deaktivieren

**Warum:** Verhindert Verzögerungen beim Zugriff auf Projektdateien.

```bash
sudo pmset -a disksleep 0
```

### 5. Power Nap aktivieren

**Warum:** Erlaubt Hintergrund-Updates (z.B. Xcode-Updates, Time Machine) ohne System zu wecken.

```bash
sudo pmset -a powernap 1
```

## 📊 Aktuelle Einstellungen prüfen

```bash
# Alle Power-Management-Einstellungen anzeigen
pmset -g

# Nur aktive Einstellungen
pmset -g custom

# Batteriestatus
pmset -g batt
```

## 🎯 Xcode-spezifische Optimierungen

### Build-Einstellungen

Das Projekt ist bereits für optimale Debug-Performance konfiguriert:

- **Debug:** `SWIFT_OPTIMIZATION_LEVEL = "-Onone"` (keine Optimierung für schnelles Debugging)
- **Release:** Vollständige Optimierung für Production
- **ONLY_ACTIVE_ARCH = YES** (nur aktive Architektur bauen, schneller)

### Xcode-Einstellungen

1. **Derived Data auf schnellem Speicher:**
   - Xcode > Settings > Locations
   - Derived Data auf interne SSD oder externes NVMe SSD

2. **Indexing optimieren:**
   - Xcode > Settings > General
   - "Show Source Control" deaktivieren (wenn nicht benötigt)

3. **Build Parallelität:**
   - Xcode > Settings > Building
   - "Build Active Architecture Only" = YES (Debug)
   - "Parallelize Build" = YES

## 🔋 Batteriebetrieb & Flexible Arbeitszeiten

### Was bedeutet "während Entwicklung"?

**"Während Entwicklung"** bedeutet: **Wenn Sie aktiv arbeiten**
- Nicht: Mac muss ständig am Netzteil sein
- Sondern: Mac bleibt wach, während Sie Code schreiben, Builds starten, Tests laufen lassen

**Die Einstellungen funktionieren automatisch:**
- **Aktive Arbeit:** Mac bleibt wach (egal ob Batterie oder Netzteil)
- **Längere Pause (3+ Stunden):** Mac geht automatisch in Sleep (spart Batterie)
- **Zurückkommen:** Mac aufklappen → sofort weiterarbeiten

### Optimale Einstellungen für Batteriebetrieb

Das Script konfiguriert optimale Einstellungen für beide Szenarien:

**Bei Batteriebetrieb:**
- **System Sleep** nach **15 Minuten** Inaktivität (Mac geht in Ruhezustand)
- **Display Sleep** nach **15 Minuten** (nur Bildschirm aus, Mac läuft weiter)
- Low Power Mode **deaktiviert** (volle Performance)
- **Wichtig:** Bei System Sleep funktioniert **kein Internet** mehr ❌

**Bei Netzbetrieb:**
- Sleep **deaktiviert** (nie schlafen)
- Volle CPU-Leistung
- Keine Unterbrechungen während Builds

### Praktische Anwendung

#### Während aktiver Entwicklung (Batteriebetrieb)

✅ **Mac bleibt wach** während Sie arbeiten:
- Builds werden nicht unterbrochen
- Tests laufen durch
- Volle CPU-Leistung verfügbar
- **Display Sleep nach 15 Min:** Bildschirm aus, aber Mac läuft weiter → Internet funktioniert ✅

#### Bei Pausen

**Nach 15 Minuten Inaktivität:**

1. **Display Sleep** (15 Min):
   - Bildschirm geht aus
   - Mac läuft weiter ✅
   - Internet funktioniert noch ✅
   - Einfach Bildschirm berühren → sofort wieder da

2. **System Sleep** (15 Min bei Batterie):
   - Mac geht komplett in Ruhezustand
   - **Internet wird getrennt** ❌
   - Spart Batterie
   - Mac aufklappen → Aufwachen (2-5 Sek)

**Beispiel-Tag:**
- **09:00 - 12:00:** Aktive Entwicklung → Mac bleibt wach ✅
- **12:00 - 12:15:** Kurze Pause → Display Sleep (Internet funktioniert noch) ✅
- **12:15+:** Längere Pause → System Sleep (Internet getrennt, spart Batterie) ✅
- **15:30:** Mac aufklappen → Aufwachen → Internet reconnect → weiterarbeiten ✅

### Low Power Mode

**Empfehlung:** Deaktiviert lassen für beste Performance
- Builds sind deutlich schneller
- Tests laufen ohne Verzögerungen
- Bei sehr niedrigem Batteriestand (< 20%): Kann manuell aktiviert werden

**Manuell aktivieren/deaktivieren:**
- Systemeinstellungen > Batterie > Energiesparmodus
- Oder: `sudo pmset -a lowpowermode 1` (aktivieren) / `0` (deaktivieren)

## 🚨 Wichtige Hinweise

### Vor Production-Deployment

Vor dem Erstellen von Production-Builds:

1. **Energiesparmodus prüfen:** Sollte für Release-Builds aktiviert sein, um echte Performance zu testen
2. **Thermal Throttling beachten:** Bei langen Builds kann der Mac heiß werden
3. **Batteriegesundheit:** Bei dauerhaftem Netzbetrieb regelmäßig Batteriezyklen prüfen

### Monitoring

```bash
# CPU-Temperatur überwachen (mit iStats oder ähnlich)
# Install: brew install istat-menus

# Aktivitätsanzeige für CPU/Memory
Activity Monitor > Window > CPU Usage
```

## 📝 Backup & Wiederherstellung

Das Optimierungsscript erstellt automatisch Backups:

```bash
# Backup finden
ls -lt /tmp/pmset-backup-*.txt

# Manuell wiederherstellen (siehe restore-mac-power-settings.sh)
```

## 🔄 Standard-Einstellungen wiederherstellen

```bash
# Zurücksetzen auf macOS-Standards
sudo pmset -a restoredefaults

# Oder manuell über Systemeinstellungen
# Systemeinstellungen > Energiesparmodus > "Wiederherstellen"
```

## 📚 Weitere Ressourcen

- [Apple: pmset Man Page](https://developer.apple.com/library/archive/documentation/Darwin/Reference/ManPages/man1/pmset.1.html)
- [Xcode Build Performance Guide](https://developer.apple.com/documentation/xcode/improving-build-performance)
- [Apple Silicon Performance](https://developer.apple.com/documentation/apple-silicon)

## ✅ Checkliste für optimale Entwicklung

- [ ] Low Power Mode deaktiviert (für volle Performance)
- [ ] Sleep bei Netzbetrieb deaktiviert (keine Unterbrechungen)
- [ ] Sleep bei Batteriebetrieb auf 15 Minuten (spart Batterie)
- [ ] Display Sleep auf 15 Minuten (Bildschirm aus, Mac läuft weiter)
- [ ] Display-Ruhezustand auf 15+ Minuten
- [ ] Festplatten-Ruhezustand deaktiviert
- [ ] Xcode Derived Data auf schnellem Speicher
- [ ] Build-Parallelität aktiviert
- [ ] Regelmäßige Backups der Einstellungen

### 💡 Für flexible Arbeitszeiten

- [ ] Mac kann am Batteriebetrieb arbeiten (2h Sleep-Timeout)
- [ ] Automatischer Sleep bei längeren Pausen (3+ Stunden)
- [ ] Volle Performance auch ohne Netzteil

---

**Letzte Aktualisierung:** $(date +%Y-%m-%d)
