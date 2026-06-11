'use strict';

/**
 * Admin: fehlende Eigenbelege (EAP) für bereits gebuchte App-Erfolgsprovision-GL.
 * Erzeugt nur Document — keine erneute postLedgerPair (idempotent pro tradeId).
 */

const { audit } = require('../../utils/structuredLogger');
const { round2 } = require('../../utils/accountingHelper/shared');
const {
  createAppCommissionEigenbeleg,
  DOC_TYPE,
  LEGACY_DOC_TYPE,
} = require('../../utils/accountingHelper/documents/appCommissionEigenbeleg');

const EIGENBEG_TYPES = [DOC_TYPE, LEGACY_DOC_TYPE];

async function hasAppCommissionEigenbeleg(tradeId) {
  const q = new Parse.Query('Document');
  q.equalTo('tradeId', tradeId);
  q.containedIn('type', EIGENBEG_TYPES);
  q.equalTo('source', 'backend');
  return Boolean(await q.first({ useMasterKey: true }));
}

async function readAppCommissionGLAmount(tradeId) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', tradeId);
  q.equalTo('referenceType', 'Trade');
  q.equalTo('transactionType', 'appCommission');
  q.equalTo('account', 'PLT-REV-COM');
  q.equalTo('side', 'credit');
  q.limit(4);
  const rows = await q.find({ useMasterKey: true });
  const legRow = rows.find((row) => (row.get('metadata') || {}).leg === 'app_commission');
  const amount = Number(legRow?.get('amount') || 0);
  return round2(amount);
}

async function resolveParticipationTotals(tradeId) {
  const parts = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .limit(500)
    .find({ useMasterKey: true });

  let totalApp = 0;
  let grossBasis = 0;

  for (const part of parts) {
    totalApp += Number(part.get('appCommissionAmount') || 0);
    grossBasis += Number(part.get('profitShare') || 0);
  }

  return {
    totalApp: round2(totalApp),
    grossBasis: round2(grossBasis),
  };
}

async function resolveAppCommissionRate(tradeId, totalAppCommission, grossProfitBasis) {
  const fromBill = await resolveRateFromCollectionBill(tradeId);
  if (Number.isFinite(fromBill)) return fromBill;
  if (grossProfitBasis > 0 && totalAppCommission > 0) {
    return round2(totalAppCommission / grossProfitBasis);
  }
  const { getAppCommissionRate } = require('../../utils/configHelper/index.js');
  return getAppCommissionRate();
}

async function resolveRateFromCollectionBill(tradeId) {
  const q = new Parse.Query('Document');
  q.equalTo('tradeId', tradeId);
  q.equalTo('type', 'investorCollectionBill');
  q.equalTo('source', 'backend');
  q.limit(1);
  const bill = await q.first({ useMasterKey: true });
  const meta = bill?.get('metadata') || {};
  return Number.isFinite(meta.appCommissionRateSnapshot) ? meta.appCommissionRateSnapshot : null;
}

/**
 * @param {import('parse/node').Cloud.FunctionRequest} request
 */
async function handleBackfillAppCommissionEigenbeleg(request) {
  const params = request.params || {};
  const dryRun = params.dryRun !== false;
  const limit = Math.min(200, Math.max(1, parseInt(params.limit, 10) || 25));
  const tradeIdParam = String(params.tradeId || '').trim();

  let candidateTradeIds = [];

  if (tradeIdParam) {
    candidateTradeIds = [tradeIdParam];
  } else {
    const glQ = new Parse.Query('AppLedgerEntry');
    glQ.equalTo('transactionType', 'appCommission');
    glQ.equalTo('account', 'PLT-REV-COM');
    glQ.equalTo('side', 'credit');
    glQ.descending('createdAt');
    glQ.limit(limit * 3);
    const rows = await glQ.find({ useMasterKey: true });
    const seen = new Set();
    for (const row of rows) {
      const md = row.get('metadata') || {};
      if (md.leg !== 'app_commission') continue;
      const tradeId = String(row.get('referenceId') || '').trim();
      if (!tradeId || seen.has(tradeId)) continue;
      seen.add(tradeId);
      candidateTradeIds.push(tradeId);
      if (candidateTradeIds.length >= limit) break;
    }
  }

  const results = [];
  let created = 0;
  let skipped = 0;
  let failed = 0;

  for (const tradeId of candidateTradeIds) {
    try {
      if (await hasAppCommissionEigenbeleg(tradeId)) {
        skipped += 1;
        results.push({ tradeId, status: 'skipped', reason: 'eigenbeleg_exists' });
        continue;
      }

      const glAmount = await readAppCommissionGLAmount(tradeId);
      if (glAmount <= 0) {
        skipped += 1;
        results.push({ tradeId, status: 'skipped', reason: 'no_app_commission_gl' });
        continue;
      }

      const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
      const partTotals = await resolveParticipationTotals(tradeId);
      const totalAppCommission = partTotals.totalApp > 0 ? partTotals.totalApp : glAmount;
      const grossProfitBasis = partTotals.grossBasis > 0 ? partTotals.grossBasis : null;
      const appCommissionRate = await resolveAppCommissionRate(
        tradeId,
        totalAppCommission,
        grossProfitBasis,
      );

      if (dryRun) {
        results.push({
          tradeId,
          status: 'would_create',
          totalAppCommission,
          glAmount,
          appCommissionRate,
          grossProfitBasis,
          tradeNumber: trade.get('tradeNumber'),
        });
        continue;
      }

      const doc = await createAppCommissionEigenbeleg({
        trade,
        traderId: trade.get('traderId'),
        totalAppCommission,
        appCommissionRate,
        grossProfitBasis,
        businessCaseId: trade.get('businessCaseId'),
      });

      if (!doc) {
        failed += 1;
        results.push({ tradeId, status: 'failed', reason: 'create_returned_null' });
        continue;
      }

      created += 1;
      results.push({
        tradeId,
        status: 'created',
        documentId: doc.id,
        documentNumber: doc.get('accountingDocumentNumber'),
        totalAppCommission,
      });
    } catch (err) {
      failed += 1;
      results.push({
        tradeId,
        status: 'failed',
        error: err?.message || String(err),
      });
    }
  }

  audit.info('admin.appCommissionEigenbeleg.backfill', {
    dryRun,
    candidateCount: candidateTradeIds.length,
    created,
    skipped,
    failed,
  });

  return {
    dryRun,
    candidateCount: candidateTradeIds.length,
    created,
    skipped,
    failed,
    results,
  };
}

module.exports = {
  handleBackfillAppCommissionEigenbeleg,
};
