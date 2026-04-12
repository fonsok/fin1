'use strict';

const { requirePermission, requireAdminRole } = require('../../../utils/permissions');

/**
 * One-time migration: copy legacy English (questionDe/answerDe) → questionEn/answerEn, then unset legacy keys.
 * Call with master key (ops) or logged-in admin with manageTemplates.
 */
Parse.Cloud.define('migrateFAQEnglishFields', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');
  }

  const dryRun = request.params?.dryRun === true;
  const FAQ = Parse.Object.extend('FAQ');
  const q = new Parse.Query(FAQ);
  q.limit(1000);
  const all = await q.find({ useMasterKey: true });

  let copied = 0;
  let legacyStripped = 0;

  for (const faq of all) {
    const legacyQ = faq.get('questionDe');
    const legacyA = faq.get('answerDe');
    const hasLegacy =
      (legacyQ && String(legacyQ).trim()) || (legacyA && String(legacyA).trim());
    if (!hasLegacy) continue;

    const curQEn = faq.get('questionEn');
    const curAEn = faq.get('answerEn');
    const needQ = !(curQEn && String(curQEn).trim()) && legacyQ && String(legacyQ).trim();
    const needA = !(curAEn && String(curAEn).trim()) && legacyA && String(legacyA).trim();

    if (needQ || needA) {
      if (!dryRun) {
        if (needQ) faq.set('questionEn', String(legacyQ).trim());
        if (needA) faq.set('answerEn', String(legacyA).trim());
        faq.unset('questionDe');
        faq.unset('answerDe');
        await faq.save(null, { useMasterKey: true });
      }
      copied += 1;
      continue;
    }

    if (!dryRun) {
      faq.unset('questionDe');
      faq.unset('answerDe');
      await faq.save(null, { useMasterKey: true });
    }
    legacyStripped += 1;
  }

  return {
    success: true,
    dryRun,
    copiedFromLegacy: copied,
    strippedLegacyOnly: legacyStripped,
    examined: all.length,
  };
});
