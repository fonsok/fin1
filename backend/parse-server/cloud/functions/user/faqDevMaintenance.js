'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

const DELETE_CTX_FAQ = { allowFaqHardDelete: true };
const DELETE_CTX_CATEGORY = { allowFaqCategoryHardDelete: true };

function copyFaqPayloadFromSource(src) {
  const fields = [
    'question',
    'answer',
    'questionEn',
    'answerEn',
    'questionDe',
    'answerDe',
    'categoryId',
    'categoryIds',
    'sortOrder',
    'isPublished',
    'isPublic',
    'isUserVisible',
    'source',
    'contexts',
    'targetRoles',
  ];
  const payload = {};
  for (const key of fields) {
    const v = src.get(key);
    if (v !== undefined) payload[key] = v;
  }
  payload.isArchived = false;
  return payload;
}

function applyPayloadToFaq(dest, payload, faqIdValue) {
  dest.set('faqId', faqIdValue);
  for (const [key, val] of Object.entries(payload)) {
    if (key === 'faqId') continue;
    if (val === undefined) continue;
    dest.set(key, val);
  }
}

/**
 * DEV: Re-baseline published FAQs (clone active → new rows, hard delete originals + all inactive rows).
 * Same workflow idea as devResetLegalDocumentsBaseline (safety JSON + dry-run + gated hard delete).
 */
Parse.Cloud.define('devResetFAQsBaseline', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const allowHardDelete = String(process.env.ALLOW_FAQ_HARD_DELETE || '').toLowerCase() === 'true';
  if (!allowHardDelete) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'FAQ hard delete is disabled. Set ALLOW_FAQ_HARD_DELETE=true on the Parse Server host.',
    );
  }

  const dryRun = !!request.params.dryRun;
  const deleteInactiveCategories = request.params.deleteInactiveCategories === true;

  const [categoryRows, faqRows] = await Promise.all([
    new Parse.Query('FAQCategory').limit(500).find({ useMasterKey: true }),
    new Parse.Query('FAQ').limit(2500).find({ useMasterKey: true }),
  ]);

  const safetyBackup = {
    exportedAt: new Date().toISOString(),
    version: '1.0',
    note: 'Safety backup before devResetFAQsBaseline (FAQ + FAQCategory).',
    categories: categoryRows.map((c) => c.toJSON()),
    faqs: faqRows.map((f) => f.toJSON()),
  };

  const activeDocs = faqRows.filter((f) => f.get('isPublished') === true && f.get('isArchived') !== true);
  if (activeDocs.length === 0) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'No active FAQs found (isPublished=true, isArchived!=true)');
  }

  const activeIdSet = new Set(activeDocs.map((d) => d.id));
  const inactiveFaqDocs = faqRows.filter((f) => !activeIdSet.has(f.id));

  const inactiveCategoryDocs = deleteInactiveCategories
    ? categoryRows.filter((c) => c.get('isActive') === false)
    : [];

  if (dryRun) {
    return {
      dryRun: true,
      deleteInactiveCategories: !!deleteInactiveCategories,
      activeFound: activeDocs.length,
      inactiveFaqsPlanned: inactiveFaqDocs.length,
      clonesPlanned: activeDocs.length,
      inactiveCategoriesPlanned: inactiveCategoryDocs.length,
      safetyBackup,
    };
  }

  const FAQ = Parse.Object.extend('FAQ');
  const renamePairs = [];

  for (const src of activeDocs) {
    const originalFaqId = String(src.get('faqId') || '').trim();
    if (!originalFaqId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `FAQ ${src.id} has empty faqId`);
    }
    const tempFaqId = `${originalFaqId}.__devBaseline.${src.id}`;
    const payload = copyFaqPayloadFromSource(src);
    const clone = new FAQ();
    applyPayloadToFaq(clone, payload, tempFaqId);
    renamePairs.push({ clone, originalFaqId });
  }

  await Parse.Object.saveAll(
    renamePairs.map((p) => p.clone),
    { useMasterKey: true },
  );

  for (const src of activeDocs) {
    await src.destroy({ useMasterKey: true, context: DELETE_CTX_FAQ });
  }

  for (const { clone, originalFaqId } of renamePairs) {
    clone.set('faqId', originalFaqId);
  }
  await Parse.Object.saveAll(
    renamePairs.map((p) => p.clone),
    { useMasterKey: true },
  );

  let deletedInactiveFaqs = 0;
  for (const d of inactiveFaqDocs) {
    await d.destroy({ useMasterKey: true, context: DELETE_CTX_FAQ });
    deletedInactiveFaqs += 1;
  }

  let deletedInactiveCategories = 0;
  for (const c of inactiveCategoryDocs) {
    await c.destroy({ useMasterKey: true, context: DELETE_CTX_CATEGORY });
    deletedInactiveCategories += 1;
  }

  return {
    dryRun: false,
    deleteInactiveCategories: !!deleteInactiveCategories,
    activeFound: activeDocs.length,
    clonesCreated: renamePairs.length,
    deletedInactiveFaqs,
    deletedInactiveCategories,
    safetyBackup,
  };
});
