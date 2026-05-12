// ============================================================================
// Parse Cloud Code
// functions/trading.js - Trading Functions
// ============================================================================

'use strict';

const { calculateOrderFees } = require('../utils/helpers');
const { requireAdminRole } = require('../utils/permissions');

const { getUserStableId } = require('./tradingIdentity');
const { handleExecutePairedBuy } = require('./tradingPairedBuyExecution');
const { handleUpsertTrade } = require('./tradingUpsertTrade');
const {
  handleGetTradeSettlement,
  handleGetAccountStatement,
  handleGetTradeInvoices,
  handleGetUserInvoices,
} = require('./tradingSettlementReads');

// Get trader's open trades
Parse.Cloud.define('getOpenTrades', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const query = new Parse.Query('Trade');
  query.equalTo('traderId', getUserStableId(user));
  query.containedIn('status', ['pending', 'active', 'partial']);
  query.descending('createdAt');

  const trades = await query.find({ useMasterKey: true });

  return { trades: trades.map(t => t.toJSON()) };
});

// Get trade history
Parse.Cloud.define('getTradeHistory', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, status } = request.params;

  const query = new Parse.Query('Trade');
  query.equalTo('traderId', getUserStableId(user));
  if (status) query.equalTo('status', status);
  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const trades = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    trades: trades.map(t => t.toJSON()),
    total,
    hasMore: skip + trades.length < total,
  };
});

// Calculate order preview (fees, etc.)
Parse.Cloud.define('calculateOrderPreview', async (request) => {
  const { symbol, quantity, price, side, orderType } = request.params;

  const grossAmount = quantity * price;
  const fees = calculateOrderFees(grossAmount);

  const netAmount = side === 'buy'
    ? grossAmount + fees.totalFees
    : grossAmount - fees.totalFees;

  return {
    symbol,
    quantity,
    price,
    side,
    orderType,
    grossAmount,
    fees,
    netAmount,
  };
});

// Place order
Parse.Cloud.define('placeOrder', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { symbol, quantity, price, side, orderType, limitPrice, stopPrice, tradeId } = request.params;

  if (!symbol) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Symbol required');
  if (!quantity || quantity <= 0) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid quantity');
  if (!['buy', 'sell'].includes(side)) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid side');
  if (!['market', 'limit', 'stop', 'stop_limit'].includes(orderType)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid order type');
  }

  if (side === 'sell' && tradeId) {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', getUserStableId(user));
    const trade = await tradeQuery.get(tradeId, { useMasterKey: true });

    if (!trade) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');
    if (quantity > trade.get('remainingQuantity')) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Quantity exceeds available');
    }
  }

  const grossAmount = quantity * (price || limitPrice || 0);
  const fees = calculateOrderFees(grossAmount);

  const Order = Parse.Object.extend('Order');
  const order = new Order();
  order.set('traderId', getUserStableId(user));
  order.set('symbol', symbol);
  order.set('side', side);
  order.set('orderType', orderType);
  order.set('quantity', quantity);
  order.set('price', price);
  order.set('limitPrice', limitPrice);
  order.set('stopPrice', stopPrice);
  order.set('grossAmount', grossAmount);
  order.set('totalFees', fees.totalFees);
  order.set('netAmount', side === 'buy' ? grossAmount + fees.totalFees : grossAmount - fees.totalFees);
  if (tradeId) order.set('tradeId', tradeId);

  await order.save(null, { useMasterKey: true });

  return {
    orderId: order.id,
    orderNumber: order.get('orderNumber'),
    status: order.get('status'),
  };
});

Parse.Cloud.define('executePairedBuy', handleExecutePairedBuy);

Parse.Cloud.define('upsertTrade', handleUpsertTrade);

