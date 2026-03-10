// ============================================================================
// Clear investments, trades, and related documents (for testing only)
// ============================================================================
//
// Deletes from MongoDB in dependency order so the backend is clean for testing.
// Use only in development/test environments.
//
// Related data removed:
//   - PoolTradeParticipation, Commission, AccountStatement
//   - WalletTransaction (Konto-Buchungen: investment, investment_return, refund, etc.)
//   - Documents (trader_credit_note, investor_collection_bill)
//   - Invoices, Orders, Trades, Investments, InvestmentBatch
//
// Run with mongosh (see clear-investments-trades-documents.sh for examples).
//
// ============================================================================

const db = db.getSiblingDB('fin1');

function count(coll) {
  return coll.countDocuments({});
}

function deleteAll(coll, label) {
  const n = count(coll);
  if (n === 0) {
    print(label + ': 0 (skip)');
    return 0;
  }
  const result = coll.deleteMany({});
  print(label + ': deleted ' + result.deletedCount);
  return result.deletedCount;
}

function deleteWithQuery(coll, query, label) {
  const n = coll.countDocuments(query);
  if (n === 0) {
    print(label + ': 0 (skip)');
    return 0;
  }
  const result = coll.deleteMany(query);
  print(label + ': deleted ' + result.deletedCount);
  return result.deletedCount;
}

print('--- Clearing investments, trades, and related documents ---');

// 1. Child records that reference Trade / Investment
const poolPart = db.getCollection('PoolTradeParticipation');
const commission = db.getCollection('Commission');
const accountStmt = db.getCollection('AccountStatement');

deleteAll(poolPart, 'PoolTradeParticipation');
deleteAll(commission, 'Commission');
deleteAll(accountStmt, 'AccountStatement');

// 2. WalletTransaction (Konto-Buchungen) – damit Kontostand/Verlauf wieder „sauber“ ist
const walletTx = db.getCollection('WalletTransaction');
deleteAll(walletTx, 'WalletTransaction');

// 3. Documents: only accounting docs (credit notes, collection bills)
const document = db.getCollection('Document');
deleteWithQuery(
  document,
  {
    $or: [
      { type: 'trader_credit_note' },
      { type: 'investor_collection_bill' },
    ],
  },
  'Document (credit notes, collection bills)',
);

// 5. Invoices (order/trade related)
const invoice = db.getCollection('Invoice');
deleteAll(invoice, 'Invoice');

// 6. Orders (reference trades)
const order = db.getCollection('Order');
deleteAll(order, 'Order');

// 7. Trades
const trade = db.getCollection('Trade');
deleteAll(trade, 'Trade');

// 8. Investments
const investment = db.getCollection('Investment');
deleteAll(investment, 'Investment');

// 9. Investment batches (optional; may be empty)
let batchColl;
try {
  batchColl = db.getCollection('InvestmentBatch');
  deleteAll(batchColl, 'InvestmentBatch');
} catch (e) {
  print('InvestmentBatch: collection not present (skip)');
}

print('--- Done. Backend cleared for testing. ---');
