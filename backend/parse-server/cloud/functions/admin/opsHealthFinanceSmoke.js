'use strict';

function looksLikeParseObjectId(value) {
  return typeof value === 'string' && /^[A-Za-z0-9]{10}$/.test(value);
}

async function runLedgerFuzzySmoke({ userFilter = 'eweber', sampleLimit = 500 }) {
  const query = new Parse.Query('AppLedgerEntry');
  query.descending('createdAt');
  query.limit(Math.min(2000, Math.max(100, sampleLimit)));
  const rows = await query.find({ useMasterKey: true });
  const needle = String(userFilter || '').trim().toLowerCase();

  const matched = rows.filter((row) => {
    const metadata = row.get('metadata') || {};
    const fields = [
      String(row.get('userId') || '').toLowerCase(),
      String(metadata.userIdRaw || '').toLowerCase(),
      String(metadata.userCustomerNumber || '').toLowerCase(),
      String(metadata.userDisplayName || '').toLowerCase(),
      String(metadata.userUsername || '').toLowerCase(),
    ];
    return fields.some((f) => f.includes(needle));
  });

  return {
    sampledRows: rows.length,
    fuzzyUserFilter: needle,
    matches: matched.length,
    parseObjectIdFilterWouldApply: looksLikeParseObjectId(needle),
  };
}

async function runReferenceDocumentCoverageSmoke({ sinceHours = 168 }) {
  const since = new Date(Date.now() - (Math.max(1, Number(sinceHours) || 168) * 3600 * 1000));
  const q = new Parse.Query('AccountStatement');
  q.equalTo('source', 'backend');
  q.greaterThanOrEqualTo('createdAt', since);
  q.limit(5000);
  const rows = await q.find({ useMasterKey: true });

  const requiresReference = new Set([
    'trade_buy',
    'trade_sell',
    'trading_fees',
    'investment_activate',
    'investment_return',
    'commission_debit',
    'commission_credit',
    'withholding_tax_debit',
    'solidarity_surcharge_debit',
    'church_tax_debit',
    'residual_return',
  ]);

  let checked = 0;
  let missingId = 0;
  let missingNumber = 0;
  const samples = [];
  for (const row of rows) {
    const entryType = String(row.get('entryType') || '');
    if (!requiresReference.has(entryType)) continue;
    checked += 1;
    const referenceDocumentId = String(row.get('referenceDocumentId') || '').trim();
    const referenceDocumentNumber = String(row.get('referenceDocumentNumber') || '').trim();
    if (!referenceDocumentId || !referenceDocumentNumber) {
      if (!referenceDocumentId) missingId += 1;
      if (!referenceDocumentNumber) missingNumber += 1;
      if (samples.length < 20) {
        samples.push({
          id: row.id,
          entryType,
          tradeId: String(row.get('tradeId') || ''),
          investmentId: String(row.get('investmentId') || ''),
          userId: String(row.get('userId') || ''),
          missingReferenceDocumentId: !referenceDocumentId,
          missingReferenceDocumentNumber: !referenceDocumentNumber,
        });
      }
    }
  }

  return {
    since: since.toISOString(),
    checkedRows: checked,
    missingReferenceDocumentId: missingId,
    missingReferenceDocumentNumber: missingNumber,
    missingSamples: samples,
  };
}

async function handleRunFinanceConsistencySmoke(request) {
  const userFilter = String(request.params?.userFilter || 'eweber');
  const ledgerSampleLimit = Number(request.params?.ledgerSampleLimit || 500);
  const sinceHours = Number(request.params?.sinceHours || 168);

  const mirrorBasis = await Parse.Cloud.run('getMirrorBasisDriftStatus', {}, {
    useMasterKey: true,
  }).catch((err) => ({ overall: 'down', error: err?.message || String(err) }));

  const settlementConsistency = await Parse.Cloud.run('getTradeSettlementConsistencyStatus', {
    limit: Number(request.params?.settlementLimit || 100),
  }, {
    useMasterKey: true,
  }).catch((err) => ({ overall: 'down', error: err?.message || String(err) }));

  const ledgerFuzzySmoke = await runLedgerFuzzySmoke({
    userFilter,
    sampleLimit: ledgerSampleLimit,
  });
  const referenceCoverage = await runReferenceDocumentCoverageSmoke({ sinceHours });

  const issues = [];
  if (mirrorBasis?.overall && mirrorBasis.overall !== 'healthy' && mirrorBasis.overall !== 'unknown') {
    issues.push(`mirror_basis_${mirrorBasis.overall}`);
  }
  if (settlementConsistency?.overall && settlementConsistency.overall !== 'healthy') {
    issues.push(`settlement_consistency_${settlementConsistency.overall}`);
  }
  if ((referenceCoverage?.missingReferenceDocumentId || 0) > 0 || (referenceCoverage?.missingReferenceDocumentNumber || 0) > 0) {
    issues.push('missing_reference_document_fields');
  }

  return {
    overall: issues.length === 0 ? 'healthy' : 'degraded',
    checkedAt: new Date().toISOString(),
    issues,
    mirrorBasis,
    settlementConsistency,
    ledgerFuzzySmoke,
    referenceCoverage,
  };
}

module.exports = {
  handleRunFinanceConsistencySmoke,
};
