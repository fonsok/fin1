'use strict';

const { logPermissionCheck } = require('../../utils/permissions');

function scoreScopeMatch(stmt, doc) {
  let score = 0;
  const stmtUser = String(stmt.get('userId') || '').trim();
  const stmtTrade = String(stmt.get('tradeId') || '').trim();
  const stmtInvestment = String(stmt.get('investmentId') || '').trim();
  const docUser = String(doc.get('userId') || '').trim();
  const docTrade = String(doc.get('tradeId') || '').trim();
  const docInvestment = String(doc.get('investmentId') || '').trim();

  if (stmtUser && docUser && stmtUser === docUser) score += 4;
  if (stmtTrade && docTrade && stmtTrade === docTrade) score += 2;
  if (stmtInvestment && docInvestment && stmtInvestment === docInvestment) score += 2;

  return score;
}

function resolveByDocumentNumber(stmt, docsByNumber) {
  const referenceDocumentNumber = String(stmt.get('referenceDocumentNumber') || '').trim();
  if (!referenceDocumentNumber) return { doc: null, reason: 'missing_document_number' };
  const docs = docsByNumber.get(referenceDocumentNumber) || [];
  if (!docs.length) return { doc: null, reason: 'document_not_found_for_number' };
  if (docs.length === 1) return { doc: docs[0], reason: null };

  const ranked = docs
    .map((doc) => ({ doc, score: scoreScopeMatch(stmt, doc) }))
    .sort((a, b) => b.score - a.score);

  if (ranked[0].score <= 0) return { doc: null, reason: 'ambiguous_number_no_scope_match' };
  if (ranked.length > 1 && ranked[0].score === ranked[1].score) {
    return { doc: null, reason: 'ambiguous_number_tied_scope_match' };
  }
  return { doc: ranked[0].doc, reason: null };
}

async function handleReconcileAccountStatementDocumentReferences(request) {
  const dryRun = request.params?.dryRun !== false;
  const requestedLimit = Number(request.params?.limit || 10000);
  const limit = Math.min(20000, Math.max(1, requestedLimit));

  const stmtQuery = new Parse.Query('AccountStatement');
  stmtQuery.equalTo('source', 'backend');
  stmtQuery.descending('createdAt');
  stmtQuery.limit(limit);
  const statements = await stmtQuery.find({ useMasterKey: true });

  const needsIdOnly = [];
  const needsNumberOnly = [];
  const missingBoth = [];
  const healthy = [];

  const missingNumberByDocId = new Set();
  const missingIdByDocNumber = new Set();
  for (const row of statements) {
    const referenceDocumentId = String(row.get('referenceDocumentId') || '').trim();
    const referenceDocumentNumber = String(row.get('referenceDocumentNumber') || '').trim();
    if (referenceDocumentId && referenceDocumentNumber) {
      healthy.push(row);
      continue;
    }
    if (referenceDocumentId && !referenceDocumentNumber) {
      needsNumberOnly.push(row);
      missingNumberByDocId.add(referenceDocumentId);
      continue;
    }
    if (!referenceDocumentId && referenceDocumentNumber) {
      needsIdOnly.push(row);
      missingIdByDocNumber.add(referenceDocumentNumber);
      continue;
    }
    missingBoth.push(row);
  }

  const docsById = new Map();
  if (missingNumberByDocId.size > 0) {
    const q = new Parse.Query('Document');
    q.containedIn('objectId', Array.from(missingNumberByDocId));
    q.limit(Math.max(1000, missingNumberByDocId.size));
    const docs = await q.find({ useMasterKey: true });
    for (const doc of docs) docsById.set(doc.id, doc);
  }

  const docsByNumber = new Map();
  if (missingIdByDocNumber.size > 0) {
    const q = new Parse.Query('Document');
    q.containedIn('accountingDocumentNumber', Array.from(missingIdByDocNumber));
    q.limit(Math.max(1000, missingIdByDocNumber.size * 4));
    const docs = await q.find({ useMasterKey: true });
    for (const doc of docs) {
      const number = String(doc.get('accountingDocumentNumber') || '').trim();
      if (!number) continue;
      if (!docsByNumber.has(number)) docsByNumber.set(number, []);
      docsByNumber.get(number).push(doc);
    }
  }

  const updates = [];
  const unresolved = [];

  for (const stmt of needsNumberOnly) {
    const referenceDocumentId = String(stmt.get('referenceDocumentId') || '').trim();
    const doc = docsById.get(referenceDocumentId);
    const number = String(doc?.get('accountingDocumentNumber') || '').trim();
    if (doc && number) {
      updates.push({
        stmt,
        setId: referenceDocumentId,
        setNumber: number,
        reason: 'filled_number_from_document_id',
      });
    } else {
      unresolved.push({
        statementId: stmt.id,
        reason: doc ? 'document_has_no_accounting_number' : 'document_id_not_found',
      });
    }
  }

  for (const stmt of needsIdOnly) {
    const result = resolveByDocumentNumber(stmt, docsByNumber);
    if (result.doc) {
      updates.push({
        stmt,
        setId: result.doc.id,
        setNumber: String(result.doc.get('accountingDocumentNumber') || '').trim(),
        reason: 'filled_id_from_document_number',
      });
    } else {
      unresolved.push({
        statementId: stmt.id,
        reason: result.reason || 'unresolved_number_lookup',
      });
    }
  }

  for (const stmt of missingBoth) {
    unresolved.push({
      statementId: stmt.id,
      reason: 'both_reference_fields_missing',
    });
  }

  if (!dryRun) {
    for (const u of updates) {
      u.stmt.set('referenceDocumentId', u.setId);
      u.stmt.set('referenceDocumentNumber', u.setNumber);
    }
    if (updates.length) {
      await Parse.Object.saveAll(updates.map((u) => u.stmt), { useMasterKey: true });
    }
  }

  if (!request.master) {
    await logPermissionCheck(
      request,
      'reconcileAccountStatementDocumentReferences',
      'AccountStatement',
      dryRun ? 'dryRun' : 'execute',
    );
  }

  return {
    success: true,
    dryRun,
    scanned: statements.length,
    healthy: healthy.length,
    missingOnlyDocumentId: needsIdOnly.length,
    missingOnlyDocumentNumber: needsNumberOnly.length,
    missingBoth: missingBoth.length,
    backfillCandidates: updates.length,
    backfilled: dryRun ? 0 : updates.length,
    unresolvedCount: unresolved.length,
    unresolvedSamples: unresolved.slice(0, 50),
    backfillSamples: updates.slice(0, 50).map((u) => ({
      statementId: u.stmt.id,
      referenceDocumentId: u.setId,
      referenceDocumentNumber: u.setNumber,
      reason: u.reason,
    })),
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleReconcileAccountStatementDocumentReferences,
};
