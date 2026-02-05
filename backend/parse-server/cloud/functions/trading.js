// ============================================================================
// Parse Cloud Code
// functions/trading.js - Trading Functions
// ============================================================================

'use strict';

const { calculateOrderFees } = require('../utils/helpers');

// Get trader's open trades
Parse.Cloud.define('getOpenTrades', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const query = new Parse.Query('Trade');
  query.equalTo('traderId', user.id);
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
  query.equalTo('traderId', user.id);
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
    tradeQuery.equalTo('traderId', user.id);
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
  order.set('traderId', user.id);
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

// Get holdings
Parse.Cloud.define('getHoldings', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const query = new Parse.Query('Holding');
  query.equalTo('traderId', user.id);
  query.equalTo('status', 'active');

  const holdings = await query.find({ useMasterKey: true });

  return { holdings: holdings.map(h => h.toJSON()) };
});
