'use strict';

const { requirePermission, requireAdminRole } = require('../../../utils/permissions');

function normalizeBoolean(value, fallback = false) {
  return typeof value === 'boolean' ? value : fallback;
}

function normalizeString(value, fallback = '') {
  return typeof value === 'string' ? value : fallback;
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((item) => typeof item === 'string' && item.trim().length > 0);
}

function resolveImportedCategoryIds(rawRefs, backupCategoryObjectIdToSlug, categorySlugToId) {
  const resolved = [];
  for (const ref of rawRefs) {
    if (typeof ref !== 'string' || ref.trim().length === 0) continue;
    const slugFromObjectId = backupCategoryObjectIdToSlug.get(ref);
    const slug = slugFromObjectId || ref;
    const categoryId = categorySlugToId.get(slug);
    if (categoryId) resolved.push(categoryId);
  }
  return [...new Set(resolved)];
}

/**
 * Export all FAQ categories and FAQ items as JSON backup (admin only).
 */
Parse.Cloud.define('exportFAQBackup', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const [categories, faqs] = await Promise.all([
    new Parse.Query('FAQCategory').limit(500).find({ useMasterKey: true }),
    new Parse.Query('FAQ').limit(1000).find({ useMasterKey: true }),
  ]);

  return {
    exportedAt: new Date().toISOString(),
    version: '1.1',
    note:
      'Backup Hilfe & Anleitung (FAQs). Englisch: kanonisch questionEn/answerEn. Legacy questionDe/answerDe nur in alten Datensätzen bis migrateFAQEnglishFields ausgeführt wurde.',
    categories: categories.map((c) => c.toJSON()),
    faqs: faqs.map((f) => f.toJSON()),
  };
});

