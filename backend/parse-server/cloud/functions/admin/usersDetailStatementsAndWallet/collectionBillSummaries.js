'use strict';

const { collectLedgerUserIdCandidates } = require('../../tradingIdentity');
const { listInvestorInvestmentIds } = require('../../../utils/investorAccountStatementMerge');
const { round2 } = require('../../../utils/accountingHelper/shared');
const { getTradeNumberCalendarYear } = require('../../../utils/tradeNumberAllocation');

function dedupeParseDocumentsById(rows) {
  const seen = new Set();
  return rows.filter((d) => {
    if (!d?.id || seen.has(d.id)) return false;
    seen.add(d.id);
    return true;
  });
}

function investmentIdFromDocument(doc) {
  const raw = doc.get('investmentId');
  if (!raw) return null;
  if (typeof raw === 'object' && raw.id) return String(raw.id);
  return String(raw).trim() || null;
}

function pickCollectionBillFeeComponents(buyFees, sellFees) {
  const out = [];
  for (const [side, fees] of [['buy', buyFees || {}], ['sell', sellFees || {}]]) {
    let anyDetail = false;
    for (const key of ['orderFee', 'exchangeFee', 'foreignCosts']) {
      const amt = round2(Number(fees[key]) || 0);
      if (amt > 0) {
        out.push({ side, key, amount: amt });
        anyDetail = true;
      }
    }
    if (!anyDetail) {
      const tot = round2(Number(fees.totalFees) || 0);
      if (tot > 0) out.push({ side, key: 'totalFees', amount: tot });
    }
  }
  return out;
}

function parseTradeNumberYearFromDocumentName(name) {
  const match = String(name || '').match(/Trade(\d{4})-(\d{3})/);
  return match ? Number(match[1]) : null;
}

function mapInvestorCollectionBillDocumentToSummary(doc, formatDate) {
  const meta = doc.get('metadata') || {};
  const buyLeg = meta.buyLeg || {};
  const sellLeg = meta.sellLeg || {};
  const buyFees = buyLeg.fees || {};
  const sellFees = sellLeg.fees || {};
  return {
    documentId: doc.id,
    documentNumber: doc.get('accountingDocumentNumber') || null,
    tradeId: doc.get('tradeId') || null,
    tradeNumber: doc.get('tradeNumber') ?? null,
    tradeNumberYear: meta.tradeNumberYear
      ?? parseTradeNumberYearFromDocumentName(doc.get('name'))
      ?? (doc.get('tradeNumber') != null
        ? getTradeNumberCalendarYear(doc.get('createdAt') || new Date())
        : null),
    investmentId: investmentIdFromDocument(doc),
    createdAt: formatDate(doc.get('createdAt')),
    transferAmount: round2(Number(meta.transferAmount) || 0),
    commission: round2(Number(meta.commission) || 0),
    commissionRate: typeof meta.commissionRate === 'number' ? meta.commissionRate : null,
    grossProfit: round2(Number(meta.grossProfit) || 0),
    netProfit: round2(Number(meta.netProfit) || 0),
    totalBuyCost: round2(Number(meta.totalBuyCost) || 0),
    netSellAmount: round2(Number(meta.netSellAmount) || 0),
    buy: {
      quantity: buyLeg.quantity,
      price: buyLeg.price,
      amount: round2(Number(buyLeg.amount) || 0),
      costBasisPerShare:
        typeof buyLeg.costBasisPerShare === 'number' ? buyLeg.costBasisPerShare : null,
    },
    sell: {
      quantity: sellLeg.quantity,
      price: sellLeg.price,
      amount: round2(Number(sellLeg.amount) || 0),
      netSellPricePerShare:
        typeof sellLeg.netSellPricePerShare === 'number' ? sellLeg.netSellPricePerShare : null,
    },
    feeComponents: pickCollectionBillFeeComponents(buyFees, sellFees),
  };
}

async function loadInvestorCollectionBillSummariesForAdmin(user, formatDate) {
  if (String(user.get('role') || '').toLowerCase() !== 'investor') return [];
  const userKeys = collectLedgerUserIdCandidates(user).filter(Boolean);
  const investmentIds = await listInvestorInvestmentIds(user);
  const queries = [];
  if (userKeys.length > 0) {
    const q = new Parse.Query('Document');
    q.equalTo('type', 'investorCollectionBill');
    q.containedIn('userId', userKeys);
    queries.push(q);
  }
  if (investmentIds.length > 0) {
    const q2 = new Parse.Query('Document');
    q2.equalTo('type', 'investorCollectionBill');
    q2.containedIn('investmentId', investmentIds);
    queries.push(q2);
  }
  if (queries.length === 0) return [];
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.descending('createdAt');
  combined.limit(100);
  const rows = dedupeParseDocumentsById(await combined.find({ useMasterKey: true }));
  return rows.map((doc) => mapInvestorCollectionBillDocumentToSummary(doc, formatDate));
}

module.exports = {
  mapInvestorCollectionBillDocumentToSummary,
  loadInvestorCollectionBillSummariesForAdmin,
};
