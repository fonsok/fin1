// ============================================================================
// Parse Cloud Code
// functions/trading.js - Trading Functions
// ============================================================================

'use strict';

const { calculateOrderFees } = require('../utils/helpers');

/**
 * Resolve the stable user ID used throughout the data model.
 * Parse User objectId differs from the stableId stored on trade/investment records.
 */
function getUserStableId(user) {
  return user.get('stableId') || `user:${(user.get('email') || user.get('username') || '').toLowerCase()}`;
}

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
    hasMore: skip + trades.length < total
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
    netAmount
  };
});

// Place order
Parse.Cloud.define('placeOrder', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { symbol, quantity, price, side, orderType, limitPrice, stopPrice, tradeId } = request.params;

  // Validate
  if (!symbol) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Symbol required');
  if (!quantity || quantity <= 0) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid quantity');
  if (!['buy', 'sell'].includes(side)) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid side');
  if (!['market', 'limit', 'stop', 'stop_limit'].includes(orderType)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid order type');
  }

  // For sell orders, verify user owns the position
  if (side === 'sell' && tradeId) {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', getUserStableId(user));
    const trade = await tradeQuery.get(tradeId, { useMasterKey: true });

    if (!trade) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');
    if (quantity > trade.get('remainingQuantity')) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Quantity exceeds available');
    }
  }

  // Calculate fees
  const grossAmount = quantity * (price || limitPrice || 0);
  const fees = calculateOrderFees(grossAmount);

  // Create order
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
    status: order.get('status')
  };
});

// ============================================================================
// SETTLEMENT & ACCOUNT STATEMENT
// ============================================================================

// Get the backend-authoritative settlement data for a completed trade
Parse.Cloud.define('getTradeSettlement', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params;
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');

  // Verify trade belongs to user (as trader or as investor)
  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  if (!trade) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');

  const stableId = getUserStableId(user);
  const isTradersOwnTrade = trade.get('traderId') === stableId;

  // Check if user is an investor in this trade
  let isInvestorInTrade = false;
  if (!isTradersOwnTrade) {
    const investorInvestments = await new Parse.Query('Investment')
      .equalTo('investorId', stableId)
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

  // Load AccountStatement entries for this trade
  const accountEntries = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  // Load documents for this trade
  const documents = await new Parse.Query('Document')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  // Load commission records
  const commissions = await new Parse.Query('Commission')
    .equalTo('tradeId', tradeId)
    .find({ useMasterKey: true });

  // Filter entries for the requesting user
  const userEntries = accountEntries
    .filter(e => e.get('userId') === stableId)
    .map(e => e.toJSON());

  const userDocuments = documents
    .filter(d => d.get('userId') === stableId)
    .map(d => d.toJSON());

  return {
    tradeId,
    tradeNumber: trade.get('tradeNumber'),
    grossProfit: trade.get('grossProfit') || 0,
    totalFees: trade.get('totalFees') || 0,
    netProfit: trade.get('netProfit') || 0,
    status: trade.get('status'),
    isSettledByBackend: accountEntries.length > 0,
    accountStatementEntries: userEntries,
    documents: userDocuments,
    commissions: commissions
      .filter(c => c.get('traderId') === stableId || c.get('investorId') === stableId)
      .map(c => c.toJSON()),
  };
});

// Get account statement entries for the current user
Parse.Cloud.define('getAccountStatement', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, entryType } = request.params || {};

  const query = new Parse.Query('AccountStatement');
  query.equalTo('userId', getUserStableId(user));
  if (entryType) query.equalTo('entryType', entryType);
  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const entries = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    entries: entries.map(e => e.toJSON()),
    total,
    hasMore: skip + entries.length < total,
  };
});

// Get invoices for a trade (buy/sell settlement invoices with fee breakdown)
Parse.Cloud.define('getTradeInvoices', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params || {};
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId is required');

  const stableId = getUserStableId(user);

  const query = new Parse.Query('Invoice');
  query.equalTo('tradeId', tradeId);
  query.equalTo('userId', stableId);
  query.descending('invoiceDate');

  const invoices = await query.find({ useMasterKey: true });

  return {
    invoices: invoices.map(inv => inv.toJSON()),
    count: invoices.length,
  };
});

// Get all invoices for the current user (paginated)
Parse.Cloud.define('getUserInvoices', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, invoiceType } = request.params || {};
  const stableId = getUserStableId(user);

  const query = new Parse.Query('Invoice');
  query.equalTo('userId', stableId);
  if (invoiceType) query.equalTo('invoiceType', invoiceType);
  query.descending('invoiceDate');
  query.limit(limit);
  query.skip(skip);

  const invoices = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    invoices: invoices.map(inv => inv.toJSON()),
    total,
    hasMore: skip + invoices.length < total,
  };
});

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
  query.equalTo('type', 'investor_collection_bill');
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
