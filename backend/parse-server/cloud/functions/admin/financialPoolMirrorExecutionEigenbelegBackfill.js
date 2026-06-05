'use strict';

/**
 * Admin: Pool-Mirror Eigenbelege (PMBC/PMSC) aus Trader-TBC/TSC + Participations erzeugen.
 */

const { audit } = require('../../utils/structuredLogger');
const { getMirrorTradeForPairedTraderLeg } = require('../../utils/pairedTradeMirrorSync');
const {
  ensurePoolMirrorExecutionEigenbelegDocument,
  DOC_TYPE,
} = require('../../utils/accountingHelper/poolMirrorExecutionEigenbelegBook');

async function findTraderExecutionDoc(traderTradeId, executionType) {
  const q = new Parse.Query('Document');
  q.equalTo('tradeId', traderTradeId);
  q.containedIn('type', ['traderCollectionBill', 'trade_execution_document']);
  q.equalTo('metadata.executionType', String(executionType).toLowerCase());
  q.ascending('createdAt');
  return q.first({ useMasterKey: true });
}

/**
 * @param {import('parse/node').Cloud.FunctionRequest} request
 */
async function handleBackfillPoolMirrorExecutionEigenbeleg(request) {
  const params = request.params || {};
  const dryRun = params.dryRun !== false;
  const force = Boolean(params.force);
  const executionType = String(params.executionType || 'buy').toLowerCase();
  const limit = Math.min(200, Math.max(1, parseInt(params.limit, 10) || 25));

  let traderTrade = null;
  const poolTradeId = String(params.poolTradeId || params.mirrorTradeId || '').trim();
  const traderTradeId = String(params.traderTradeId || '').trim();
  const traderDocNumber = String(params.traderDocumentNumber || params.documentNumber || '').trim();

  if (traderDocNumber) {
    const dq = new Parse.Query('Document');
    dq.equalTo('accountingDocumentNumber', traderDocNumber);
    const traderDoc = await dq.first({ useMasterKey: true });
    if (traderDoc) {
      traderTrade = await new Parse.Query('Trade').get(traderDoc.get('tradeId'), { useMasterKey: true });
    }
  } else if (traderTradeId) {
    traderTrade = await new Parse.Query('Trade').get(traderTradeId, { useMasterKey: true });
  } else if (poolTradeId) {
    const poolTrade = await new Parse.Query('Trade').get(poolTradeId, { useMasterKey: true });
    const { getTraderTradeForPairedMirrorLeg } = require('../../utils/pairedTradeMirrorSync');
    traderTrade = await getTraderTradeForPairedMirrorLeg(poolTrade);
    if (!traderTrade) traderTrade = poolTrade;
  }

  if (!traderTrade?.id) {
    return { dryRun, error: 'traderTrade not resolved — pass traderTradeId, poolTradeId, or traderDocumentNumber' };
  }

  const mirror = await getMirrorTradeForPairedTraderLeg(traderTrade);
  const poolTrade = mirror || (poolTradeId ? await new Parse.Query('Trade').get(poolTradeId, { useMasterKey: true }) : null);

  const traderExecDoc = await findTraderExecutionDoc(traderTrade.id, executionType);
  if (!traderExecDoc) {
    return {
      dryRun,
      error: `no trader execution document (${executionType}) for trade ${traderTrade.id}`,
    };
  }

  if (!poolTrade?.id || poolTrade.id === traderTrade.id) {
    const parts = await new Parse.Query('PoolTradeParticipation')
      .equalTo('tradeId', traderTrade.id)
      .limit(1)
      .first({ useMasterKey: true });
    if (!parts) {
      return { dryRun, error: 'no pool mirror trade / participations found' };
    }
  }

  const targetPoolId = poolTrade?.id && poolTrade.id !== traderTrade.id ? poolTrade.id : traderTrade.id;

  if (dryRun) {
    const check = new Parse.Query('Document');
    check.equalTo('tradeId', targetPoolId);
    check.equalTo('type', DOC_TYPE);
    check.equalTo('metadata.executionType', executionType);
    const exists = await check.first({ useMasterKey: true });
    return {
      dryRun: true,
      force,
      executionType,
      traderTradeId: traderTrade.id,
      poolTradeId: targetPoolId,
      traderDocumentNumber: traderExecDoc.get('accountingDocumentNumber'),
      wouldUpdate: Boolean(exists) || true,
      existingPoolDocId: exists?.id || null,
      existingPoolDocNumber: exists?.get('accountingDocumentNumber') || null,
    };
  }

  const doc = await ensurePoolMirrorExecutionEigenbelegDocument({
    traderTrade,
    traderExecutionDoc: traderExecDoc,
    executionType,
    force,
  });

  audit.info('admin.poolMirrorEigenbeleg.backfill', {
    traderTradeId: traderTrade.id,
    poolTradeId: targetPoolId,
    documentId: doc?.id,
    executionType,
    force,
  });

  return {
    dryRun: false,
    force,
    executionType,
    traderTradeId: traderTrade.id,
    poolTradeId: targetPoolId,
    traderDocumentNumber: traderExecDoc.get('accountingDocumentNumber'),
    poolDocumentId: doc?.id,
    poolDocumentNumber: doc?.get('accountingDocumentNumber'),
    updated: true,
  };
}

module.exports = {
  handleBackfillPoolMirrorExecutionEigenbeleg,
};
