'use strict';

const {
  countAll,
  destroyAllInBatches,
  destroyParseObjectsTolerant,
} = require('./shared');

function createTradingResetScopedOps({ normalizedScope, sinceDate, targets }) {
  function hasTargets() {
    if (normalizedScope === 'all') return true;
    return (targets.tradeIds?.length || 0) > 0
      || (targets.orderIds?.length || 0) > 0
      || (targets.investmentIds?.length || 0) > 0
      || (targets.holdingIds?.length || 0) > 0
      || (targets.investmentBatchIds?.length || 0) > 0
      || (targets.userIds?.length || 0) > 0;
  }

  async function countScoped(cls) {
    if (normalizedScope === 'all') return countAll(cls);
    if (!hasTargets()) return 0;

    const q = new Parse.Query(cls);
    if (sinceDate) q.greaterThanOrEqualTo('createdAt', sinceDate);

    if (cls === 'Trade' && targets.tradeIds) q.containedIn('objectId', targets.tradeIds);
    else if (cls === 'Order' && targets.orderIds) q.containedIn('objectId', targets.orderIds);
    else if (cls === 'Holding' && targets.holdingIds) q.containedIn('objectId', targets.holdingIds);
    else if (cls === 'Investment' && targets.investmentIds) q.containedIn('objectId', targets.investmentIds);
    else if (cls === 'InvestmentBatch' && targets.investmentBatchIds) q.containedIn('objectId', targets.investmentBatchIds);
    else if (cls === 'PoolTradeParticipation') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = new Parse.Query(cls);
        q1.containedIn('tradeId', targets.tradeIds);
        if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q1);
      }
      if (targets.investmentIds?.length) {
        const q2 = new Parse.Query(cls);
        q2.containedIn('investmentId', targets.investmentIds);
        if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q2);
      }
      return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
    } else if (cls === 'Commission') {
      if (targets.tradeIds?.length) q.containedIn('tradeId', targets.tradeIds);
      else return 0;
    } else if (cls === 'AccountStatement') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = new Parse.Query(cls);
        q1.containedIn('tradeId', targets.tradeIds);
        if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q1);
      }
      if (targets.investmentIds?.length) {
        const qInv = new Parse.Query(cls);
        qInv.containedIn('investmentId', targets.investmentIds);
        if (sinceDate) qInv.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qInv);
      }
      if (targets.userIds?.length) {
        const q2 = new Parse.Query(cls);
        q2.containedIn('userId', targets.userIds);
        if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q2);
      }
      return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
    } else if (cls === 'Document') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = new Parse.Query(cls);
        q1.containedIn('tradeId', targets.tradeIds);
        if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q1);
      }
      if (targets.investmentIds?.length) {
        const q2 = new Parse.Query(cls);
        q2.containedIn('investmentId', targets.investmentIds);
        if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q2);
      }
      if (targets.userIds?.length) {
        const q3 = new Parse.Query(cls);
        q3.containedIn('userId', targets.userIds);
        if (sinceDate) q3.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q3);
      }
      return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
    } else if (cls === 'Invoice') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = new Parse.Query(cls);
        q1.containedIn('tradeId', targets.tradeIds);
        if (sinceDate) q1.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q1);
      }
      if (targets.orderIds?.length) {
        const q2 = new Parse.Query(cls);
        q2.containedIn('orderId', targets.orderIds);
        if (sinceDate) q2.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q2);
      }
      if (targets.userIds?.length) {
        const q3 = new Parse.Query(cls);
        q3.containedIn('userId', targets.userIds);
        if (sinceDate) q3.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(q3);
      }
      return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
    } else if (cls === 'WalletTransaction') {
      if (targets.userIds?.length) q.containedIn('userId', targets.userIds);
      else return 0;
    } else if (cls === 'BankContraPosting') {
      if (targets.userIds?.length) q.containedIn('investorId', targets.userIds);
      else return 0;
    } else if (cls === 'AppLedgerEntry') {
      const ors = [];
      if (targets.userIds?.length) {
        const qUser = new Parse.Query(cls);
        qUser.containedIn('userId', targets.userIds);
        if (sinceDate) qUser.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qUser);
      }
      if (targets.tradeIds?.length) {
        const qTradeRef = new Parse.Query(cls);
        qTradeRef.containedIn('referenceId', targets.tradeIds);
        if (sinceDate) qTradeRef.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qTradeRef);
        const qTradeMeta = new Parse.Query(cls);
        qTradeMeta.containedIn('metadata.tradeId', targets.tradeIds);
        if (sinceDate) qTradeMeta.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qTradeMeta);
      }
      if (targets.orderIds?.length) {
        const qOrderRef = new Parse.Query(cls);
        qOrderRef.containedIn('referenceId', targets.orderIds);
        if (sinceDate) qOrderRef.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qOrderRef);
      }
      if (targets.investmentIds?.length) {
        const qInvRef = new Parse.Query(cls);
        qInvRef.containedIn('referenceId', targets.investmentIds);
        if (sinceDate) qInvRef.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qInvRef);
        const qInvMeta = new Parse.Query(cls);
        qInvMeta.containedIn('metadata.investmentId', targets.investmentIds);
        if (sinceDate) qInvMeta.greaterThanOrEqualTo('createdAt', sinceDate);
        ors.push(qInvMeta);
      }
      return ors.length ? Parse.Query.or(...ors).count({ useMasterKey: true }) : 0;
    } else if (cls === 'Notification' || cls === 'ComplianceEvent') {
      if (targets.userIds?.length) q.containedIn('userId', targets.userIds);
      else return 0;
    }

    return q.count({ useMasterKey: true });
  }

  async function destroyScoped(cls) {
    if (normalizedScope === 'all') return destroyAllInBatches(cls, { batchSize: 500 });
    if (!hasTargets()) return 0;

    async function destroyByQuery(query) {
      query.limit(500);
      let deleted = 0;
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const batch = await query.find({ useMasterKey: true });
        if (!batch || batch.length === 0) break;
        const n = await destroyParseObjectsTolerant(batch);
        deleted += n;
        if (n === 0) {
          console.warn(`devReset: destroyScoped destroyByQuery: batch of ${batch.length} undeletable — stop loop.`);
          break;
        }
      }
      return deleted;
    }

    const mkBase = () => {
      const query = new Parse.Query(cls);
      if (sinceDate) query.greaterThanOrEqualTo('createdAt', sinceDate);
      return query;
    };

    if (cls === 'Trade') {
      if (!targets.tradeIds?.length) return 0;
      const query = mkBase();
      query.containedIn('objectId', targets.tradeIds);
      return destroyByQuery(query);
    }
    if (cls === 'Order') {
      if (!targets.orderIds?.length) return 0;
      const query = mkBase();
      query.containedIn('objectId', targets.orderIds);
      return destroyByQuery(query);
    }
    if (cls === 'Holding') {
      if (!targets.holdingIds?.length) return 0;
      const query = mkBase();
      query.containedIn('objectId', targets.holdingIds);
      return destroyByQuery(query);
    }
    if (cls === 'Investment') {
      if (!targets.investmentIds?.length) return 0;
      const query = mkBase();
      query.containedIn('objectId', targets.investmentIds);
      return destroyByQuery(query);
    }
    if (cls === 'InvestmentBatch') {
      if (!targets.investmentBatchIds?.length) return 0;
      const query = mkBase();
      query.containedIn('objectId', targets.investmentBatchIds);
      return destroyByQuery(query);
    }
    if (cls === 'PoolTradeParticipation') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = mkBase();
        q1.containedIn('tradeId', targets.tradeIds);
        ors.push(q1);
      }
      if (targets.investmentIds?.length) {
        const q2 = mkBase();
        q2.containedIn('investmentId', targets.investmentIds);
        ors.push(q2);
      }
      if (!ors.length) return 0;
      return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
    }
    if (cls === 'Commission') {
      if (!targets.tradeIds?.length) return 0;
      const query = mkBase();
      query.containedIn('tradeId', targets.tradeIds);
      return destroyByQuery(query);
    }
    if (cls === 'AccountStatement') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = mkBase();
        q1.containedIn('tradeId', targets.tradeIds);
        ors.push(q1);
      }
      if (targets.investmentIds?.length) {
        const qInv = mkBase();
        qInv.containedIn('investmentId', targets.investmentIds);
        ors.push(qInv);
      }
      if (targets.userIds?.length) {
        const q2 = mkBase();
        q2.containedIn('userId', targets.userIds);
        ors.push(q2);
      }
      if (!ors.length) return 0;
      return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
    }
    if (cls === 'Document') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = mkBase();
        q1.containedIn('tradeId', targets.tradeIds);
        ors.push(q1);
      }
      if (targets.investmentIds?.length) {
        const q2 = mkBase();
        q2.containedIn('investmentId', targets.investmentIds);
        ors.push(q2);
      }
      if (targets.userIds?.length) {
        const q3 = mkBase();
        q3.containedIn('userId', targets.userIds);
        ors.push(q3);
      }
      if (!ors.length) return 0;
      return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
    }
    if (cls === 'Invoice') {
      const ors = [];
      if (targets.tradeIds?.length) {
        const q1 = mkBase();
        q1.containedIn('tradeId', targets.tradeIds);
        ors.push(q1);
      }
      if (targets.orderIds?.length) {
        const q2 = mkBase();
        q2.containedIn('orderId', targets.orderIds);
        ors.push(q2);
      }
      if (targets.userIds?.length) {
        const q3 = mkBase();
        q3.containedIn('userId', targets.userIds);
        ors.push(q3);
      }
      if (!ors.length) return 0;
      return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
    }
    if (cls === 'WalletTransaction') {
      if (!targets.userIds?.length) return 0;
      const query = mkBase();
      query.containedIn('userId', targets.userIds);
      return destroyByQuery(query);
    }
    if (cls === 'BankContraPosting') {
      if (!targets.userIds?.length) return 0;
      const query = mkBase();
      query.containedIn('investorId', targets.userIds);
      return destroyByQuery(query);
    }
    if (cls === 'AppLedgerEntry') {
      const ors = [];
      if (targets.userIds?.length) {
        const qUser = mkBase();
        qUser.containedIn('userId', targets.userIds);
        ors.push(qUser);
      }
      if (targets.tradeIds?.length) {
        const qTradeRef = mkBase();
        qTradeRef.containedIn('referenceId', targets.tradeIds);
        ors.push(qTradeRef);
        const qTradeMeta = mkBase();
        qTradeMeta.containedIn('metadata.tradeId', targets.tradeIds);
        ors.push(qTradeMeta);
      }
      if (targets.orderIds?.length) {
        const qOrderRef = mkBase();
        qOrderRef.containedIn('referenceId', targets.orderIds);
        ors.push(qOrderRef);
      }
      if (targets.investmentIds?.length) {
        const qInvRef = mkBase();
        qInvRef.containedIn('referenceId', targets.investmentIds);
        ors.push(qInvRef);
        const qInvMeta = mkBase();
        qInvMeta.containedIn('metadata.investmentId', targets.investmentIds);
        ors.push(qInvMeta);
      }
      if (!ors.length) return 0;
      return destroyByQuery(ors.length === 1 ? ors[0] : Parse.Query.or(...ors));
    }
    if (cls === 'Notification' || cls === 'ComplianceEvent') {
      if (!targets.userIds?.length) return 0;
      const query = mkBase();
      query.containedIn('userId', targets.userIds);
      return destroyByQuery(query);
    }

    if (sinceDate) {
      const query = mkBase();
      return destroyByQuery(query);
    }
    return 0;
  }

  return {
    countScoped,
    destroyScoped,
    hasTargets,
  };
}

module.exports = {
  createTradingResetScopedOps,
};
