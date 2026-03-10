'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

/**
 * Create a new FAQ (Admin only)
 */
Parse.Cloud.define('createFAQ', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const {
    faqId,
    question,
    questionDe,
    answer,
    answerDe,
    categoryId,
    categoryIds,
    sortOrder = 100,
    isPublished = true,
    isPublic = true,
    isUserVisible = true,
    source = 'help_center',
    contexts,
  } = request.params;

  if (!question || !answer) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'question and answer are required');
  }

  // At least one category association is required: either single categoryId or non-empty categoryIds array
  const normalizedCategoryIds = Array.isArray(categoryIds)
    ? categoryIds.filter((id) => typeof id === 'string' && id.trim().length > 0)
    : [];

  if (!categoryId && normalizedCategoryIds.length === 0) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      'At least one categoryId is required (single categoryId or non-empty categoryIds array)'
    );
  }

  if (faqId) {
    const existingQuery = new Parse.Query('FAQ');
    existingQuery.equalTo('faqId', faqId);
    const existing = await existingQuery.first({ useMasterKey: true });
    if (existing) {
      throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'FAQ ID already exists');
    }
  }

  const FAQ = Parse.Object.extend('FAQ');
  const faq = new FAQ();

  faq.set('faqId', faqId || `faq-${Date.now()}`);
  faq.set('question', question);
  if (questionDe) faq.set('questionDe', questionDe);
  faq.set('answer', answer);
  if (answerDe) faq.set('answerDe', answerDe);
  // Multi-category support:
  // - Persist full categoryIds array for new behavior
  // - Keep legacy categoryId (single) in sync using the first entry for backwards compatibility
  if (normalizedCategoryIds.length > 0) {
    faq.set('categoryIds', normalizedCategoryIds);
    faq.set('categoryId', categoryId || normalizedCategoryIds[0]);
  } else {
    faq.set('categoryId', categoryId);
  }
  faq.set('sortOrder', sortOrder);
  faq.set('isPublished', isPublished);
  faq.set('isArchived', false);
  faq.set('isPublic', isPublic);
  faq.set('isUserVisible', isUserVisible);
  // Multi-context support:
  // - Persist full contexts array if provided
  // - Keep legacy single source in sync using the first context (or provided source)
  const normalizedContexts = Array.isArray(contexts)
    ? contexts.filter((ctx) => typeof ctx === 'string' && ctx.trim().length > 0)
    : [];

  if (normalizedContexts.length > 0) {
    faq.set('contexts', normalizedContexts);
    faq.set('source', source || normalizedContexts[0]);
  } else {
    faq.set('source', source);
  }

  await faq.save(null, { useMasterKey: true });

  console.log(`[FAQ] Created FAQ: ${faq.get('faqId')} by ${request.user.id}`);

  return faq.toJSON();
});

/**
 * Update an existing FAQ (Admin only)
 */
Parse.Cloud.define('updateFAQ', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { objectId, ...updates } = request.params;

  if (!objectId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId is required');
  }

  const FAQ = Parse.Object.extend('FAQ');
  const query = new Parse.Query(FAQ);
  const faq = await query.get(objectId, { useMasterKey: true });

  const allowedFields = [
    'question',
    'questionDe',
    'answer',
    'answerDe',
    'categoryId',
    'categoryIds',
    'sortOrder',
    'isPublished',
    'isArchived',
    'isPublic',
    'isUserVisible',
    'source',
    'contexts',
  ];

  for (const field of allowedFields) {
    if (updates.hasOwnProperty(field)) {
      faq.set(field, updates[field]);
    }
  }

  // Keep legacy single fields in sync when arrays are updated
  if (updates.hasOwnProperty('categoryIds') && Array.isArray(updates.categoryIds)) {
    const normalizedCategoryIds = updates.categoryIds.filter(
      (id) => typeof id === 'string' && id.trim().length > 0
    );
    faq.set('categoryIds', normalizedCategoryIds);
    if (normalizedCategoryIds.length > 0) {
      faq.set('categoryId', normalizedCategoryIds[0]);
    }
  }

  if (updates.hasOwnProperty('contexts') && Array.isArray(updates.contexts)) {
    const normalizedContexts = updates.contexts.filter(
      (ctx) => typeof ctx === 'string' && ctx.trim().length > 0
    );
    faq.set('contexts', normalizedContexts);
    if (normalizedContexts.length > 0 && !updates.source) {
      faq.set('source', normalizedContexts[0]);
    }
  }

  await faq.save(null, { useMasterKey: true });

  console.log(`[FAQ] Updated FAQ: ${objectId} by ${request.user.id}`);

  return faq.toJSON();
});

/**
 * Delete an FAQ (Admin only - soft delete)
 */
Parse.Cloud.define('deleteFAQ', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { objectId } = request.params;

  if (!objectId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId is required');
  }

  const FAQ = Parse.Object.extend('FAQ');
  const query = new Parse.Query(FAQ);
  const faq = await query.get(objectId, { useMasterKey: true });

  faq.set('isArchived', true);
  faq.set('isPublished', false);

  await faq.save(null, { useMasterKey: true });

  console.log(`[FAQ] Deleted FAQ: ${objectId} by ${request.user.id}`);

  return { success: true, message: 'FAQ deleted' };
});

/**
 * Create a new FAQCategory (Admin only)
 *
 * This is a lightweight helper to allow creating new categories directly from the Admin/CSR portal.
 * It focuses on the core fields used by the app and help center.
 */
Parse.Cloud.define('createFAQCategory', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const {
    slug,
    title,
    displayName,
    icon,
    sortOrder = 100,
    isActive = true,
    showOnLanding = false,
    showInHelpCenter = true,
    showInCSR = true,
  } = request.params;

  if (!slug) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'slug is required');
  }

  const normalizedSlug = String(slug).trim().toLowerCase();
  if (!normalizedSlug) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'slug must not be empty');
  }

  // Enforce unique slug
  const existingQuery = new Parse.Query('FAQCategory');
  existingQuery.equalTo('slug', normalizedSlug);
  const existing = await existingQuery.first({ useMasterKey: true });
  if (existing) {
    throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, `FAQCategory with slug "${normalizedSlug}" already exists`);
  }

  const FAQCategory = Parse.Object.extend('FAQCategory');
  const category = new FAQCategory();

  category.set('slug', normalizedSlug);
  if (title) category.set('title', title);
  if (displayName) category.set('displayName', displayName);
  if (icon) category.set('icon', icon);
  category.set('sortOrder', sortOrder);
  category.set('isActive', isActive);
  category.set('showOnLanding', showOnLanding);
  category.set('showInHelpCenter', showInHelpCenter);
  category.set('showInCSR', showInCSR);

  await category.save(null, { useMasterKey: true });

  console.log(`[FAQ] Created FAQCategory: ${normalizedSlug} (${category.id}) by ${request.user.id}`);

  return category.toJSON();
});
