// ============================================================================
// Parse Cloud Code
// functions/reports.js - Reporting Functions
// ============================================================================

'use strict';

// Get user's documents
Parse.Cloud.define('getDocuments', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { type, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('Document');
  query.equalTo('userId', user.id);
  query.equalTo('status', 'active');
  if (type) query.equalTo('documentType', type);
  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const documents = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    documents: documents.map(d => d.toJSON()),
    total,
    hasMore: skip + documents.length < total
  };
});

// Get invoices
Parse.Cloud.define('getInvoices', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { type, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('Invoice');
  query.equalTo('userId', user.id);
  if (type) query.equalTo('invoiceType', type);
  query.descending('invoiceDate');
  query.limit(limit);
  query.skip(skip);

  const invoices = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    invoices: invoices.map(i => i.toJSON()),
    total,
    hasMore: skip + invoices.length < total
  };
});

// Get account statements
Parse.Cloud.define('getAccountStatements', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { year } = request.params;

  const query = new Parse.Query('AccountStatement');
  query.equalTo('userId', user.id);
  if (year) query.equalTo('periodYear', year);
  query.descending('periodYear');
  query.descending('periodMonth');

  const statements = await query.find({ useMasterKey: true });

  return { statements: statements.map(s => s.toJSON()) };
});

// Get trader performance report
Parse.Cloud.define('getTraderPerformance', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Traders only');
  }

  const { period = 30 } = request.params; // days
  const startDate = new Date(Date.now() - period * 24 * 60 * 60 * 1000);

  // Get completed trades in period
  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.equalTo('traderId', user.id);
  tradeQuery.equalTo('status', 'completed');
  tradeQuery.greaterThanOrEqualTo('closedAt', startDate);

  const trades = await tradeQuery.find({ useMasterKey: true });

  let totalProfit = 0;
  let totalVolume = 0;
  let winningTrades = 0;

  trades.forEach(t => {
    const profit = t.get('grossProfit') || 0;
    totalProfit += profit;
    totalVolume += t.get('buyAmount') || 0;
    if (profit > 0) winningTrades++;
  });

  // Get commissions earned
  const commQuery = new Parse.Query('Commission');
  commQuery.equalTo('traderId', user.id);
  commQuery.equalTo('status', 'paid');
  commQuery.greaterThanOrEqualTo('paidAt', startDate);

  const commissions = await commQuery.find({ useMasterKey: true });
  let totalCommissions = 0;
  commissions.forEach(c => totalCommissions += c.get('commissionAmount') || 0);

  return {
    period,
    trades: {
      total: trades.length,
      winning: winningTrades,
      losing: trades.length - winningTrades,
      winRate: trades.length > 0 ? (winningTrades / trades.length) * 100 : 0
    },
    profit: {
      gross: totalProfit,
      commissions: totalCommissions,
      volume: totalVolume,
      returnPct: totalVolume > 0 ? (totalProfit / totalVolume) * 100 : 0
    }
  };
});

// Get investor performance report
Parse.Cloud.define('getInvestorPerformance', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { period = 30 } = request.params;
  const startDate = new Date(Date.now() - period * 24 * 60 * 60 * 1000);

  // Get all investments
  const invQuery = new Parse.Query('Investment');
  invQuery.equalTo('investorId', user.id);

  const investments = await invQuery.find({ useMasterKey: true });

  let totalInvested = 0;
  let totalCurrentValue = 0;
  let totalProfit = 0;
  let activeCount = 0;
  let completedCount = 0;

  investments.forEach(inv => {
    if (inv.get('status') === 'active') {
      activeCount++;
      totalInvested += inv.get('amount') || 0;
      totalCurrentValue += inv.get('currentValue') || 0;
    }
    if (inv.get('status') === 'completed') {
      completedCount++;
    }
    totalProfit += inv.get('profit') || 0;
  });

  return {
    period,
    investments: {
      active: activeCount,
      completed: completedCount,
      total: investments.length
    },
    financials: {
      totalInvested,
      currentValue: totalCurrentValue,
      unrealizedProfit: totalCurrentValue - totalInvested,
      realizedProfit: totalProfit,
      returnPct: totalInvested > 0 ? ((totalCurrentValue - totalInvested) / totalInvested) * 100 : 0
    }
  };
});

// Create service charge invoice for investment
Parse.Cloud.define('createServiceChargeInvoice', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const {
    invoiceNumber,
    grossServiceChargeAmount,
    netServiceChargeAmount,
    vatAmount,
    vatRate,
    batchId,
    investmentIds,
    customerInfo
  } = request.params;

  // Validate required fields
  if (!invoiceNumber || !grossServiceChargeAmount || !customerInfo) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Missing required invoice fields');
  }

  // Generate invoice number if not provided (for backward compatibility)
  let finalInvoiceNumber = invoiceNumber;
  if (!finalInvoiceNumber) {
    const prefix = 'SC'; // Service Charge prefix
    const lastInvoice = await new Parse.Query('Invoice')
      .startsWith('invoiceNumber', `${prefix}-${new Date().getFullYear()}-`)
      .descending('invoiceNumber')
      .first({ useMasterKey: true });

    let seq = 1;
    if (lastInvoice) {
      const parts = lastInvoice.get('invoiceNumber').split('-');
      seq = parseInt(parts[2], 10) + 1;
    }

    finalInvoiceNumber = `${prefix}-${new Date().getFullYear()}-${seq.toString().padStart(7, '0')}`;
  }

  // Create invoice object
  const Invoice = Parse.Object.extend('Invoice');
  const invoice = new Invoice();

  invoice.set('invoiceNumber', finalInvoiceNumber);
  invoice.set('invoiceType', 'service_charge');
  invoice.set('userId', user.id);
  invoice.set('subtotal', netServiceChargeAmount || grossServiceChargeAmount);
  invoice.set('taxAmount', vatAmount || 0);
  invoice.set('taxRate', vatRate || 19.0);
  invoice.set('totalAmount', grossServiceChargeAmount);
  invoice.set('invoiceDate', new Date());
  invoice.set('status', 'issued');
  invoice.set('currency', 'EUR');

  // Link to investment batch if provided.
  // Important: some iOS flows pass a business UUID batchId that is not a Parse objectId.
  // Do not resolve via `get()` here; store as reference string so invoice save
  // remains robust and still triggers server-side ledger booking.
  if (batchId) {
    invoice.set('investmentId', String(batchId));
    invoice.set('batchId', String(batchId));
  }

  // Store investment IDs as metadata
  if (investmentIds && investmentIds.length > 0) {
    invoice.set('investmentIds', investmentIds);
  }

  // Store customer info snapshot
  if (customerInfo) {
    invoice.set('customerName', customerInfo.name || '');
    invoice.set('customerAddress', customerInfo.address || '');
    invoice.set('customerEmail', customerInfo.email || '');
    invoice.set('customerId', customerInfo.customerNumber || user.id);
  }

  await invoice.save(null, { useMasterKey: true });

  return {
    invoiceId: invoice.id,
    invoiceNumber: finalInvoiceNumber,
    status: 'issued'
  };
});
