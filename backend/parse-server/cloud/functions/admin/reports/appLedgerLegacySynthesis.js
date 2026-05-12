'use strict';

const { applyQuerySort } = require('../../../utils/applyQuerySort');
const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const {
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
} = require('./appLedgerConstants');

/**
 * SYNTHESIS flag: see comment in legacy `appLedger` handler (migration-only).
 */
function isLegacyFeeSynthesisEnabled() {
  const value = String(process.env.FIN1_LEDGER_LEGACY_FEE_SYNTHESIS || '').trim().toLowerCase();
  return value === '1' || value === 'true' || value === 'yes' || value === 'on';
}

async function buildLegacySyntheticLedgerEntries(params) {
  const {
    userId,
    dateFrom,
    dateTo,
    maxResults,
    skip,
    requestParams,
    getMappingSnapshotForAccount,
  } = params;

  const rows = [];

  const invQuery = new Parse.Query('Investment');
  invQuery.exists('platformServiceCharge');
  if (userId && looksLikeParseObjectId(String(userId).trim())) invQuery.equalTo('investorId', userId);
  if (dateFrom) invQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
  if (dateTo) invQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
  applyQuerySort(invQuery, requestParams || {}, {
    allowed: ['createdAt', 'amount'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  invQuery.limit(maxResults);
  invQuery.skip(skip);

  const investments = await invQuery.find({ useMasterKey: true });

  for (const inv of investments) {
    const appServiceCharge = inv.get('appServiceCharge') || inv.get('platformServiceCharge') || {};
    const grossAmount = appServiceCharge.gross || appServiceCharge.amount || 0;
    if (grossAmount <= 0) continue;

    const vatRate = 0.19;
    const netAmount = grossAmount / (1 + vatRate);
    const vatAmount = grossAmount - netAmount;
    const investorId = inv.get('investorId') || '';
    const batchId = inv.get('batchId') || inv.id;

    const revSnapshot = getMappingSnapshotForAccount('PLT-REV-PSC') || {};
    rows.push({
      id: `${inv.id}-rev`,
      account: 'PLT-REV-PSC',
      side: 'credit',
      amount: Math.round(netAmount * 100) / 100,
      userId: investorId,
      userRole: 'investor',
      transactionType: TRANSACTION_TYPE_APP_SERVICE_CHARGE,
      referenceId: batchId,
      referenceType: 'investment_batch',
      description: `Appgebühr (netto) – Investor ${investorId}`,
      createdAt: inv.get('createdAt'),
      metadata: { component: 'net', grossAmount: grossAmount.toString() },
      ...revSnapshot,
    });

    const vatSnapshot = getMappingSnapshotForAccount('PLT-TAX-VAT') || {};
    rows.push({
      id: `${inv.id}-vat`,
      account: 'PLT-TAX-VAT',
      side: 'credit',
      amount: Math.round(vatAmount * 100) / 100,
      userId: investorId,
      userRole: 'investor',
      transactionType: TRANSACTION_TYPE_APP_SERVICE_CHARGE,
      referenceId: batchId,
      referenceType: 'investment_batch',
      description: `USt. Appgebühr – Investor ${investorId}`,
      createdAt: inv.get('createdAt'),
      metadata: { component: 'vat', grossAmount: grossAmount.toString() },
      ...vatSnapshot,
    });
  }

  try {
    const invFeeQuery = new Parse.Query('Invoice');
    invFeeQuery.equalTo('invoiceType', 'order');
    if (dateFrom) invFeeQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
    if (dateTo) invFeeQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
    applyQuerySort(invFeeQuery, requestParams || {}, {
      allowed: ['createdAt', 'amount'],
      defaultField: 'createdAt',
      defaultDesc: true,
    });
    invFeeQuery.limit(maxResults);
    const invoices = await invFeeQuery.find({ useMasterKey: true });

    for (const invoice of invoices) {
      const fees = invoice.get('feeBreakdown') || {};
      const invUserId = invoice.get('userId') || '';
      const orderId = invoice.get('orderId') || invoice.id;

      if (fees.orderFee > 0) {
        rows.push({
          id: `${invoice.id}-ord`,
          account: 'PLT-REV-ORD',
          side: 'credit',
          amount: Math.round(fees.orderFee * 100) / 100,
          userId: invUserId,
          userRole: 'trader',
          transactionType: 'orderFee',
          referenceId: orderId,
          referenceType: 'order',
          description: `Ordergebühr – Order ${orderId}`,
          createdAt: invoice.get('createdAt'),
          metadata: { feeType: 'orderFee' },
          ...(getMappingSnapshotForAccount('PLT-REV-ORD') || {}),
        });
      }

      if (fees.exchangeFee > 0) {
        rows.push({
          id: `${invoice.id}-exc`,
          account: 'PLT-REV-EXC',
          side: 'credit',
          amount: Math.round(fees.exchangeFee * 100) / 100,
          userId: invUserId,
          userRole: 'trader',
          transactionType: 'exchangeFee',
          referenceId: orderId,
          referenceType: 'order',
          description: `Börsenplatzgebühr – Order ${orderId}`,
          createdAt: invoice.get('createdAt'),
          metadata: { feeType: 'exchangeFee' },
          ...(getMappingSnapshotForAccount('PLT-REV-EXC') || {}),
        });
      }

      if (fees.foreignCosts > 0) {
        rows.push({
          id: `${invoice.id}-frg`,
          account: 'PLT-REV-FRG',
          side: 'credit',
          amount: Math.round(fees.foreignCosts * 100) / 100,
          userId: invUserId,
          userRole: 'trader',
          transactionType: 'foreignCosts',
          referenceId: orderId,
          referenceType: 'order',
          description: `Fremdkostenpauschale – Order ${orderId}`,
          createdAt: invoice.get('createdAt'),
          metadata: { feeType: 'foreignCosts' },
          ...(getMappingSnapshotForAccount('PLT-REV-FRG') || {}),
        });
      }
    }
  } catch {
    // Invoice class may not have fee data
  }

  return rows;
}

async function mergeLegacySyntheticEntriesWhenEmpty(entries, params) {
  if (!isLegacyFeeSynthesisEnabled() || entries.length > 0) return entries;
  return buildLegacySyntheticLedgerEntries(params);
}

module.exports = {
  mergeLegacySyntheticEntriesWhenEmpty,
};
