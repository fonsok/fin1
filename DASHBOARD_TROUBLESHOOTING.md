# Dashboard Troubleshooting - Leere Seite

**Problem:** Dashboard zeigt leere weiße Seite, kein Login-Formular sichtbar

---

## ✅ Lösung: Content-Security-Policy deaktiviert

Die Content-Security-Policy (CSP) von Helmet hat das JavaScript blockiert. CSP wurde jetzt deaktiviert.

---

## 🔄 Nächste Schritte

### 1. Browser-Cache leeren und neu laden

**Firefox:**
1. **Hard Reload:** `Cmd+Shift+R` (Mac) oder `Strg+Shift+R` (Windows/Linux)
2. **Oder:** Cache leeren:
   - `Cmd+Shift+Delete` (Mac) oder `Strg+Shift+Delete` (Windows/Linux)
   - Wähle "Cache" und "Cookies"
   - Klicke "Jetzt löschen"

### 2. Browser-Console prüfen

**Falls es immer noch nicht funktioniert:**

1. **Console öffnen:**
   - `F12` oder `Cmd+Option+I` (Mac) / `Strg+Shift+I` (Windows/Linux)
   - Tab: **"Konsole"** (Console)

2. **Nach Fehlern suchen:**
   - Rote Fehlermeldungen
   - CSP-bezogene Fehler
   - JavaScript-Fehler

3. **Network-Tab prüfen:**
   - Tab: **"Netzwerkanalyse"** (Network)
   - Seite neu laden
   - Prüfe ob `login.bundle.js` geladen wird (Status 200)
   - Prüfe ob andere Ressourcen fehlschlagen

---

## 🔍 Was wurde geändert

**Datei:** `backend/parse-server/index.js`

```javascript
// Vorher: CSP blockierte JavaScript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      scriptSrc: ["'self'"], // Zu restriktiv
    },
  },
}));

// Jetzt: CSP deaktiviert für Dashboard
app.use(helmet({
  contentSecurityPolicy: false,
}));
```

---

## 🧪 Testen

**Nach Hard Reload sollte erscheinen:**
- Login-Formular mit Username- und Password-Feldern
- "Log In" Button
- Parse Dashboard Branding

---

## ⚠️ Falls es immer noch nicht funktioniert

### Option 1: Browser-Console-Fehler prüfen

**Console öffnen und nach Fehlern suchen:**
- CSP-Fehler
- JavaScript-Fehler
- Netzwerk-Fehler

**Fehlermeldungen hier posten!**

### Option 2: Anderen Browser testen

- Chrome/Edge testen
- Safari testen
- Falls es in einem Browser funktioniert = Browser-spezifisches Problem

### Option 3: Direkt-URL testen

```bash
# Prüfe ob JavaScript-Bundle erreichbar ist
curl -sk https://192.168.178.24/dashboard/bundles/login.bundle.js | head -5
```

**Sollte JavaScript-Code zeigen, nicht HTML oder Fehler**

---

## 📝 Alternative: ComplianceEvent-Klasse ohne Dashboard erstellen

Falls das Dashboard weiterhin Probleme macht, kann die Klasse auch automatisch erstellt werden:

**Parse Server erstellt Klassen automatisch beim ersten Objekt-Save.**

Die App wird die Klasse beim nächsten Compliance Event automatisch erstellen, sobald der Server vollständig bereit ist.

---

## 🎯 Status

- ✅ Dashboard aktiviert
- ✅ CSP deaktiviert
- ✅ JavaScript-Bundle wird geladen
- ⏳ Warte auf Hard Reload im Browser

**Bitte Hard Reload durchführen (Cmd+Shift+R) und prüfen, ob Login-Formular erscheint!**
