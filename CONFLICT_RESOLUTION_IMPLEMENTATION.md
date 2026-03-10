# ✅ Conflict-Resolution Implementation - Abgeschlossen

**Datum:** 2026-02-05
**Status:** ✅ Implementiert

---

## 🎯 Was wurde implementiert

### 1. ConflictResolutionService
**Datei:** `FIN1/Shared/Services/ConflictResolutionService.swift`

**Features:**
- ✅ Mehrere Resolution-Strategien unterstützt
- ✅ Timestamp-basierte Conflict-Erkennung
- ✅ Field-level Merging für komplexe Objekte
- ✅ Protocol-basiert für einfache Erweiterung

**Strategien:**
1. **Last Write Wins** (Standard)
   - Neueste Version gewinnt
   - Einfach und schnell
   - Verhindert Datenverlust bei schnellen Updates

2. **First Write Wins**
   - Erste Version gewinnt
   - Verhindert Überschreibung von Updates
   - Nützlich für kritische Daten

3. **Field-Level Merging**
   - Merged nicht-konfliktierende Felder
   - Lokale Version gewinnt bei Konflikten
   - Ideal für komplexe Objekte mit vielen Feldern

4. **Manual Resolution**
   - Wirft Fehler für manuelle Bearbeitung
   - Für kritische Conflicts, die User-Input benötigen

---

### 2. ConflictDetector
**Datei:** `FIN1/Shared/Services/ConflictResolutionService.swift`

**Features:**
- ✅ Erkennt Conflicts basierend auf Timestamps
- ✅ Unterstützt Version-Nummern (optional)
- ✅ Berücksichtigt Clock-Skew (1 Sekunde Toleranz)

**Verwendung:**
```swift
let hasConflict = ConflictDetector.hasConflict(
    localUpdatedAt: localDate,
    remoteUpdatedAt: remoteDate
)
```

---

### 3. ParseAPIClient Integration
**Datei:** `FIN1/Shared/Services/ParseAPIClient.swift`

**Änderungen:**
- ✅ `conflictResolver` Property hinzugefügt
- ✅ `configure(conflictResolver:)` Methode hinzugefügt
- ✅ `handleConflict()` Methode implementiert
- ✅ Automatische Conflict-Resolution bei 409 Fehlern
- ✅ `extractUpdatedAt()` Helper für Timestamp-Extraktion

**Flow:**
```
Update Request
    ↓
409 Conflict Error
    ↓
Fetch Remote Version
    ↓
Extract Timestamps
    ↓
Resolve Conflict
    ↓
Retry Update with Resolved Object
```

---

### 4. AppServicesBuilder Integration
**Datei:** `FIN1/Shared/Services/AppServicesBuilder.swift`

**Änderungen:**
- ✅ `ConflictResolutionService` wird erstellt
- ✅ Standard-Strategie: `.lastWriteWins`
- ✅ `ParseAPIClient` wird mit Resolver konfiguriert

---

## 📊 Architektur

### Conflict-Resolution Flow

```
Device A: Update Object (updatedAt: 10:00)
    ↓
Device B: Update Object (updatedAt: 10:01)
    ↓
Device A: Retry Update → 409 Conflict
    ↓
ParseAPIClient.handleConflict()
    ↓
Fetch Remote Version (Device B's update)
    ↓
ConflictResolver.resolveConflict()
    ├─ Last Write Wins → Device B's version wins
    ├─ First Write Wins → Device A's version wins
    └─ Field-Level Merging → Merge both versions
    ↓
Retry Update with Resolved Object
```

---

## 🔧 Konfiguration

### Standard-Konfiguration (Last Write Wins)

```swift
let conflictResolver = ConflictResolutionService(strategy: .lastWriteWins)
parseAPIClient.configure(conflictResolver: conflictResolver)
```

### Alternative Strategien

```swift
// First Write Wins
let resolver = ConflictResolutionService(strategy: .firstWriteWins)

// Field-Level Merging
let resolver = ConflictResolutionService(strategy: .fieldLevelMerging)

// Manual Resolution (throws error)
let resolver = ConflictResolutionService(strategy: .manualResolution)
```

---

## 🧪 Testing-Empfehlungen

