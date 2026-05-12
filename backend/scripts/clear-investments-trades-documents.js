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
//   - AppLedgerEntry, BankContraPosting (Hauptbuch / Bank-Gegenbuch wie devResetTradingTestData)
//   - Notification, ComplianceEvent (Handels-/Investment-Nebenwirkungen)
//   - Document (Buchhaltungs-Belege: siehe Typ-Liste unten)
//   - Invoices, Orders, Holdings, Trades, Investments, InvestmentBatch
//
// Run with mongosh (see clear-investments-trades-documents.sh for examples).
// Wallet: this script clears WalletTransaction; to set balances to Configuration „initialAccountBalance“,
// use Admin Portal → System → DEV Reset with „Nach Reset: Kontostand = Initial Account Balance“ (Cloud devResetTradingTestData),
// or insert deposits manually.
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

// 2b. Ledger (Parse-Klassen wie Cloud devResetTradingTestData scope=all)
const appLedger = db.getCollection('AppLedgerEntry');
deleteAll(appLedger, 'AppLedgerEntry');
const bankContra = db.getCollection('BankContraPosting');
deleteAll(bankContra, 'BankContraPosting');

// 2c. In-app notifications & compliance events (often trade/investment related)
const notification = db.getCollection('Notification');
deleteAll(notification, 'Notification');
const compliance = db.getCollection('ComplianceEvent');
deleteAll(compliance, 'ComplianceEvent');

// 3. Documents: accounting / trade-linked (camelCase wie cloud/utils/accountingHelper/documents.js)
const document = db.getCollection('Document');
deleteWithQuery(
  document,
  {
    $or: [
      { tradeId: { $exists: true, $ne: null } },
      { investmentId: { $exists: true, $ne: null } },
      {
        type: {
          $in: [
            'traderCreditNote',
            'investorCollectionBill',
            'traderCollectionBill',
            'financial',
            'invoice',
            // Legacy / falsch benannte Typen (falls altbestand)
            'trader_credit_note',
            'investor_collection_bill',
          ],
        },
      },
    ],
  },
  'Document (trade/investment-linked & accounting types)',
);

// 5. Invoices (order/trade related)
const invoice = db.getCollection('Invoice');
deleteAll(invoice, 'Invoice');

// 6. Orders (reference trades)
const order = db.getCollection('Order');
deleteAll(order, 'Order');

// 6b. Holdings (server-side trader depot rows; reference trades)
const holding = db.getCollection('Holding');
deleteAll(holding, 'Holding');

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
