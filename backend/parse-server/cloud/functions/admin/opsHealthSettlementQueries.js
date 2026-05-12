'use strict';

const { round2, statementSumKey } = require('./opsHealthSettlementHelpers');

async function getStatementSumsByTypeForTrade(tradeId) {
  const q = new Parse.Query('AccountStatement');
  q.equalTo('tradeId', tradeId);
  q.equalTo('source', 'backend');
  q.containedIn('entryType', [
    'investment_return',
    'commission_debit',
    'withholding_tax_debit',
    'solidarity_surcharge_debit',
    'church_tax_debit',
  ]);
  q.limit(5000);
  const rows = await q.find({ useMasterKey: true });
  const sums = new Map();
  for (const row of rows) {
    const key = statementSumKey({
      userId: String(row.get('userId') || '').trim(),
      investmentId: String(row.get('investmentId') || '').trim(),
      entryType: String(row.get('entryType') || '').trim(),
    });
    const current = Number(sums.get(key) || 0);
    const amount = Math.abs(Number(row.get('amount') || 0));
    sums.set(key, round2(current + amount));
  }
  return sums;
}

async function sumExpectedTaxFromCollectionBills({ userId, tradeId, investmentId }) {
  const q = new Parse.Query('Document');
  q.equalTo('userId', userId);
  q.equalTo('tradeId', tradeId);
  q.equalTo('investmentId', investmentId);
  q.equalTo('type', 'investorCollectionBill');
  q.equalTo('source', 'backend');
  const docs = await q.find({ useMasterKey: true });

  return docs.reduce((acc, doc) => {
    const metadata = doc.get('metadata') || {};
    const tax = metadata.taxBreakdown || {};
    const totalTax = Number(tax.totalTax || 0);
    return round2(acc + (Number.isFinite(totalTax) ? totalTax : 0));
  }, 0);
}

async function getExpectedTaxByInvestmentForTrade(tradeId) {
  const q = new Parse.Query('Document');
  q.equalTo('tradeId', tradeId);
  q.equalTo('type', 'investorCollectionBill');
  q.equalTo('source', 'backend');
  const docs = await q.find({ useMasterKey: true });

  const byKey = new Map();
  for (const doc of docs) {
    const investmentId = String(doc.get('investmentId') || '').trim();
    const userId = String(doc.get('userId') || '').trim();
    if (!investmentId || !userId) continue;
    const metadata = doc.get('metadata') || {};
    const tax = metadata.taxBreakdown || {};
    const totalTax = Number(tax.totalTax || 0);
    if (!Number.isFinite(totalTax)) continue;
    const key = `${userId}::${investmentId}`;
    byKey.set(key, round2((byKey.get(key) || 0) + totalTax));
  }
  return byKey;
}

async function getExpectedSettlementByInvestmentForTrade(tradeId) {
  const q = new Parse.Query('Document');
  q.equalTo('tradeId', tradeId);
  q.equalTo('type', 'investorCollectionBill');
  q.equalTo('source', 'backend');
  const docs = await q.find({ useMasterKey: true });

  const byKey = new Map();
  for (const doc of docs) {
    const investmentId = String(doc.get('investmentId') || '').trim();
    const userId = String(doc.get('userId') || '').trim();
    if (!investmentId || !userId) continue;
    const metadata = doc.get('metadata') || {};
    const sellLeg = metadata.sellLeg || {};
    const rawGrossProfit = metadata.grossProfit;
    const rawNetProfit = metadata.netProfit;
    const rawInvestmentCapital = metadata.buyLeg && metadata.buyLeg.amount;
    const rawSellAmount = sellLeg.amount;
    const rawCommission = metadata.commission;
    const grossProfit = Number(rawGrossProfit || 0);
    const netProfit = Number(rawNetProfit || 0);
    const investmentCapital = Number(rawInvestmentCapital || 0);
    const fallbackGrossReturn = round2(investmentCapital + grossProfit);
    const grossReturn = Number(rawSellAmount);
    const commission = Number(rawCommission || 0);
    const grossReturnFromProfitBreakdown = round2(investmentCapital + netProfit + commission);
    const hasProfitBreakdownSignal =
      rawNetProfit !== undefined &&
      rawInvestmentCapital !== undefined &&
      rawCommission !== undefined;
    const hasGrossReturnSignal =
      rawSellAmount !== undefined ||
      rawGrossProfit !== undefined ||
      rawInvestmentCapital !== undefined;
    const hasCommissionSignal = rawCommission !== undefined;
    if (!hasGrossReturnSignal && !hasCommissionSignal) continue;

    const key = `${userId}::${investmentId}`;
    const prev = byKey.get(key) || { grossReturn: 0, commission: 0 };
    byKey.set(key, {
      grossReturn: round2(
        prev.grossReturn +
        (hasProfitBreakdownSignal
          ? grossReturnFromProfitBreakdown
          : (Number.isFinite(grossReturn) ? grossReturn : fallbackGrossReturn)),
      ),
      commission: round2(prev.commission + (Number.isFinite(commission) ? commission : 0)),
    });
  }
  return byKey;
}

async function getInvestmentsByIds(ids) {
  const uniqueIds = Array.from(new Set((ids || []).map((id) => String(id || '').trim()).filter(Boolean)));
  if (!uniqueIds.length) return new Map();
  const q = new Parse.Query('Investment');
  q.containedIn('objectId', uniqueIds);
  q.limit(Math.max(1000, uniqueIds.length));
  const rows = await q.find({ useMasterKey: true });
  const byId = new Map();
  for (const row of rows) byId.set(row.id, row);
  return byId;
}

module.exports = {
  getStatementSumsByTypeForTrade,
  sumExpectedTaxFromCollectionBills,
  getExpectedTaxByInvestmentForTrade,
  getExpectedSettlementByInvestmentForTrade,
  getInvestmentsByIds,
};
