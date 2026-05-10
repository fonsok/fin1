/**
 * Einmalig / bei Bedarf: Indizes für App-Ledger und Beleg-Suche (siehe init/01_indexes.js).
 *
 * Ausführung: siehe `backend/mongodb/init/README.md` (Abschnitte „Indizes nachziehen“).
 * Kurz (Docker, Repo-Root): `export MONGO_PASS='…'` dann
 *   cat backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js | docker exec -i fin1-mongodb \
 *     mongosh --quiet -u admin -p "$MONGO_PASS" --authenticationDatabase admin
 *
 * Hinweis: `01_indexes.js` im Repo nutzt `getCollection('_User')`/`_Session` — vollständiges Nachziehen
 * geht mit `mongosh --file` oder Pipe; dieses Skript bleibt optional für nur Ledger/Document.
 */

db = db.getSiblingDB('fin1');

print('=== apply_ledger_document_indexes_fin1: AppLedgerEntry ===');
db.AppLedgerEntry.createIndex({ account: 1, createdAt: -1 });
db.AppLedgerEntry.createIndex({ userId: 1, createdAt: -1 }, { sparse: true });
db.AppLedgerEntry.createIndex({ account: 1, userId: 1, createdAt: -1 }, { sparse: true });
db.AppLedgerEntry.createIndex({ transactionType: 1, createdAt: -1 });

print('=== apply_ledger_document_indexes_fin1: BankContraPosting ===');
db.BankContraPosting.createIndex({ investorId: 1, createdAt: -1 }, { sparse: true });

print('=== apply_ledger_document_indexes_fin1: Document ===');
db.Document.createIndex({ userId: 1, type: 1, uploadedAt: -1 });
db.Document.createIndex({ type: 1, uploadedAt: -1 });
db.Document.createIndex({ investmentId: 1, uploadedAt: -1 }, { sparse: true });
db.Document.createIndex({ tradeId: 1, uploadedAt: -1 }, { sparse: true });
db.Document.createIndex({ uploadedAt: -1 });
db.Document.createIndex({ referenceType: 1, referenceId: 1 }, { sparse: true });
db.Document.createIndex({ periodYear: 1, periodMonth: 1 }, { sparse: true });
db.Document.createIndex({ createdAt: -1 });
db.Document.createIndex({ userId: 1, documentType: 1 });

print('=== apply_ledger_document_indexes_fin1: done ===');
