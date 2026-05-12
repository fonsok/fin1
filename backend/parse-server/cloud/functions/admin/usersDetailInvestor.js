'use strict';

async function loadInvestorInvestmentLists(user, userId) {
  const role = user.get('role');
  if (role !== 'investor') {
    return { investments: [], investmentSummary: null };
  }

  const investorIdByEmail = `user:${user.get('email')}`;

  const invByIdQuery = new Parse.Query('Investment');
  invByIdQuery.equalTo('investorId', userId);
  const invByEmailQuery = new Parse.Query('Investment');
  invByEmailQuery.equalTo('investorId', investorIdByEmail);
  const investmentQuery = Parse.Query.or(invByIdQuery, invByEmailQuery);
  investmentQuery.descending('createdAt');
  investmentQuery.limit(10);
  const investments = await investmentQuery.find({ useMasterKey: true });

  const allInvByIdQuery = new Parse.Query('Investment');
  allInvByIdQuery.equalTo('investorId', userId);
  const allInvByEmailQuery = new Parse.Query('Investment');
  allInvByEmailQuery.equalTo('investorId', investorIdByEmail);
  const allInvestmentsQuery = Parse.Query.or(allInvByIdQuery, allInvByEmailQuery);
  const allInvestments = await allInvestmentsQuery.find({ useMasterKey: true });
  const totalInvested = allInvestments.reduce((sum, i) => sum + (i.get('amount') || 0), 0);
  const totalProfit = allInvestments.reduce((sum, i) => sum + (i.get('profit') || 0), 0);
  const activeInvestments = allInvestments.filter(i => i.get('status') === 'active');

  const completedInvestments = allInvestments.filter(i => i.get('status') === 'completed');
  const investmentSummary = {
    totalInvestments: allInvestments.length,
    activeInvestments: activeInvestments.length,
    completedInvestments: completedInvestments.length,
    reservedInvestments: allInvestments.filter(i => i.get('status') === 'reserved').length,
    totalInvested,
    totalProfit,
    currentValue: activeInvestments.reduce((sum, i) => sum + (i.get('currentValue') || i.get('amount') || 0), 0),
  };

  return { investments, investmentSummary };
}

async function mapInvestmentsForAdminDetail(investments, formatDate) {
  return Promise.all(investments.map(async (i) => {
    const partQuery = new Parse.Query('PoolTradeParticipation');
    partQuery.equalTo('investmentId', i.id);
    const participations = await partQuery.find({ useMasterKey: true });

    let investProfit = i.get('profit') || 0;
    let investStatus = i.get('status') || 'reserved';
    let investProfitPct = i.get('profitPercentage') || 0;
    let investCommission = i.get('totalCommissionPaid') || 0;
    let investTradeCount = i.get('numberOfTrades') || 0;

    let tradeNumber = null;
    let tradeSymbol = null;
    let tradeStatus = null;
    let tradeCompletedAt = null;
    let ownershipPct = 0;
    let allocatedAmount = 0;
    let docRef = null;

    for (const p of participations) {
      const isSettled = p.get('isSettled');
      ownershipPct = p.get('ownershipPercentage') || 0;
      allocatedAmount = p.get('allocatedAmount') || 0;

      if (isSettled) {
        const profitShare = p.get('profitShare');
        if (profitShare != null && profitShare !== '') {
          investProfit = Number(profitShare) || investProfit;
        }
        const commAmt = p.get('commissionAmount');
        if (commAmt != null && commAmt !== '') {
          investCommission = Number(commAmt) || investCommission;
        }
        investTradeCount = 1;
        investStatus = 'completed';
        const capital = i.get('amount') || allocatedAmount;
        if (capital > 0) {
          investProfitPct = parseFloat(((investProfit / capital) * 100).toFixed(2));
        }
      }

      const tradeId = p.get('tradeId');
      if (tradeId) {
        try {
          const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
          tradeNumber = trade.get('tradeNumber');
          tradeSymbol = trade.get('symbol');
          tradeStatus = trade.get('status');
          tradeCompletedAt = formatDate(trade.get('completedAt'));
        } catch (_) {
          void _;
        }
      }
    }

    const docQuery = new Parse.Query('AccountStatement');
    docQuery.equalTo('investmentId', i.id);
    docQuery.containedIn('entryType', ['investment_return', 'investment_profit', 'commission_debit']);
    docQuery.exists('referenceDocumentId');
    docQuery.descending('createdAt');
    docQuery.limit(1);
    const docEntry = await docQuery.first({ useMasterKey: true });
    if (docEntry) {
      const refDocId = docEntry.get('referenceDocumentId');
      if (refDocId) {
        try {
          const doc = await new Parse.Query('Document').get(refDocId, { useMasterKey: true });
          docRef = doc.get('accountingDocumentNumber') || doc.get('documentNumber') || refDocId;
        } catch (_) {
          docRef = refDocId;
        }
      }
    }
    if (!docRef) {
      const billQuery = new Parse.Query('Document');
      billQuery.equalTo('investmentId', i.id);
      billQuery.containedIn('type', ['investorCollectionBill', 'investor_collection_bill']);
      billQuery.descending('createdAt');
      billQuery.limit(1);
      const bill = await billQuery.first({ useMasterKey: true });
      if (bill) {
        docRef = bill.get('accountingDocumentNumber') || bill.get('documentNumber') || bill.id;
      }
    }

    return {
      objectId: i.id,
      traderId: i.get('traderId'),
      traderName: i.get('traderName'),
      amount: i.get('amount'),
      status: investStatus,
      profit: investProfit,
      currentValue: i.get('currentValue'),
      investmentNumber: i.get('investmentNumber'),
      serviceChargeAmount: i.get('serviceChargeAmount'),
      totalCommissionPaid: investCommission,
      numberOfTrades: investTradeCount,
      profitPercentage: investProfitPct,
      createdAt: formatDate(i.get('createdAt')),
      activatedAt: formatDate(i.get('activatedAt')),
      completedAt: formatDate(i.get('completedAt')),
      tradeNumber,
      tradeSymbol,
      tradeStatus,
      tradeCompletedAt,
      ownershipPercentage: ownershipPct,
      allocatedAmount,
      docRef,
    };
  }));
}

module.exports = {
  loadInvestorInvestmentLists,
  mapInvestmentsForAdminDetail,
};
