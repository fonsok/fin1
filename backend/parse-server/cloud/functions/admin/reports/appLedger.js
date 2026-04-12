'use strict';

const { requirePermission } = require('../../../utils/permissions');
const { applyQuerySort, resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { PLATFORM_ACCOUNTS, FULL_PLATFORM_ACCOUNTS, mapBankContraToEntry } = require('./shared');

const LEDGER_ENTRY_SORT_FIELDS = [
  'createdAt',
  'amount',
];

/**
 * Stable sort for plain ledger row objects (merged / derived paths).
 */
function sortPlainLedgerEntries(entries, sortBy, sortOrder) {
  const field = LEDGER_ENTRY_SORT_FIELDS.includes(sortBy) ? sortBy : 'createdAt';
  const desc = String(sortOrder || '').toLowerCase() !== 'asc';
  const mul = desc ? -1 : 1;
  const tie = (a, b) => String(a.id).localeCompare(String(b.id));
  entries.sort((a, b) => {
    let va = a[field];
    let vb = b[field];
    if (field === 'createdAt') {
      va = new Date(va).getTime();
      vb = new Date(vb).getTime();
    } else if (field === 'amount') {
      va = Number(va) || 0;
      vb = Number(vb) || 0;
    } else {
      va = va == null ? '' : String(va);
      vb = vb == null ? '' : String(vb);
      const c = String(va).localeCompare(String(vb));
      if (c !== 0) return mul * c;
      return tie(a, b);
    }
    if (va < vb) return -1 * mul;
    if (va > vb) return 1 * mul;
    return tie(a, b);
  });
}

function registerAppLedgerReportFunctions() {
  Parse.Cloud.define('getAppLedger', async (request) => {
    requirePermission(request, 'getFinancialDashboard');

    const {
      account,
      userId,
      transactionType,
      dateFrom,
      dateTo,
      limit: maxResults = 500,
      skip = 0,
      sortBy,
      sortOrder,
    } = request.params || {};

    const isBankContraAccount = account === 'BANK-PS-NET' || account === 'BANK-PS-VAT';
    const normalizedUserIdFilter = String(userId || '').trim().toLowerCase();

    const withinDateRange = (createdAt) => {
      const created = new Date(createdAt);
      if (dateFrom && created < new Date(dateFrom)) return false;
      if (dateTo && created > new Date(dateTo)) return false;
      return true;
    };

    const matchesFilters = (entry) => {
      if (account && entry.account !== account) return false;
      if (transactionType && entry.transactionType !== transactionType) return false;
      if (normalizedUserIdFilter && !String(entry.userId || '').toLowerCase().includes(normalizedUserIdFilter)) {
        return false;
      }
      if (!withinDateRange(entry.createdAt)) return false;
      return true;
    };

    if (isBankContraAccount) {
      let bankEntries = [];
      try {
        const bcQuery = new Parse.Query('BankContraPosting');
        bcQuery.equalTo('account', account);
        if (userId) bcQuery.equalTo('investorId', userId);
        if (dateFrom) bcQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
        if (dateTo) bcQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
        applyQuerySort(bcQuery, request.params || {}, {
          allowed: ['createdAt', 'amount'],
          defaultField: 'createdAt',
          defaultDesc: true,
        });
        bcQuery.limit(maxResults + skip);
        const results = await bcQuery.find({ useMasterKey: true });
        bankEntries = results.map(mapBankContraToEntry);
      } catch {
        // BankContraPosting class may not exist
      }
      const filteredBankEntries = bankEntries.filter(matchesFilters);
      sortPlainLedgerEntries(filteredBankEntries, sortBy, resolveListSortOrder(request.params || {}));
      const paginatedBankEntries = filteredBankEntries.slice(skip, skip + maxResults);

      const totals = {};
      for (const e of filteredBankEntries) {
        const key = e.account;
        if (!totals[key]) totals[key] = { credit: 0, debit: 0, net: 0 };
        if (e.side === 'credit') { totals[key].credit += e.amount; totals[key].net += e.amount; } else { totals[key].debit += e.amount; totals[key].net -= e.amount; }
      }
      for (const key of Object.keys(totals)) {
        totals[key].credit = Math.round(totals[key].credit * 100) / 100;
        totals[key].debit = Math.round(totals[key].debit * 100) / 100;
        totals[key].net = Math.round(totals[key].net * 100) / 100;
      }
      const totalRevenue = 0;
      const totalRefunds = 0;
      const vatSummary = {
        outputVATCollected: 0,
        outputVATRemitted: 0,
        inputVATClaimed: 0,
        outstandingVATLiability: 0,
      };
      return {
        entries: paginatedBankEntries,
        totals,
        totalRevenue,
        totalRefunds,
        vatSummary,
        totalCount: filteredBankEntries.length,
        accounts: FULL_PLATFORM_ACCOUNTS,
      };
    }

    let entries = [];
    const mergeBankContra = !account;
    const queryLimit = mergeBankContra ? 2 * (maxResults + skip) : maxResults + skip;
    const querySkip = 0;
    try {
      const query = new Parse.Query('AppLedgerEntry');
      if (account) query.equalTo('account', account);
      if (userId) query.equalTo('userId', userId);
      if (transactionType) query.equalTo('transactionType', transactionType);
      if (dateFrom) query.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
      if (dateTo) query.lessThanOrEqualTo('createdAt', new Date(dateTo));
      applyQuerySort(query, request.params || {}, {
        allowed: ['createdAt', 'amount'],
        defaultField: 'createdAt',
        defaultDesc: true,
      });
      query.limit(queryLimit);
      query.skip(querySkip);

      const results = await query.find({ useMasterKey: true });
      entries = results.map((e) => ({
        id: e.id,
        account: e.get('account'),
        side: e.get('side'),
        amount: e.get('amount'),
        userId: e.get('userId'),
        userRole: e.get('userRole'),
        transactionType: e.get('transactionType'),
        referenceId: e.get('referenceId'),
        referenceType: e.get('referenceType'),
        description: e.get('description') || '',
        createdAt: e.get('createdAt'),
        metadata: e.get('metadata') || {},
      }));
    } catch {
      // Class may not exist yet – derive from investments
    }

    if (entries.length === 0) {
      const invQuery = new Parse.Query('Investment');
      invQuery.exists('platformServiceCharge');
      if (userId) invQuery.equalTo('investorId', userId);
      if (dateFrom) invQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
      if (dateTo) invQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
      applyQuerySort(invQuery, request.params || {}, {
        allowed: ['createdAt', 'amount'],
        defaultField: 'createdAt',
        defaultDesc: true,
      });
      invQuery.limit(maxResults);
      invQuery.skip(skip);

      const investments = await invQuery.find({ useMasterKey: true });

      for (const inv of investments) {
        const psc = inv.get('platformServiceCharge') || {};
        const grossAmount = psc.gross || psc.amount || 0;
        if (grossAmount <= 0) continue;

        const vatRate = 0.19;
        const netAmount = grossAmount / (1 + vatRate);
        const vatAmount = grossAmount - netAmount;
        const investorId = inv.get('investorId') || '';
        const batchId = inv.get('batchId') || inv.id;

        entries.push({
          id: `${inv.id}-rev`,
          account: 'PLT-REV-PSC',
          side: 'credit',
          amount: Math.round(netAmount * 100) / 100,
          userId: investorId,
          userRole: 'investor',
          transactionType: 'platformServiceCharge',
          referenceId: batchId,
          referenceType: 'investment_batch',
          description: `Appgebühr (netto) – Investor ${investorId}`,
          createdAt: inv.get('createdAt'),
          metadata: { component: 'net', grossAmount: grossAmount.toString() },
        });

        entries.push({
          id: `${inv.id}-vat`,
          account: 'PLT-TAX-VAT',
          side: 'credit',
          amount: Math.round(vatAmount * 100) / 100,
          userId: investorId,
          userRole: 'investor',
          transactionType: 'platformServiceCharge',
          referenceId: batchId,
          referenceType: 'investment_batch',
          description: `USt. Appgebühr – Investor ${investorId}`,
          createdAt: inv.get('createdAt'),
          metadata: { component: 'vat', grossAmount: grossAmount.toString() },
        });
      }

      try {
        const invFeeQuery = new Parse.Query('Invoice');
        invFeeQuery.equalTo('invoiceType', 'order');
        if (dateFrom) invFeeQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
        if (dateTo) invFeeQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
        applyQuerySort(invFeeQuery, request.params || {}, {
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
            entries.push({
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
            });
          }

          if (fees.exchangeFee > 0) {
            entries.push({
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
            });
          }

          if (fees.foreignCosts > 0) {
            entries.push({
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
            });
          }
        }
      } catch {
        // Invoice class may not have fee data
      }
    }

    if (!account) {
      try {
        const bcQuery = new Parse.Query('BankContraPosting');
        if (userId) bcQuery.equalTo('investorId', userId);
        if (dateFrom) bcQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
        if (dateTo) bcQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
        applyQuerySort(bcQuery, request.params || {}, {
          allowed: ['createdAt', 'amount'],
          defaultField: 'createdAt',
          defaultDesc: true,
        });
        bcQuery.limit(2 * maxResults);
        const bankResults = await bcQuery.find({ useMasterKey: true });
        const bankEntries = bankResults.map(mapBankContraToEntry);
        entries = [...entries, ...bankEntries];
      } catch {
        // BankContraPosting optional
      }
    }

    const filtered = entries.filter(matchesFilters);
    sortPlainLedgerEntries(filtered, sortBy, resolveListSortOrder(request.params || {}));
    const paginated = filtered.slice(skip, skip + maxResults);

    const totals = {};
    for (const e of filtered) {
      const key = e.account;
      if (!totals[key]) totals[key] = { credit: 0, debit: 0, net: 0 };
      if (e.side === 'credit') {
        totals[key].credit += e.amount;
        totals[key].net += e.amount;
      } else {
        totals[key].debit += e.amount;
        totals[key].net -= e.amount;
      }
    }
    for (const key of Object.keys(totals)) {
      totals[key].credit = Math.round(totals[key].credit * 100) / 100;
      totals[key].debit = Math.round(totals[key].debit * 100) / 100;
      totals[key].net = Math.round(totals[key].net * 100) / 100;
    }

    const totalRevenue = PLATFORM_ACCOUNTS
      .filter((a) => a.group === 'revenue')
      .reduce((sum, a) => sum + (totals[a.code]?.net || 0), 0);

    const vatCollected = totals['PLT-TAX-VAT']?.credit || 0;
    const vatRemitted = totals['PLT-TAX-VAT']?.debit || 0;
    const inputVATClaimed = totals['PLT-TAX-VST']?.debit || 0;
    const vatSummary = {
      outputVATCollected: Math.round(vatCollected * 100) / 100,
      outputVATRemitted: Math.round(vatRemitted * 100) / 100,
      inputVATClaimed: Math.round(inputVATClaimed * 100) / 100,
      outstandingVATLiability: Math.round((vatCollected - vatRemitted - inputVATClaimed) * 100) / 100,
    };

    const totalRefunds = PLATFORM_ACCOUNTS
      .filter((a) => a.group === 'expense')
      .reduce((sum, a) => sum + (totals[a.code]?.debit || 0), 0);

    return {
      entries: paginated,
      totals,
      totalRevenue: Math.round(totalRevenue * 100) / 100,
      totalRefunds: Math.round(totalRefunds * 100) / 100,
      vatSummary,
      totalCount: filtered.length,
      accounts: FULL_PLATFORM_ACCOUNTS,
    };
  });
}

module.exports = { registerAppLedgerReportFunctions };
