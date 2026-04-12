# Migration: PlatformLedgerEntry → AppLedgerEntry

Die Parse-Klasse (und MongoDB-Collection) wurde von **PlatformLedgerEntry** auf **AppLedgerEntry** umbenannt.

## Einmalige Migration (nur einmal pro Umgebung)

Die Umbenennung der Collection ist **einmalig** pro Datenbank/Umgebung. Nach dem ersten Ausführen ist bei **zukünftigen Deploys keine erneute Migration nötig** – der neue Code arbeitet dann einfach mit der bereits umbenannten Collection.

Damit bestehende Ledger-Einträge in einer noch nicht migrierten Umgebung sichtbar bleiben, die **MongoDB-Collection einmal umbenennen**:

```bash
# Auf dem Server (oder mit mongosh gegen die FIN1-Datenbank)
mongosh "<connection-string>" --eval 'db.PlatformLedgerEntry.renameCollection("AppLedgerEntry")'
```

Oder in der `mongosh`-Shell:

```javascript
use fin1_db_name;  // Name Ihrer Parse-Datenbank
db.PlatformLedgerEntry.renameCollection("AppLedgerEntry");
```

**Hinweis:** Wenn die Parse-Datenbank einen anderen Namen hat, zuerst `show dbs` ausführen und den richtigen DB-Namen verwenden. Die Collection heißt in Parse standardmäßig wie die Klasse (`PlatformLedgerEntry` bzw. nach Migration `AppLedgerEntry`).

## Vor der Migration

- Backup der Datenbank empfohlen (siehe `scripts/BACKUP_RESTORE.md`).
- Kurzes Wartungsfenster einplanen: Während der Umbenennung sollten keine neuen App-Ledger-Einträge geschrieben werden (Deploy **nach** der Migration, oder Migration in einer ruhigen Phase durchführen).

## Nach der Migration

- Neuer Cloud-Code schreibt nur noch in `AppLedgerEntry`.
- Alte Einträge sind in derselben Collection und werden von `getAppLedger` mitgelesen.
