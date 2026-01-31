# Markdown zu PDF Konverter

Dieses Skript konvertiert Markdown-Dateien in PDFs mit lokalisierten Währungsformaten und optimierten Tabellen.

**Das Skript kann in beliebige Ordner kopiert werden und funktioniert eigenständig!**

## Verwendung

### Automatische Konvertierung aller .md Dateien

Das einfachste: Kopieren Sie das Skript in einen Ordner mit Markdown-Dateien und führen Sie es aus:

```bash
# Skript in beliebigen Ordner kopieren
cp convert_md_to_pdf_simple.py ~/Downloads/
cd ~/Downloads

# Alle .md Dateien im aktuellen Verzeichnis konvertieren
python3 convert_md_to_pdf_simple.py
```

Das Skript findet automatisch alle `.md` Dateien im aktuellen Verzeichnis und erstellt entsprechende `.pdf` Dateien.

### Spezifische Dateien konvertieren (optional)

Sie können auch bestimmte Dateien angeben:

```bash
# Einzelne Datei
python3 convert_md_to_pdf_simple.py dokument.md

# Mehrere Dateien
python3 convert_md_to_pdf_simple.py doc1.md doc2.md doc3.md

# Mit Pfaden
python3 convert_md_to_pdf_simple.py ~/Downloads/datei.md
```

### Wichtige Hinweise

1. **Standalone-Funktionalität**: Das Skript kann in jeden Ordner kopiert werden und funktioniert eigenständig. Keine Abhängigkeit vom FIN1-Projekt nötig!

2. **PDF wird im gleichen Verzeichnis erstellt**: Die PDF-Datei wird immer im gleichen Ordner wie die Markdown-Datei erstellt.

3. **Automatische Paket-Installation**: Beim ersten Ausführen installiert das Skript automatisch die benötigten Pakete (`markdown`, `reportlab`). Falls das fehlschlägt, installieren Sie manuell:
   ```bash
   pip3 install --user markdown reportlab
   ```

4. **Sprach-Erkennung**: Das Skript erkennt automatisch, ob es sich um eine deutsche Version handelt:
   - Dateinamen mit `_DE` oder `DE.md` → deutsches Währungsformat (50.000 €)
   - Andere Dateien → englisches Währungsformat (€50,000)

## Features

- ✅ Lokalisierte Währungsformate (deutsch/englisch)
- ✅ Dynamische Tabellenspaltenbreiten
- ✅ Korrekte Leerzeichen um €, -, + Symbole
- ✅ Entfernung von Emojis (verhindert schwarze Quadrate)
- ✅ Textumbruch in Tabellenzellen
- ✅ Professionelles Layout mit korrekten Rändern

## Beispiel

**Eingabe (Markdown):**
```markdown
| Kosten | €50K-150K |
```

**Ausgabe (PDF):**
- Deutsch: `50.000 € - 150.000 €`
- Englisch: `€50,000 - €150,000`

## Fehlerbehebung

**Problem**: "ModuleNotFoundError: No module named 'markdown'"
**Lösung**: Aktivieren Sie das virtuelle Environment oder installieren Sie die Pakete:
```bash
pip3 install --user markdown reportlab
```

**Problem**: "File not found"
**Lösung**: Verwenden Sie absolute Pfade oder prüfen Sie, ob die Datei existiert:
```bash
python3 scripts/convert_md_to_pdf_simple.py ~/Downloads/datei.md
```
