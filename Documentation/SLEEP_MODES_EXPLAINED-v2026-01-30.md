# Display Sleep vs. System Sleep - Erklärung

## 🔍 Der Unterschied

### 📺 Display Sleep (`displaysleep`)

**Was passiert:**
- Nur der **Bildschirm** geht aus
- **Mac läuft weiter** im Hintergrund
- CPU, RAM, Netzwerk: **alles aktiv**

**Was funktioniert:**
- ✅ **Internet surfen** (nach Aufwecken sofort verfügbar)
- ✅ **Downloads** laufen weiter
- ✅ **Server** laufen weiter (z.B. lokaler Entwicklungsserver)
- ✅ **Builds** laufen weiter
- ✅ **Backups** laufen weiter (Time Machine, etc.)

**Aufwecken:**
- Bildschirm berühren
- Tastatur/Maus bewegen
- Sofort wieder da, alles läuft weiter

**Einstellung:**
```bash
sudo pmset -a displaysleep 15  # 15 Minuten
```

---

### 💤 System Sleep (`sleep`)

**Was passiert:**
- **Mac geht komplett in den Ruhezustand**
- CPU wird heruntergefahren
- Nur RAM wird minimal versorgt (für schnelles Aufwachen)
- Netzwerk wird getrennt

**Was funktioniert NICHT:**
- ❌ **Kein Internet** (WiFi/Ethernet getrennt)
- ❌ **Keine Downloads**
- ❌ **Keine Server** (alle Verbindungen getrennt)
- ❌ **Keine Builds**
- ❌ **Keine Backups**

**Aufwecken:**
- Mac aufklappen (bei Laptops)
- Power-Button drücken
- Tastatur/Maus bewegen
- Dauert 2-5 Sekunden zum Aufwachen

**Einstellung:**
```bash
sudo pmset -b sleep 15  # 15 Minuten bei Batteriebetrieb
sudo pmset -c sleep 0   # Nie bei Netzbetrieb
```

---

## 🎯 Praktische Beispiele

### Szenario 1: Display Sleep (15 Min)

**Situation:** Sie surfen im Internet, machen 20 Minuten Pause

1. **15 Minuten:** Display geht aus (Display Sleep)
2. **Internet:** ✅ Funktioniert noch (Mac läuft)
3. **Nach 20 Minuten:** Bildschirm berühren → sofort wieder da
4. **Internet:** ✅ Noch verbunden, keine Unterbrechung

**Ergebnis:** Keine Unterbrechung, alles läuft weiter

---

### Szenario 2: System Sleep (15 Min)

**Situation:** Sie surfen im Internet, machen 20 Minuten Pause

1. **15 Minuten:** Mac geht in System Sleep
2. **Internet:** ❌ Getrennt (Mac ist aus)
3. **Nach 20 Minuten:** Mac aufklappen → Aufwachen (2-5 Sek)
4. **Internet:** ⏳ Muss sich neu verbinden (WiFi reconnect)

**Ergebnis:** Internet-Unterbrechung, kurze Verzögerung beim Aufwachen

---

## 💡 Empfehlungen

### Für Entwicklung

**Display Sleep:** 15 Minuten
- Bildschirm geht aus, aber Mac läuft weiter
- Builds/Server laufen weiter
- Internet bleibt verbunden

**System Sleep:**
- **Bei Batterie:** 15 Minuten (spart Batterie)
- **Bei Netzbetrieb:** Deaktiviert (nie schlafen)

### Für Internet-Surfen

**Wenn Sie während Pausen weiter surfen wollen:**
- Display Sleep: 15 Minuten ✅
- System Sleep: Länger (z.B. 30-60 Minuten) oder deaktiviert

**Wenn Sie Pausen machen und nicht surfen:**
- System Sleep: 15 Minuten ✅ (spart Batterie)

---

## 🔧 Aktuelle Einstellungen prüfen

```bash
# Alle Sleep-Einstellungen anzeigen
pmset -g

# Spezifisch:
# displaysleep = Display Sleep
# sleep = System Sleep
```

---

## 📊 Zusammenfassung

| Feature | Display Sleep | System Sleep |
|---------|---------------|--------------|
| **Bildschirm** | Aus | Aus |
| **Mac läuft** | ✅ Ja | ❌ Nein |
| **Internet** | ✅ Funktioniert | ❌ Getrennt |
| **Downloads** | ✅ Laufen weiter | ❌ Gestoppt |
| **Server** | ✅ Laufen weiter | ❌ Gestoppt |
| **Aufwecken** | Sofort | 2-5 Sekunden |
| **Batterie sparen** | Wenig | Viel |

---

**Fazit:**
- **Display Sleep** = Bildschirm aus, alles läuft weiter ✅
- **System Sleep** = Mac aus, kein Internet ❌
