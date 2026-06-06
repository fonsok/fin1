'use strict';

/**
 * Summary Report trades tab: one list row per trader-visible position.
 * Pool-Mirror legs stay in Mongo (ledger, Eigenbelege) but are nested under TRADER rows.
 * Aligns with iOS `TraderDepotTradeFilter` (no duplicate depot/holding row).
 */

function buildExcludePoolMirrorLegMongoClause() {
  return {
    $nor: [
      { buyLegType: 'MIRROR_POOL' },
      { 'buyOrder.isMirrorPoolOrder': true },
    ],
  };
}

/**
 * `hasPoolParticipation` is often denormalized on the mirror trade only — paired TRADER legs
 * still need to match filter "mit Investoren".
 */
function buildHasPoolInvestorsMongoClause(hasPoolInvestors) {
  if (hasPoolInvestors === 'yes') {
    return {
      $or: [
        { hasPoolParticipation: true },
        { pairExecutionId: { $exists: true, $nin: [null, ''] } },
      ],
    };
  }
  if (hasPoolInvestors === 'no') {
    return {
      $and: [
        {
          $or: [
            { hasPoolParticipation: { $ne: true } },
            { hasPoolParticipation: { $exists: false } },
          ],
        },
        {
          $or: [
            { pairExecutionId: { $exists: false } },
            { pairExecutionId: null },
            { pairExecutionId: '' },
          ],
        },
      ],
    };
  }
  return null;
}

/** Parse.Query AND-part for non-aggregate trade counts (dashboard summary). */
function buildExcludePoolMirrorLegParseQuery() {
  const legNotMirror = new Parse.Query('Trade');
  legNotMirror.notEqualTo('buyLegType', 'MIRROR_POOL');
  const legMissing = new Parse.Query('Trade');
  legMissing.doesNotExist('buyLegType');
  const legOk = Parse.Query.or(legNotMirror, legMissing);

  const orderNotMirror = new Parse.Query('Trade');
  orderNotMirror.notEqualTo('buyOrder.isMirrorPoolOrder', true);
  const orderFlagMissing = new Parse.Query('Trade');
  orderFlagMissing.doesNotExist('buyOrder.isMirrorPoolOrder');
  const orderOk = Parse.Query.or(orderNotMirror, orderFlagMissing);

  return Parse.Query.and(legOk, orderOk);
}

function buildHasPoolInvestorsParseQuery(hasPoolInvestors) {
  if (!hasPoolInvestors) return null;
  if (hasPoolInvestors === 'yes') {
    const withFlag = new Parse.Query('Trade');
    withFlag.equalTo('hasPoolParticipation', true);
    const paired = new Parse.Query('Trade');
    paired.exists('pairExecutionId');
    return Parse.Query.or(withFlag, paired);
  }
  const noFlag = new Parse.Query('Trade');
  noFlag.notEqualTo('hasPoolParticipation', true);
  const noPair = new Parse.Query('Trade');
  noPair.doesNotExist('pairExecutionId');
  return Parse.Query.and(noFlag, noPair);
}

module.exports = {
  buildExcludePoolMirrorLegMongoClause,
  buildHasPoolInvestorsMongoClause,
  buildExcludePoolMirrorLegParseQuery,
  buildHasPoolInvestorsParseQuery,
};