### Unit Tests
1. **ConflictResolutionService:**
   - Teste Last Write Wins Strategie
   - Teste First Write Wins Strategie
   - Teste Field-Level Merging
   - Teste mit fehlenden Timestamps

2. **ConflictDetector:**
   - Teste Conflict-Erkennung mit Timestamps
   - Teste Clock-Skew-Toleranz
   - Teste mit Version-Nummern

3. **ParseAPIClient Integration:**
   - Teste Conflict-Handling bei 409 Fehlern
   - Teste Timestamp-Extraktion
   - Teste Retry nach Resolution

### Integration Tests
1. **Multi-Device-Szenario:**
   - Zwei Geräte aktualisieren gleichzeitig
   - Prüfen, dass Conflict erkannt wird
   - Prüfen, dass Resolution funktioniert

2. **Offline-Queue + Conflict:**
   - Gerät A offline, aktualisiert Objekt
   - Gerät B online, aktualisiert Objekt
   - Gerät A kommt online, Queue wird verarbeitet
   - Prüfen, dass Conflict erkannt und gelöst wird

---

## 📝 Verwendung

### Beispiel: Invoice Update mit Conflict

```swift
// Device A: Update Invoice
let invoice = Invoice(id: "123", amount: 1000, updatedAt: Date())
do {
    let updated = try await invoiceAPIService.updateInvoice(invoice)
    // Success
} catch NetworkError.serverError(409) {
    // Conflict wurde automatisch gelöst
    // Invoice wurde mit neuester Version aktualisiert
}
```

### Custom Conflict Resolution

```swift
// Custom Resolver für spezielle Use-Cases
class CustomConflictResolver: ConflictResolutionServiceProtocol {
    func resolveConflict<T: Codable>(
        local: T,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date?
    ) async throws -> T {
        // Custom logic
        // z.B. User-Frage stellen, spezielle Felder bevorzugen, etc.
        return local // oder remote, oder merged version
    }
}

let customResolver = CustomConflictResolver()
parseAPIClient.configure(conflictResolver: customResolver)
```

---

## ⚠️ Wichtige Hinweise

### Timestamp-Extraktion
- `extractUpdatedAt()` verwendet Reflection (Mirror)
- Unterstützt `updatedAt` und `lastModified` Felder
- Fallback auf JSON-Dictionary-Extraktion
- Kann erweitert werden für spezielle Modelle

### Field-Level Merging
- Arrays werden kombiniert (Duplikate entfernt)
- Lokale Version gewinnt bei Konflikten
- Metadata-Felder (`objectId`, `createdAt`, `updatedAt`) werden ignoriert
- Kann für komplexe Objekte angepasst werden

### Performance
- Conflict-Resolution ist synchron (kann für große Objekte langsam sein)
- Field-Level Merging erfordert Encoding/Decoding (Overhead)
- Für Production: Caching von Remote-Versionen erwägen

---

## 🚀 Nächste Schritte

### Optional: Erweiterungen
1. **Optimistic Updates:**
   - UI sofort aktualisieren
   - Conflict-Resolution im Hintergrund
   - Rollback bei Fehlern

2. **User-Interaction:**
   - UI für manuelle Conflict-Resolution
   - Zeige beide Versionen
   - User wählt gewünschte Version

3. **Advanced Merging:**
   - Field-spezifische Merge-Strategien
   - Array-Merging mit ID-basierter Deduplizierung
   - Nested-Object-Merging

---

## 📚 Referenzen

- **ConflictResolutionService**: `FIN1/Shared/Services/ConflictResolutionService.swift`
- **ParseAPIClient**: `FIN1/Shared/Services/ParseAPIClient.swift`
- **AppServicesBuilder**: `FIN1/Shared/Services/AppServicesBuilder.swift`
- **Backend-Integration Fortschritt**: `BACKEND_INTEGRATION_FORTSCHRITT.md`
- **Offline-Queue**: `OFFLINE_QUEUE_IMPLEMENTATION.md`

---

**Fazit:** Conflict-Resolution ist vollständig implementiert und integriert. Die App kann jetzt Conflicts automatisch lösen, wenn mehrere Geräte gleichzeitig dasselbe Objekt aktualisieren.
