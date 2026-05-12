# AGB & Rechtstexte – Anleitung für Admins

> Schritt-für-Schritt: Wie ein Admin einen Abschnitt (z. B. Abschnitt 3) in AGB, Datenschutz oder Impressum ändert.

## Wichtig: Append-Only

Rechtstexte werden **nicht** in-place bearbeitet. Jede inhaltliche Änderung erfolgt über eine **neue Version**. Die bisherige Version bleibt unverändert (Audit/GoB).

---

## Vorgehensweise: Abschnitt ändern

### 1. Admin-Portal öffnen

- Im Admin-Portal zu **„AGB & Rechtstexte“** wechseln.
- Dokumenttyp wählen (z. B. **AGB / Terms**, **Datenschutz** oder **Impressum**).
- Optional: Sprache filtern (z. B. Deutsch).

### 2. Aktuelle Version finden (optional)

- In der Liste die Version finden, in der der zu ändernde Abschnitt steht.
- Auf **„(Inhalt anzeigen)“** oder **„Inhalt anzeigen“** klicken.
- Abschnitte durchsehen und den gewünschten Abschnitt (z. B. Abschnitt 3) identifizieren.
- **Änderungen zur Vorgängerversion:** Nach dem Aufklappen zeigt der Bereich „Änderungen zur Vorgängerversion“ einen Button **„Änderungen anzeigen“**. Ein Klick lädt die Vorgängerversion und listet kompakt, was hinzugefügt, entfernt oder geändert wurde – ohne die Vorgängerversion manuell zu durchsuchen.

### 3. Neue Version klonen (oder direkt Bearbeiten)

- **Variante A:** Bei dieser Version auf **„Klonen (neue Version)“** klicken. Der Editor öffnet sich mit allen Abschnitten.
- **Variante B:** Beim gewünschten Abschnitt auf **„Bearbeiten“** klicken. Es wird dieselbe Version geklont und der Editor mit Fokus auf genau diesen Abschnitt geöffnet (Suchfeld vorausgefüllt).

### 4. Abschnitt im Editor anpassen

- Im Editor zum gewünschten Abschnitt scrollen (z. B. Abschnitt 3).
- **Titel** und/oder **Inhalt** anpassen: Jeder Abschnitt hat im Editor die Felder **„Titel des Abschnitts“** (z. B. „Wichtige Hinweise“) und **„Inhalt“**. Diese Felder erscheinen nur nach „Klonen (neue Version)“ in der Bearbeitungsansicht, nicht in der reinen Ansicht der Abschnitte.
- Weitere Abschnitte können unverändert bleiben.
- **Suche:** Mit dem Suchfeld „Abschnitte durchsuchen (Titel, Inhalt, ID)“ können Sie schnell einen Abschnitt finden.
- **Version** setzen (z. B. `1.0.4` oder `1.0.3-clone`).
- **Gültig ab** setzen (z. B. heutiges Datum).

### 5. Neue Version anlegen

- Auf **„Neue Version anlegen“** klicken.
- Die neue Version wird **inaktiv** angelegt; die bisher aktive Version bleibt vorerst aktiv.

### 6. Neue Version aktiv setzen

- Zurück in der Liste die **neu angelegte Version** finden.
- Auf **„Als aktiv setzen“** klicken.
- Die neue Version ist damit die aktive für diesen Dokumenttyp und diese Sprache; die bisher aktive wird automatisch deaktiviert.

### 7. Prüfen (optional)

- In der App oder im Portal die entsprechende Seite (AGB, Datenschutz oder Impressum) aufrufen und prüfen, ob der geänderte Abschnitt korrekt angezeigt wird.

---

## Kurzüberblick

| Schritt | Aktion |
|--------|--------|
| 1 | Admin → AGB & Rechtstexte, Typ/Sprache wählen |
| 2 | Optional: „Inhalt anzeigen“, Abschnitt finden |
| 3 | „Klonen (neue Version)“ |
| 4 | Im Editor Abschnitt ändern, Version/Datum setzen |
| 5 | „Neue Version anlegen“ |
| 6 | „Als aktiv setzen“ bei der neuen Version |
| 7 | Optional: Anzeige in der App prüfen |

---

## Backup/Restore & Release-Workflow (Export/Import)

Im Admin‑Portal (Seite **„AGB & Rechtstexte“**) stehen zusätzlich folgende Funktionen zur Verfügung:

- **Export (Backup)**: exportiert die Rechtstexte als JSON‑Backup (für Archivierung / Migration).
- **Import (Restore)**: importiert ein JSON‑Backup und ersetzt die bestehenden Versionen (bestehende werden serverseitig archiviert/deaktiviert, neue werden angelegt).
- **Export active (filtered)**: exportiert **nur aktive** Versionen (optional nach Dokumenttyp/Sprache gefiltert).
- **Import active (as new)**: importiert aktive Versionen und legt sie als **neue** Versionen an (Release‑Workflow).

**Wahl des richtigen Buttons:**
- **`Import (Restore)`** nur für **vollständige** Backups (Notfall/Migration gesamter Bestand).
- **`Import active (as new)`** für kontrollierte Releases einzelner Dokumente (z. B. Terms DE+EN auf neue Version heben).

**Hinweis (Audit/Append‑only):** Historische Versionen werden nicht überschrieben. Restore/Import erzeugt neue Datensätze und (je nach Funktion) archiviert/deaktiviert die bisherigen.

**Warnings beachten:** Export/Import zeigt serverseitige `warnings` (z. B. bei erreichten Server-Limits). Diese Hinweise vor Bestätigung prüfen.

---

## Legal Branding (Platzhalter wie `{{APP_NAME}}`)

Bestimmte Platzhalter werden serverseitig aufgelöst (z. B. `{{APP_NAME}}` / `{{LEGAL_*}}`). Der **kanonische App‑Name** wird zentral in der aktiven `Configuration` gepflegt:

- Im Admin‑Portal unter **„Konfiguration“ → „Systemparameter“** als **`legalAppName`** (4‑Augen‑Workflow wie andere kritische Parameter).
- Unter **„AGB & Rechtstexte“** gibt es nur noch einen **Hinweis/Deep‑Link** zur Konfiguration (kein direktes Schreiben mehr).

**Namens-Sache (praktisch):**
- In Texten möglichst **`{{APP_NAME}}`** statt festem App-Namen verwenden.
- Feste Legacy-Literale wie `bbb` werden **nicht** automatisch durch Konfig-Änderungen ersetzt; dafür eine neue Version anlegen und auf Platzhalter umstellen.

---

## Development Maintenance (nur DEV/Test)

Für Entwicklungs-/Testdaten gibt es eine Wartungsfunktion:

- **DEV: Reset legal docs baseline (v1.0.0)**: klont die aktuell aktiven Versionen als neue `v1.0.0` Baseline und löscht danach inaktive Altversionen (nur mit serverseitigen Guardrails).

Diese Funktion ist für PROD nicht gedacht und ist serverseitig durch ENV‑Flags und Schutzbedingungen abgesichert.

---

## Referenzen

- Backend/Trigger: `backend/parse-server/cloud/functions/legal.js`, `backend/parse-server/cloud/triggers/legal.js`
- Audit/Immutability: `Documentation/LEGAL_DOCS_AUDIT_TRAIL.md`
- Admin-Portal Übersicht (inkl. Versionsanzeige, Bearbeiten-Button, Suche, Änderungsvergleich): `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` (Abschnitt 10.2.2)
