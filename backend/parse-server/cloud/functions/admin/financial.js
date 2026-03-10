'use strict';

const { requirePermission, logPermissionCheck } = require('../../utils/permissions');
const { getTraderCommissionRate } = require('../../utils/configHelper');

Parse.Cloud.define('getFinancialDashboard', async (request) => {
  requirePermission(request, 'getFinancialDashboard');

  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const investmentQuery = new Parse.Query('Investment');
  investmentQuery.containedIn('status', ['active', 'completed']);
  const investments = await investmentQuery.find({ useMasterKey: true });
  const totalInvestments = investments.reduce((sum, inv) => sum + (inv.get('amount') || 0), 0);

  const tradeQuery = new Parse.Query('Trade');
  const trades = await tradeQuery.find({ useMasterKey: true });

  console.log(`📊 getFinancialDashboard: Found ${trades.length} total trades`);

  const totalRevenue = trades.reduce((sum, trade) => {
    const buyOrder = trade.get('buyOrder') || {};
    const sellOrder = trade.get('sellOrder') || {};
    const sellOrders = trade.get('sellOrders') || [];
    let sellVolume = sellOrder.totalAmount || 0;
    if (sellOrders.length > 0) {
      sellVolume = sellOrders.reduce((s, order) => s + (order.totalAmount || 0), 0);
    }
    if (sellVolume === 0 && buyOrder.totalAmount) {
      sellVolume = buyOrder.totalAmount;
    }
    return sum + sellVolume;
  }, 0);

  const commissionRate = await getTraderCommissionRate();
  const totalFees = trades.reduce((sum, trade) => {
    const profit = trade.get('calculatedProfit') || trade.get('grossProfit') || 0;
    const commission = profit > 0 ? profit * commissionRate : 0;
    return sum + commission;
  }, 0);

  const monthlyTradeQuery = new Parse.Query('Trade');
  monthlyTradeQuery.greaterThanOrEqualTo('createdAt', startOfMonth);
  const monthlyTrades = await monthlyTradeQuery.find({ useMasterKey: true });

  console.log(`📊 getFinancialDashboard: Found ${monthlyTrades.length} trades this month`);

  const monthlyRevenue = monthlyTrades.reduce((sum, trade) => {
    const buyOrder = trade.get('buyOrder') || {};
    const sellOrder = trade.get('sellOrder') || {};
    const sellOrders = trade.get('sellOrders') || [];
    let sellVolume = sellOrder.totalAmount || 0;
    if (sellOrders.length > 0) {
      sellVolume = sellOrders.reduce((s, order) => s + (order.totalAmount || 0), 0);
    }
    if (sellVolume === 0 && buyOrder.totalAmount) {
      sellVolume = buyOrder.totalAmount;
    }
    return sum + sellVolume;
  }, 0);

  const monthlyFees = monthlyTrades.reduce((sum, trade) => {
    const profit = trade.get('calculatedProfit') || trade.get('grossProfit') || 0;
    const commission = profit > 0 ? profit * commissionRate : 0;
    return sum + commission;
  }, 0);

  const correctionQuery = new Parse.Query('CorrectionRequest');
  correctionQuery.equalTo('status', 'pending');
  const pendingCorrections = await correctionQuery.count({ useMasterKey: true });

  const roundingQuery = new Parse.Query('RoundingDifference');
  roundingQuery.equalTo('status', 'open');
  const openRoundingDiffs = await roundingQuery.count({ useMasterKey: true });

  return {
    stats: {
      totalRevenue,
      totalFees,
      totalInvestments,
      pendingCorrections,
      openRoundingDiffs,
      monthlyRevenue,
      monthlyFees,
    },
  };
});

Parse.Cloud.define('getRoundingDifferences', async (request) => {
  requirePermission(request, 'getRoundingDifferences');

  const { status, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('RoundingDifference');

  if (status) {
    query.equalTo('status', status);
  } else {
    query.containedIn('status', ['open', 'under_review']);
  }

  query.descending('occurredAt');
  query.limit(limit);
  query.skip(skip);

  const differences = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return { differences: differences.map(d => d.toJSON()), total };
});

Parse.Cloud.define('createCorrectionRequest', async (request) => {
  requirePermission(request, 'createCorrectionRequest');

  const {
    correctionType,
    targetId,
    targetType,
    reason,
    oldValue,
    newValue
  } = request.params;

  if (!correctionType || !targetId || !targetType || !reason) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'correctionType, targetId, targetType, and reason required'
    );
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const fourEyesReq = new FourEyesRequest();
  fourEyesReq.set('requestType', 'correction');
  fourEyesReq.set('requesterId', request.user.id);
  fourEyesReq.set('requesterRole', request.user.get('role'));
  fourEyesReq.set('status', 'pending');
  fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
  fourEyesReq.set('metadata', {
    correctionType,
    targetId,
    targetType,
    reason,
    oldValue,
    newValue,
  });
  await fourEyesReq.save(null, { useMasterKey: true });

  await logPermissionCheck(request, 'createCorrectionRequest', targetType, targetId);

  return {
    success: true,
    fourEyesRequestId: fourEyesReq.id,
    message: 'Correction request created. Awaiting 4-eyes approval.'
  };
});

Parse.Cloud.define('getCorrectionRequests', async (request) => {
  requirePermission(request, 'getCorrectionRequests');

  const { status, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('FourEyesRequest');
  query.equalTo('requestType', 'correction');

  if (status) {
    query.equalTo('status', status);
  }

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const requests = await query.find({ useMasterKey: true });

  const corrections = requests.map(req => {
    const metadata = req.get('metadata') || {};
    return {
      objectId: req.id,
      type: metadata.correctionType || 'unknown',
      amount: metadata.newValue || 0,
      currency: 'EUR',
      reason: metadata.reason || '',
      status: req.get('status'),
      requestedBy: req.get('requesterId'),
      createdAt: req.get('createdAt').toISOString(),
    };
  });

  return { corrections };
});
