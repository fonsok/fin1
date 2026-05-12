'use strict';

const { logPermissionCheck } = require('../../utils/permissions');

async function handleCleanupLegacyDocumentsAllUsers(request) {
  const dryRun = request.params?.dryRun !== false;
  const MAX_DELETE = 2000;
  const legacyPrefixes = ['IAR-', 'IRR-', 'IFR-'];
  const legacyTypeCandidates = ['investorCollectionBill', 'traderCollectionBill', 'traderCreditNote', 'invoice'];

  const allDocs = await new Parse.Query('Document')
    .descending('createdAt')
    .limit(10000)
    .find({ useMasterKey: true });

  const backendDocs = allDocs.filter((d) => String(d.get('source') || '') === 'backend');
  const nonBackendDocs = allDocs.filter((d) => String(d.get('source') || '') !== 'backend');

  const backendByKey = new Set();
  for (const d of backendDocs) {
    const userId = String(d.get('userId') || '').trim();
    const type = String(d.get('type') || '').trim();
    const tradeId = String(d.get('tradeId') || '').trim();
    const investmentId = String(d.get('investmentId') || '').trim();
    if (userId && type && tradeId) backendByKey.add(`${userId}|${type}|trade|${tradeId}`);
    if (userId && type && investmentId) backendByKey.add(`${userId}|${type}|investment|${investmentId}`);
  }

  const toNormalize = [];
  for (const d of backendDocs) {
    const type = String(d.get('type') || '');
    const accNo = String(d.get('accountingDocumentNumber') || '');
    if (type === 'investorCollectionBill' && legacyPrefixes.some((p) => accNo.startsWith(p))) {
      toNormalize.push(d);
    }
  }

  const toDelete = [];
  for (const d of nonBackendDocs) {
    const type = String(d.get('type') || '');
    if (!legacyTypeCandidates.includes(type)) continue;

    const userId = String(d.get('userId') || '').trim();
    const tradeId = String(d.get('tradeId') || '').trim();
    const investmentId = String(d.get('investmentId') || '').trim();
    const fileURL = String(d.get('fileURL') || '').trim();
    const documentNumber = String(d.get('documentNumber') || '').trim();
    const name = String(d.get('name') || '').trim();

    const duplicatesBackendTrade = userId && tradeId && backendByKey.has(`${userId}|${type}|trade|${tradeId}`);
    const duplicatesBackendInvestment = userId && investmentId && backendByKey.has(`${userId}|${type}|investment|${investmentId}`);
    const obviousLegacyPattern =
      fileURL.startsWith('investment://')
      || fileURL.startsWith('statement://')
      || (fileURL.startsWith('invoice://') && documentNumber.startsWith('ABCDEFG-'))
      || documentNumber.startsWith('ABCDEFG-')
      || name.startsWith('InvestorCollectionBill_');

    if (duplicatesBackendTrade || duplicatesBackendInvestment || obviousLegacyPattern) {
      toDelete.push(d);
    }
  }

  if (toDelete.length > MAX_DELETE) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, `cleanup aborted: candidate deletes ${toDelete.length} > MAX_DELETE ${MAX_DELETE}`);
  }

  if (!dryRun) {
    for (const d of toNormalize) {
      d.set('type', 'financial');
    }
    if (toNormalize.length) {
      await Parse.Object.saveAll(toNormalize, { useMasterKey: true });
    }
    if (toDelete.length) {
      await Parse.Object.destroyAll(toDelete, { useMasterKey: true });
    }
  }

  if (!request.master) {
    await logPermissionCheck(request, 'cleanupLegacyDocumentsAllUsers', 'Document', dryRun ? 'dryRun' : 'execute');
  }

  return {
    success: true,
    dryRun,
    totalDocumentsScanned: allDocs.length,
    backendDocuments: backendDocs.length,
    nonBackendDocuments: nonBackendDocs.length,
    normalizeCandidates: toNormalize.length,
    deleteCandidates: toDelete.length,
    normalized: dryRun ? 0 : toNormalize.length,
    deleted: dryRun ? 0 : toDelete.length,
    sampleNormalize: toNormalize.slice(0, 20).map((d) => ({
      id: d.id,
      accountingDocumentNumber: d.get('accountingDocumentNumber') || null,
      typeBefore: d.get('type') || null,
    })),
    sampleDelete: toDelete.slice(0, 40).map((d) => ({
      id: d.id,
      userId: d.get('userId') || null,
      type: d.get('type') || null,
      tradeId: d.get('tradeId') || null,
      investmentId: d.get('investmentId') || null,
      source: d.get('source') || null,
      fileURL: d.get('fileURL') || null,
      documentNumber: d.get('documentNumber') || null,
      name: d.get('name') || null,
    })),
    ranAt: new Date().toISOString(),
  };
}

module.exports = {
  handleCleanupLegacyDocumentsAllUsers,
};
