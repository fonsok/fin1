'use strict';

// ============================================================================
// utils/accountingHelper/repair.js – Trade-Settlement Reparatur
//
// Räumt für einen einzelnen Trade alle backend-erzeugten Belege, Buchungen,
// Commissions und Wallet-Receipts auf und stößt anschließend ein sauberes
// `settleAndDistribute` neu an. Notwendig, wenn ein vorheriger Lauf
// (z. B. wegen Abbruch oder älterer Code-Version) Doppelbelege produziert
// hat (#GoB Doppelbeleg-Vermeidung).
//
// Der Pfad ist destruktiv — daher ausschließlich admin-only und stets als
// einmalige Korrektur zu nutzen. Existierende iOS-/Investor-Selbstbelege
// (`source !== 'backend'`) werden NICHT angefasst.
// ============================================================================

const { round2 } = require('./shared');

const BACKEND_DOC_TYPES = [
  'investorCollectionBill',
  'traderCollectionBill',
  'traderCreditNote',
  'invoice',
  'tradeExecution',
  'walletReceipt',
];

const BACKEND_STATEMENT_TYPES = [
  'trade_buy',
  'trade_sell',
  'trading_fees',
  'commission_credit',
  'commission_debit',
  'investment_return',
  'investment_activate',
  'residual_return',
  'withholding_tax_debit',
  'solidarity_surcharge_debit',
  'church_tax_debit',
];

async function destroyAllInBatches(objects) {
  if (!objects || objects.length === 0) return 0;
  // Parse REST destroyAll handles arrays > 50; we batch defensively.
  const BATCH = 50;
  let removed = 0;
  for (let i = 0; i < objects.length; i += BATCH) {
    const slice = objects.slice(i, i + BATCH);
    await Parse.Object.destroyAll(slice, { useMasterKey: true });
    removed += slice.length;
  }
  return removed;
}

