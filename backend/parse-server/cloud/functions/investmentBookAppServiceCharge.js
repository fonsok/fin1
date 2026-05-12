'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const { newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');
const { getAppServiceChargeRateForAccountType } = require('../utils/configHelper');
const { investorOwnsInvestment, resolveInvestorAccountType } = require('./investmentAccess');

/**
 * ADR-007: Idempotent service_charge Invoice for an Investment batch.
 * Ledger booking runs in triggers/invoice/ afterSave.
 */
async function handleBookAppServiceCharge(request) {
  const user = request.user;
  if (!user && !request.master) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  }

  const { investmentId } = request.params || {};
  if (!investmentId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „investmentId“ erforderlich.');
  }

  const Investment = Parse.Object.extend('Investment');
  let investment;
  const userEmail = user ? (user.get('email') || user.get('username') || '').toLowerCase() : '';
  const userStableId = user ? (user.get('stableId') || (userEmail ? `user:${userEmail}` : '')) : '';
  try {
    investment = await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });
  } catch {
    const byBatch = new Parse.Query(Investment);
    byBatch.equalTo('batchId', investmentId);
    byBatch.descending('createdAt');
    investment = await byBatch.first({ useMasterKey: true });
    if (!investment && user) {
      const byInvestorRecent = new Parse.Query(Investment);
      byInvestorRecent.descending('createdAt');
      byInvestorRecent.limit(50);
      const ownerIds = [user.id];
      if (userStableId) ownerIds.push(userStableId);
      if (userEmail) ownerIds.push(userEmail);
      byInvestorRecent.containedIn('investorId', ownerIds);
      const recentRows = await byInvestorRecent.find({ useMasterKey: true });
      const nowMs = Date.now();
      const candidates = recentRows.filter((row) => {
        const status = String(row.get('status') || '').toLowerCase();
        const hasBatch = typeof row.get('batchId') === 'string' && row.get('batchId').trim().length > 0;
        const createdAt = row.get('createdAt');
        const createdMs = createdAt instanceof Date ? createdAt.getTime() : 0;
        const isFresh = createdMs > 0 && (nowMs - createdMs) <= (15 * 60 * 1000);
        return hasBatch && isFresh && ['reserved', 'active', 'executing', 'paused', 'closing'].includes(status);
      });
      const distinctBatchIds = [...new Set(candidates.map((row) => String(row.get('batchId')).trim()))];
      if (distinctBatchIds.length === 1) {
        investment = candidates[0];
      } else if (distinctBatchIds.length > 1) {
        throw new Parse.Error(
          Parse.Error.INVALID_VALUE,
          'InvestmentId konnte nicht eindeutig aufgelöst werden (mehrere aktuelle Batches).'
        );
      } else {
        investment = null;
      }
    }
    if (!investment) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Investment nicht gefunden.');
    }
  }

  if (user && !investorOwnsInvestment(investment, user)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Vorgang nicht erlaubt.');
  }

  const batchId = investment.get('batchId') || investment.id;
  const investorId = investment.get('investorId') || (user ? user.id : null);

  const existing = await new Parse.Query('Invoice')
    .equalTo('batchId', batchId)
    .equalTo('invoiceType', 'service_charge')
    .first({ useMasterKey: true });
  if (existing) {
    return { success: true, invoiceId: existing.id, skipped: true, reason: 'already booked' };
  }

  const batchQuery = new Parse.Query('Investment');
  batchQuery.equalTo('batchId', batchId);
  if (investorId) batchQuery.equalTo('investorId', investorId);
  if (typeof batchQuery.limit === 'function') batchQuery.limit(1000);
  const batchRows = typeof batchQuery.find === 'function'
    ? await batchQuery.find({ useMasterKey: true })
    : [];
  const relevantRows = batchRows.length > 0 ? batchRows : [investment];
  const investmentIds = relevantRows.map((row) => row.id);

  const totalInvestmentAmount = round2(
    relevantRows.reduce((sum, row) => sum + (Number(row.get('amount')) || 0), 0)
  );
  let accountType = investment.get('investorAccountType')
    || (user && user.get('accountType'))
    || 'individual';
  if (!accountType && investorId) {
    accountType = await resolveInvestorAccountType(investorId, 'individual');
  }
  const configuredRate = await getAppServiceChargeRateForAccountType(accountType);
  const rate = Number(investment.get('serviceChargeRate'));
  const serviceChargeRate = Number.isFinite(rate) ? rate : configuredRate;
  const isCompany = String(accountType).toLowerCase() === 'company';

  let grossAmount = round2(totalInvestmentAmount * serviceChargeRate);
  if (grossAmount <= 0) {
    grossAmount = round2(
      relevantRows.reduce((sum, row) => sum + (Number(row.get('serviceChargeTotal')) || 0), 0)
    );
  }

  const netAmount = isCompany
    ? grossAmount
    : round2(grossAmount / 1.19);
  const vatAmount = isCompany
    ? 0
    : round2(grossAmount - netAmount);
  const totalAmount = round2(netAmount + vatAmount);

  if (totalAmount <= 0) {
    return { success: true, invoiceId: null, skipped: true, reason: 'no service charge' };
  }

  const vatRate = netAmount > 0 && vatAmount > 0
    ? round2((vatAmount / netAmount) * 100)
    : 0;

  const primaryBc = String(
    relevantRows[0].get('businessCaseId')
    || investment.get('businessCaseId')
    || '',
  ).trim();
  let businessCaseId = primaryBc;
  if (!businessCaseId) {
    businessCaseId = newBusinessCaseId();
    if (investment && typeof investment.set === 'function' && investment.id) {
      investment.set('businessCaseId', businessCaseId);
      await investment.save(null, { useMasterKey: true });
    }
  }

  const Invoice = Parse.Object.extend('Invoice');
  const invoice = new Invoice();
  invoice.set('invoiceType', 'service_charge');
  invoice.set('investmentId', investment.id);
  invoice.set('batchId', batchId);
  invoice.set('businessCaseId', businessCaseId);
  invoice.set('userId', investorId);
  invoice.set('customerId', investorId);
  invoice.set('customerEmail', investment.get('investorEmail') || '');
  invoice.set('customerName', investment.get('investorName') || '');
  invoice.set('investmentIds', investmentIds);
  invoice.set('subtotal', netAmount);
  invoice.set('taxRate', vatRate);
  invoice.set('taxAmount', vatAmount);
  invoice.set('totalAmount', totalAmount);
  invoice.set('source', 'backend');
  invoice.set('metadata', {
    investmentNumber: investment.get('investmentNumber') || '',
    serviceChargeRate,
    investorAccountType: accountType,
    totalInvestmentAmount,
    adrRef: 'ADR-007-Phase-2',
    businessCaseId,
  });

  await invoice.save(null, { useMasterKey: true });

  return { success: true, invoiceId: invoice.id, skipped: false };
}

module.exports = {
  handleBookAppServiceCharge,
};
