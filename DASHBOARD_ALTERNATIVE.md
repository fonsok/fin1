# Alternative: ComplianceEvent-Klasse ohne Dashboard erstellen

**Problem:** Dashboard zeigt leere Seite, Login-Formular nicht sichtbar

**Lösung:** ComplianceEvent-Klasse wird automatisch erstellt, wenn die App ein Compliance Event speichert

---

## ✅ Automatische Erstellung

**Parse Server erstellt Klassen automatisch**, wenn das erste Objekt gespeichert wird.

**Das bedeutet:**
- Die Klasse wird erstellt, sobald die App das nächste Mal ein Compliance Event speichert
- **Kein Dashboard nötig!**

---

## 🧪 Testen

### 1. App neu starten

1. **Xcode:** Product → Clean Build Folder (⇧⌘K)
2. **Xcode:** Product → Build (⌘B)
3. **Xcode:** Product → Run (⌘R)

### 2. Warte auf Compliance Event

Die App versucht automatisch, Compliance Events zu speichern. Sobald der Parse Server vollständig bereit ist, wird die Klasse automatisch erstellt.

### 3. Prüfe Logs

**In Xcode Console:**
- Sollte keine 500-Fehler mehr zeigen
- Compliance Events sollten erfolgreich gespeichert werden

**Parse Server Logs:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server"
```

**Was du sehen solltest:**
```
POST /parse/classes/ComplianceEvent HTTP/1.1" 201
```

**201 = Erfolgreich erstellt!** ✅

---

## 📝 Manuelle Erstellung via API (Falls nötig)

Falls die automatische Erstellung nicht funktioniert, kann die Klasse auch direkt in MongoDB erstellt werden:

```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml exec mongodb mongosh --quiet --eval 'use fin1; db.ComplianceEvent.insertOne({userId: \"init\", eventType: \"init\", description: \"Init\", timestamp: new Date()}); print(\"Class created\")'"
```

**Hinweis:** Parse Server erkennt die Collection, aber das Schema wird beim ersten API-Call erstellt.

---

## 🎯 Empfehlung

**Einfachste Lösung:** Warte, bis die App die Klasse automatisch erstellt.

- ✅ Kein Dashboard nötig
- ✅ Keine manuelle Konfiguration
- ✅ Funktioniert automatisch

**Die 500-Fehler verschwinden, sobald die Klasse erstellt wurde.**

---

## ⏱️ Wann wird die Klasse erstellt?

Die Klasse wird erstellt, wenn:
1. Parse Server vollständig initialisiert ist (1-2 Minuten nach Neustart)
2. Die App ein Compliance Event speichert
3. Parse Server erkennt, dass die Klasse nicht existiert
4. Parse Server erstellt die Klasse automatisch
5. Das Objekt wird gespeichert

**Das passiert automatisch beim nächsten App-Start!**