async function findBackendDocumentsForTrade(tradeId) {
  const q = new Parse.Query('Document')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .containedIn('type', BACKEND_DOC_TYPES)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findBackendStatementsForTrade(tradeId) {
  const q = new Parse.Query('AccountStatement')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .containedIn('entryType', BACKEND_STATEMENT_TYPES)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findCommissionsForTrade(tradeId) {
  const q = new Parse.Query('Commission')
    .equalTo('tradeId', tradeId)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findParticipationsForTrade(tradeId) {
  const q = new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function findOtherSettledParticipationsForInvestment(investmentId, excludeTradeId) {
  const q = new Parse.Query('PoolTradeParticipation')
    .equalTo('investmentId', investmentId)
    .equalTo('isSettled', true)
    .notEqualTo('tradeId', excludeTradeId)
    .limit(1000);
  return q.find({ useMasterKey: true });
}

async function loadInvestmentById(investmentId) {
  if (!investmentId) return null;
  try {
    return await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
  } catch (_) {
    return null;
  }
}

function resetParticipation(part) {
  part.set('profitShare', 0);
  part.set('commissionAmount', 0);
  part.set('commissionRate', 0);
  part.set('grossReturn', 0);
  part.set('isSettled', false);
  part.unset('settledAt');
  part.unset('profitBasis');
  return part;
}

async function recalcInvestmentTotalsFromOtherTrades({ investment, excludeTradeId }) {
  // Re-derive Investment.profit / commission / currentValue / numberOfTrades
  // from the participations of OTHER (still-settled) trades. If no other
  // settled participation remains, the Investment is reset to its initial
  // capital state — same as before any trade ran on it.
  const others = await findOtherSettledParticipationsForInvestment(
    investment.id,
    excludeTradeId,
  );

  let totalProfit = 0;
  let totalCommission = 0;
  for (const p of others) {
    totalProfit += Number(p.get('grossReturn') || 0); // grossReturn = netProfit per participation
    totalCommission += Number(p.get('commissionAmount') || 0);
  }

  const initialValue =
    Number(investment.get('initialValue')) ||
    Number(investment.get('amount')) ||
    0;

  investment.set('numberOfTrades', others.length);
  investment.set('profit', round2(totalProfit));
  investment.set('totalCommissionPaid', round2(totalCommission));
  investment.set('currentValue', round2(initialValue + totalProfit));
  if (initialValue > 0) {
    investment.set('profitPercentage', round2((totalProfit / initialValue) * 100));
  } else {
    investment.set('profitPercentage', 0);
  }

  // Note: we deliberately keep `status` and `completedAt` as-is. The Investment
  // beforeSave trigger forbids `completed → active` transitions, and changing
  // status here is unnecessary: the subsequent `settleAndDistribute` re-runs
  // will increment the counters back to their correct values, leaving the
  // investment in the same `completed` lifecycle state with corrected
  // numeric totals (profit / commission / currentValue / numberOfTrades).
  return investment;
}

/**
 * Reparatur eines Trades: Belege & Buchungen säubern und neu erzeugen.
 *
 * @param {string} tradeId — Parse Trade ObjectId.
 * @param {object} [opts]
 * @param {boolean} [opts.reSettle=true] — nach Cleanup `settleAndDistribute` aufrufen.
 * @param {boolean} [opts.dryRun=false] — nur zählen, nichts löschen.
 * @returns {Promise<object>} Diagnose-Report.
 */
async function repairTradeSettlement(tradeId, opts = {}) {
  if (!tradeId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'tradeId required');
  }
  const reSettle = opts.reSettle !== false;
  const dryRun = opts.dryRun === true;

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });

  const [docs, stmts, comms, parts] = await Promise.all([
    findBackendDocumentsForTrade(tradeId),
    findBackendStatementsForTrade(tradeId),
    findCommissionsForTrade(tradeId),
    findParticipationsForTrade(tradeId),
  ]);

  const investmentIds = [...new Set(parts.map((p) => p.get('investmentId')).filter(Boolean))];

  const report = {
    tradeId,
    tradeNumber: trade.get('tradeNumber') || null,
    counts: {
      documents: docs.length,
      statements: stmts.length,
      commissions: comms.length,
      participations: parts.length,
      investments: investmentIds.length,
    },
    documentTypes: docs.reduce((acc, d) => {
      const t = d.get('type') || 'unknown';
      acc[t] = (acc[t] || 0) + 1;
      return acc;
    }, {}),
    statementTypes: stmts.reduce((acc, s) => {
      const t = s.get('entryType') || 'unknown';
      acc[t] = (acc[t] || 0) + 1;
      return acc;
    }, {}),
    investmentIds,
    dryRun,
    reSettleRequested: reSettle,
    reSettleSummary: null,
  };

  if (dryRun) return report;

  // 1. Statements first (they reference Documents).
  await destroyAllInBatches(stmts);

  // 2. Commissions.
  await destroyAllInBatches(comms);

  // 3. Documents (CollectionBill, CreditNote, TradeExecution, walletReceipt).
  await destroyAllInBatches(docs);

  // 4. Reset PoolTradeParticipation for this trade.
  for (const p of parts) {
    resetParticipation(p);
  }
  if (parts.length > 0) {
    await Parse.Object.saveAll(parts, { useMasterKey: true });
  }

  // 5. Recompute Investment totals from REMAINING settled participations.
  for (const invId of investmentIds) {
    const inv = await loadInvestmentById(invId);
    if (!inv) continue;
    await recalcInvestmentTotalsFromOtherTrades({ investment: inv, excludeTradeId: tradeId });
    await inv.save(null, { useMasterKey: true });
  }

  // 6. Trigger fresh settlement.
  if (reSettle) {
    const { settleAndDistribute } = require('./settlement');
    try {
      const settlement = await settleAndDistribute(trade);
      report.reSettleSummary = settlement || { skipped: true };
    } catch (err) {
      report.reSettleSummary = { error: err && err.message ? err.message : String(err) };
    }
  }

  return report;
}

module.exports = {
  repairTradeSettlement,
};
