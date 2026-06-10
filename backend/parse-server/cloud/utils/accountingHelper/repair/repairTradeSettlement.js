'use strict';

const { audit } = require('../../structuredLogger');
const { resolvePairedRepairScope } = require('../../../services/poolMirrorActivation/traderCustomerBookingPolicy');
const { isMirrorPoolTradeLeg } = require('../../../services/poolMirrorActivation/poolActivationPolicy');
const { destroyAllInBatches } = require('./batchDestroy');
const {
  findBackendDocumentsForTrades,
  findBackendStatementsForTrades,
  findCommissionsForTrades,
  findParticipationsForTrades,
  loadInvestmentById,
} = require('./queries');
const { resetParticipation, recalcInvestmentTotalsFromOtherTrades } = require('./investmentRecalc');

function tradeAuditFields(trade) {
  if (!trade || !trade.id) {
    return { tradeId: null, tradeNumber: null, businessCaseId: null };
  }
  const tn = trade.get('tradeNumber');
  const bc = trade.get('businessCaseId');
  return {
    tradeId: trade.id,
    tradeNumber: tn != null ? tn : null,
    businessCaseId: bc != null && String(bc).trim() !== '' ? String(bc).trim() : null,
  };
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
  const reSettle = opts.reSettle !== false;
  const dryRun = opts.dryRun === true;

  if (!tradeId) {
    audit.error('settlement.admin.repair.repairTradeSettlement.invalid', {
      tradeId: null,
      dryRun,
      reSettle,
      error: 'tradeId required',
      message: 'repairTradeSettlement: missing or empty tradeId',
    });
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'tradeId required');
  }

  let trade;
  try {
    trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  } catch (err) {
    audit.error('settlement.admin.repair.repairTradeSettlement.loadTradeFailure', {
      tradeId,
      dryRun,
      reSettle,
      error: err && err.message ? err.message : String(err),
      stack: err && err.stack ? err.stack : undefined,
      message: 'repairTradeSettlement: Trade.get failed (preflight)',
    });
    throw err;
  }

  const repairScope = await resolvePairedRepairScope(trade);
  const tradeIdsForCleanup = repairScope.tradeIdsForCleanup.length
    ? repairScope.tradeIdsForCleanup
    : [tradeId];
  const settlementTrade = repairScope.settlementTrade || trade;

  if (isMirrorPoolTradeLeg(trade) && !repairScope.traderLeg && !opts.repairMirrorLegDirectly) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      'MIRROR_POOL trade repair requires paired TRADER leg or repairMirrorLegDirectly=true',
    );
  }

  let docs;
  let stmts;
  let comms;
  let parts;
  try {
    [docs, stmts, comms, parts] = await Promise.all([
      findBackendDocumentsForTrades(tradeIdsForCleanup),
      findBackendStatementsForTrades(tradeIdsForCleanup),
      findCommissionsForTrades(tradeIdsForCleanup),
      findParticipationsForTrades([repairScope.poolTrade?.id || tradeId]),
    ]);
  } catch (err) {
    audit.error('settlement.admin.repair.repairTradeSettlement.preflightQueriesFailure', {
      ...tradeAuditFields(trade),
      dryRun,
      reSettle,
      phase: 'preflight_queries',
      error: err && err.message ? err.message : String(err),
      stack: err && err.stack ? err.stack : undefined,
      message: 'repairTradeSettlement: parallel preflight queries failed',
    });
    throw err;
  }

  const investmentIds = [...new Set(parts.map((p) => p.get('investmentId')).filter(Boolean))];

  const report = {
    tradeId,
    tradeNumber: trade.get('tradeNumber') || null,
    repairScope: {
      settlementTradeId: settlementTrade.id,
      poolTradeId: repairScope.poolTrade?.id || tradeId,
      tradeIdsForCleanup,
      redirectedFromMirror: repairScope.redirectedFromMirror || false,
    },
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

  const baseAudit = tradeAuditFields(trade);
  audit.info('settlement.admin.repair.repairTradeSettlement.start', {
    ...baseAudit,
    dryRun,
    reSettle,
    counts: report.counts,
    message: 'repairTradeSettlement: scope (dry-run or destructive)',
  });

  if (dryRun) {
    audit.info('settlement.admin.repair.repairTradeSettlement.complete', {
      ...baseAudit,
      dryRun: true,
      reSettle,
      counts: report.counts,
      message: 'repairTradeSettlement: dry-run complete (no changes)',
    });
    return report;
  }

  try {
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
      const { settleAndDistribute } = require('../settlement');
      const baseFields = tradeAuditFields(trade);
      audit.info('settlement.admin.repair.reSettle.start', {
        ...baseFields,
        dryRun: false,
        repairPath: 'repairTradeSettlement',
        message: 'repairTradeSettlement: re-settlement starting',
      });
      try {
        const settlement = await settleAndDistribute(settlementTrade);
        report.reSettleSummary = settlement || { skipped: true };
        audit.info('settlement.admin.repair.reSettle.done', {
          ...tradeAuditFields(settlementTrade),
          investorCount: settlement && settlement.investorCount,
          totalCommission: settlement && settlement.totalCommission,
          message: 'repairTradeSettlement: re-settlement completed',
        });
      } catch (err) {
        report.reSettleSummary = { error: err && err.message ? err.message : String(err) };
        audit.error('settlement.admin.repair.reSettle.failure', {
          ...baseFields,
          error: err && err.message ? err.message : String(err),
          stack: err && err.stack ? err.stack : undefined,
          message: 'repairTradeSettlement: re-settlement failed',
        });
      }
    }

    audit.info('settlement.admin.repair.repairTradeSettlement.complete', {
      ...tradeAuditFields(trade),
      dryRun: false,
      reSettle,
      counts: report.counts,
      reSettleSummaryError: report.reSettleSummary && report.reSettleSummary.error
        ? String(report.reSettleSummary.error)
        : null,
      message: 'repairTradeSettlement: destructive path finished',
    });

    return report;
  } catch (err) {
    audit.error('settlement.admin.repair.repairTradeSettlement.failure', {
      ...tradeAuditFields(trade),
      dryRun: false,
      reSettle,
      error: err && err.message ? err.message : String(err),
      stack: err && err.stack ? err.stack : undefined,
      message: 'repairTradeSettlement: failed before completion',
    });
    throw err;
  }
}

module.exports = {
  repairTradeSettlement,
};