Parse.Cloud.define('importFAQBackup', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const dryRun = request.params?.dryRun === true;
  let backup = request.params?.backup;
  if (!backup && typeof request.params?.backupJson === 'string') {
    try {
      backup = JSON.parse(request.params.backupJson);
    } catch (e) {
      throw new Parse.Error(Parse.Error.INVALID_JSON, 'backupJson is not valid JSON');
    }
  }

  if (!backup || typeof backup !== 'object') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup (object) or backupJson (string) is required');
  }

  const categories = Array.isArray(backup.categories) ? backup.categories : null;
  const faqs = Array.isArray(backup.faqs) ? backup.faqs : null;
  if (!categories || !faqs) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup.categories and backup.faqs must be arrays');
  }

  const warnings = [];
  const normalizedCategories = categories.map((category, idx) => {
    const slug = normalizeString(category?.slug).trim().toLowerCase();
    if (!slug) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Category slug required at categories[${idx}]`);
    }
    return {
      slug,
      title: normalizeString(category?.title),
      displayName: normalizeString(category?.displayName),
      icon: normalizeString(category?.icon),
      sortOrder: Number.isFinite(category?.sortOrder) ? Number(category.sortOrder) : 100,
      isActive: normalizeBoolean(category?.isActive, true),
      showOnLanding: normalizeBoolean(category?.showOnLanding, false),
      showInHelpCenter: normalizeBoolean(category?.showInHelpCenter, true),
      showInCSR: normalizeBoolean(category?.showInCSR, true),
      sourceObjectId: normalizeString(category?.objectId),
    };
  });

  const backupCategoryObjectIdToSlug = new Map(
    normalizedCategories
      .filter((category) => category.sourceObjectId.length > 0)
      .map((category) => [category.sourceObjectId, category.slug]),
  );

  const normalizedFaqs = faqs.map((faq, idx) => {
    const faqId = normalizeString(faq?.faqId).trim();
    const question = normalizeString(faq?.question).trim();
    const answer = normalizeString(faq?.answer).trim();
    if (!faqId || !question || !answer) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `faqId, question, answer required at faqs[${idx}]`);
    }
    const rawCategoryRefs = [];
    if (Array.isArray(faq?.categoryIds)) rawCategoryRefs.push(...faq.categoryIds);
    if (faq?.categoryId) rawCategoryRefs.push(faq.categoryId);
    const categoryRefs = normalizeStringArray(rawCategoryRefs);
    if (categoryRefs.length === 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `categoryId/categoryIds required at faqs[${idx}]`);
    }
    return {
      faqId,
      question,
      answer,
      questionEn: faq?.questionEn,
      answerEn: faq?.answerEn,
      categoryRefs,
      sortOrder: Number.isFinite(faq?.sortOrder) ? Number(faq.sortOrder) : 100,
      isPublished: normalizeBoolean(faq?.isPublished, true),
      isArchived: normalizeBoolean(faq?.isArchived, false),
      isPublic: normalizeBoolean(faq?.isPublic, false),
      isUserVisible: normalizeBoolean(faq?.isUserVisible, true),
      source: normalizeString(faq?.source, 'help_center'),
      contexts: normalizeStringArray(faq?.contexts),
    };
  });

  const existingCategoryQuery = new Parse.Query('FAQCategory');
  existingCategoryQuery.limit(1000);
  const existingCategories = await existingCategoryQuery.find({ useMasterKey: true });
  const categoryBySlug = new Map(
    existingCategories.map((category) => [String(category.get('slug') || '').toLowerCase(), category]),
  );
  const categorySlugToId = new Map(
    existingCategories.map((category) => [String(category.get('slug') || '').toLowerCase(), category.id]),
  );

  let categoriesCreated = 0;
  let categoriesUpdated = 0;

  for (const category of normalizedCategories) {
    const existing = categoryBySlug.get(category.slug);
    if (!existing) {
      categoriesCreated += 1;
      if (!dryRun) {
        const FAQCategory = Parse.Object.extend('FAQCategory');
        const created = new FAQCategory();
        created.set('slug', category.slug);
        if (category.title) created.set('title', category.title);
        if (category.displayName) created.set('displayName', category.displayName);
        if (category.icon) created.set('icon', category.icon);
        created.set('sortOrder', category.sortOrder);
        created.set('isActive', category.isActive);
        created.set('showOnLanding', category.showOnLanding);
        created.set('showInHelpCenter', category.showInHelpCenter);
        created.set('showInCSR', category.showInCSR);
        await created.save(null, { useMasterKey: true });
        categoryBySlug.set(category.slug, created);
        categorySlugToId.set(category.slug, created.id);
      } else {
        categorySlugToId.set(category.slug, `dryrun-${category.slug}`);
      }
      continue;
    }

    categoriesUpdated += 1;
    if (!dryRun) {
      if (category.title) existing.set('title', category.title);
      if (category.displayName) existing.set('displayName', category.displayName);
      if (category.icon) existing.set('icon', category.icon);
      existing.set('sortOrder', category.sortOrder);
      existing.set('isActive', category.isActive);
      existing.set('showOnLanding', category.showOnLanding);
      existing.set('showInHelpCenter', category.showInHelpCenter);
      existing.set('showInCSR', category.showInCSR);
      await existing.save(null, { useMasterKey: true });
    }
  }

  const existingFaqQuery = new Parse.Query('FAQ');
  existingFaqQuery.limit(2000);
  const existingFaqs = await existingFaqQuery.find({ useMasterKey: true });
  const faqByFaqId = new Map(
    existingFaqs.map((faq) => [String(faq.get('faqId') || ''), faq]).filter(([faqId]) => faqId.length > 0),
  );

  let faqsCreated = 0;
  let faqsUpdated = 0;
  let skippedFaqs = 0;

  for (const faq of normalizedFaqs) {
    const resolvedCategoryIds = resolveImportedCategoryIds(
      faq.categoryRefs,
      backupCategoryObjectIdToSlug,
      categorySlugToId,
    );

    if (resolvedCategoryIds.length === 0) {
      skippedFaqs += 1;
      warnings.push(`FAQ ${faq.faqId} skipped: no resolvable category reference`);
      continue;
    }

    const existing = faqByFaqId.get(faq.faqId);
    if (!existing) {
      faqsCreated += 1;
      if (!dryRun) {
        const FAQ = Parse.Object.extend('FAQ');
        const created = new FAQ();
        created.set('faqId', faq.faqId);
        created.set('question', faq.question);
        created.set('answer', faq.answer);
        if (typeof faq.questionEn === 'string') created.set('questionEn', faq.questionEn);
        if (typeof faq.answerEn === 'string') created.set('answerEn', faq.answerEn);
        created.set('categoryIds', resolvedCategoryIds);
        created.set('categoryId', resolvedCategoryIds[0]);
        created.set('sortOrder', faq.sortOrder);
        created.set('isPublished', faq.isPublished);
        created.set('isArchived', faq.isArchived);
        created.set('isPublic', faq.isPublic);
        created.set('isUserVisible', faq.isUserVisible);
        created.set('source', faq.source);
        if (faq.contexts.length > 0) created.set('contexts', faq.contexts);
        await created.save(null, { useMasterKey: true });
      }
      continue;
    }

    faqsUpdated += 1;
    if (!dryRun) {
      existing.set('question', faq.question);
      existing.set('answer', faq.answer);
      if (typeof faq.questionEn === 'string') existing.set('questionEn', faq.questionEn);
      if (typeof faq.answerEn === 'string') existing.set('answerEn', faq.answerEn);
      existing.set('categoryIds', resolvedCategoryIds);
      existing.set('categoryId', resolvedCategoryIds[0]);
      existing.set('sortOrder', faq.sortOrder);
      existing.set('isPublished', faq.isPublished);
      existing.set('isArchived', faq.isArchived);
      existing.set('isPublic', faq.isPublic);
      existing.set('isUserVisible', faq.isUserVisible);
      existing.set('source', faq.source);
      if (faq.contexts.length > 0) {
        existing.set('contexts', faq.contexts);
      } else {
        existing.unset('contexts');
      }
      await existing.save(null, { useMasterKey: true });
    }
  }

  return {
    success: true,
    dryRun,
    counts: {
      categoriesInput: normalizedCategories.length,
      categoriesCreated,
      categoriesUpdated,
      faqsInput: normalizedFaqs.length,
      faqsCreated,
      faqsUpdated,
      faqsSkipped: skippedFaqs,
    },
    warnings,
  };
});
