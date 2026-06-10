'use strict';

const { getUserStableId, collectLedgerUserIdCandidates } = require('../tradingIdentity');
const { getMirrorTradeForPairedTraderLeg } = require('../../utils/pairedTradeMirrorSync');
const { isMirrorPoolTradeLeg } = require('../../services/poolMirrorActivation/poolActivationPolicy');

async function handleGetTradeSettlement(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params;
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  if (!trade) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');

  const stableId = getUserStableId(user);
  const userKeys = collectLedgerUserIdCandidates(user);
  const isTradersOwnTrade = trade.get('traderId') === stableId;

  let isInvestorInTrade = false;
  if (!isTradersOwnTrade) {
    const investorInvestments = userKeys.length === 0
      ? []
      : await new Parse.Query('Investment')
        .containedIn('investorId', userKeys)
        .find({ useMasterKey: true });
    const investmentIds = investorInvestments.map(i => i.id);

    if (investmentIds.length > 0) {
      const participationCount = await new Parse.Query('PoolTradeParticipation')
        .equalTo('tradeId', tradeId)
        .containedIn('investmentId', investmentIds)
        .count({ useMasterKey: true });
      isInvestorInTrade = participationCount > 0;
    }
  }

  if (!isTradersOwnTrade && !isInvestorInTrade && !request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Access denied');
  }

  const accountEntries = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  const documents = await new Parse.Query('Document')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  let mirrorTrade = null;
  let poolParticipationCount = 0;
  if (isTradersOwnTrade && !isMirrorPoolTradeLeg(trade)) {
    mirrorTrade = await getMirrorTradeForPairedTraderLeg(trade);
    if (mirrorTrade?.id) {
      poolParticipationCount = await new Parse.Query('PoolTradeParticipation')
        .equalTo('tradeId', mirrorTrade.id)
        .count({ useMasterKey: true });
    }
  } else if (isMirrorPoolTradeLeg(trade)) {
    poolParticipationCount = await new Parse.Query('PoolTradeParticipation')
      .equalTo('tradeId', tradeId)
      .count({ useMasterKey: true });
  }

  let settlementDocuments = documents;
  if (mirrorTrade?.id && mirrorTrade.id !== tradeId) {
    const mirrorDocs = await new Parse.Query('Document')
      .equalTo('tradeId', mirrorTrade.id)
      .equalTo('source', 'backend')
      .find({ useMasterKey: true });
    const seen = new Set(documents.map((d) => d.id));
    settlementDocuments = [
      ...documents,
      ...mirrorDocs.filter((d) => !seen.has(d.id)),
    ];
  }

  const commissions = await new Parse.Query('Commission')
    .equalTo('tradeId', tradeId)
    .find({ useMasterKey: true });

  const userEntries = accountEntries
    .filter(e => userKeys.includes(e.get('userId')))
    .map(e => e.toJSON());

  const userDocuments = settlementDocuments
    .filter(d => userKeys.includes(d.get('userId')))
    .map(d => d.toJSON());

  return {
    tradeId,
    tradeNumber: trade.get('tradeNumber'),
    pairExecutionId: trade.get('pairExecutionId') || null,
    mirrorTradeId: mirrorTrade?.id || null,
    poolParticipationCount,
    grossProfit: trade.get('grossProfit') || 0,
    totalFees: trade.get('totalFees') || 0,
    netProfit: trade.get('netProfit') || 0,
    status: trade.get('status'),
    isSettledByBackend: accountEntries.length > 0,
    accountStatementEntries: userEntries,
    documents: userDocuments,
    commissions: commissions
      .filter(c => userKeys.includes(c.get('traderId')) || userKeys.includes(c.get('investorId')))
      .map(c => c.toJSON()),
  };
}

module.exports = {
  handleGetTradeSettlement,
};
