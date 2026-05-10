/**
 * Einmalig / bei Bedarf: Indizes für App-Ledger und Beleg-Suche (siehe init/01_indexes.js).
 *
 * Ausführung (lokal, Docker-Compose wie in docker-compose.yml):
 *   cat backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js | docker exec -i fin1-mongodb \
 *     mongosh --quiet -u admin -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin
 *
 * Hinweis: `mongosh --file init/01_indexes.js` scheitert an Collections mit Namen `_User`
 * (Dot-Notation `db._User` ist in mongosh undefined — nutze init-Skripte nur beim ersten Volume-Start).
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