Parse.Cloud.define('getTradeById', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params || {};
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  const stableId = getUserStableId(user);

  if (request.master) {
    return trade.toJSON();
  }

  if (trade.get('traderId') === stableId) {
    return trade.toJSON();
  }

  const allParticipations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .limit(1000)
    .find({ useMasterKey: true });
  const investmentRefs = allParticipations
    .map((p) => p.get('investmentId'))
    .filter((id) => typeof id === 'string' && id.length > 0);
  if (investmentRefs.length > 0) {
    const investorMatch = await new Parse.Query('Investment')
      .containedIn('objectId', investmentRefs)
      .equalTo('investorId', stableId)
      .first({ useMasterKey: true });
    if (investorMatch) {
      return trade.toJSON();
    }
  }

  throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Access denied');
});

// ============================================================================
// SETTLEMENT & ACCOUNT STATEMENT
// ============================================================================

Parse.Cloud.define('getTradeSettlement', handleGetTradeSettlement);

Parse.Cloud.define('getAccountStatement', handleGetAccountStatement);

Parse.Cloud.define('getTradeInvoices', handleGetTradeInvoices);

Parse.Cloud.define('getUserInvoices', handleGetUserInvoices);

// Get holdings
Parse.Cloud.define('getHoldings', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const query = new Parse.Query('Holding');
  query.equalTo('traderId', getUserStableId(user));
  query.equalTo('status', 'active');

  const holdings = await query.find({ useMasterKey: true });

  return { holdings: holdings.map(h => h.toJSON()) };
});

// Get investor collection bill documents for the current user (paginated)
Parse.Cloud.define('getInvestorCollectionBills', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, investmentId, tradeId } = request.params || {};
  const stableId = getUserStableId(user);

  const query = new Parse.Query('Document');
  query.equalTo('userId', stableId);
  query.containedIn('type', ['investor_collection_bill', 'investorCollectionBill']);
  query.doesNotExist('metadata.receiptType');
  if (investmentId) query.equalTo('investmentId', investmentId);
  if (tradeId) query.equalTo('tradeId', tradeId);
  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const docs = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    collectionBills: docs.map(d => d.toJSON()),
    total,
    hasMore: skip + docs.length < total,
  };
});

Parse.Cloud.define('auditCollectionBillReturnPercentage', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }

  const { limit = 100 } = request.params || {};
  const effectiveLimit = Math.min(Math.max(Number(limit) || 100, 1), 1000);

  const baseQuery = new Parse.Query('Document');
  baseQuery.containedIn('type', ['investor_collection_bill', 'investorCollectionBill']);
  baseQuery.doesNotExist('metadata.receiptType');

  const missingQuery = new Parse.Query('Document');
  missingQuery.containedIn('type', ['investor_collection_bill', 'investorCollectionBill']);
  missingQuery.doesNotExist('metadata.receiptType');
  missingQuery.doesNotExist('metadata.returnPercentage');

  const nullQuery = new Parse.Query('Document');
  nullQuery.containedIn('type', ['investor_collection_bill', 'investorCollectionBill']);
  nullQuery.doesNotExist('metadata.receiptType');
  nullQuery.equalTo('metadata.returnPercentage', null);

  const missingAnyQuery = Parse.Query.or(missingQuery, nullQuery);
  missingAnyQuery.descending('createdAt');
  missingAnyQuery.limit(effectiveLimit);

  const [totalActive, missingCount, samples] = await Promise.all([
    baseQuery.count({ useMasterKey: true }),
    missingAnyQuery.count({ useMasterKey: true }),
    missingAnyQuery.find({ useMasterKey: true }),
  ]);

  return {
    totalActiveCollectionBills: totalActive,
    missingReturnPercentageCount: missingCount,
    healthy: missingCount === 0,
    sampledMissingDocuments: samples.map((doc) => ({
      objectId: doc.id,
      type: doc.get('type') || null,
      tradeId: doc.get('tradeId') || null,
      investmentId: doc.get('investmentId') || null,
      createdAt: doc.createdAt || null,
    })),
    checkedAt: new Date().toISOString(),
  };
});
