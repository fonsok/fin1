// ============================================================================
// Parse Cloud Functions - CSR Templates
// ============================================================================
//
// Zentrale Verwaltung von Textbausteinen und E-Mail-Vorlagen für CSR.
// Templates werden im Backend gespeichert für:
//   - Zentrale Verwaltung ohne App-Update
//   - Echtzeit-Updates
//   - Analytics (Nutzungsstatistiken)
//   - Admin-Portal Integration
//
// ============================================================================

'use strict';

const { requirePermission, requireAdminRole } = require('../utils/permissions');

// ============================================================================
// RESPONSE TEMPLATES (Textbausteine)
// ============================================================================

/**
 * Get all response templates for a specific CSR role
 * @param {string} role - CSR role (level_1, level_2, fraud_analyst, etc.)
 * @param {string} [category] - Optional category filter
 * @param {string} [language] - Language preference (de, en)
 * @returns {Array} List of templates
 */
Parse.Cloud.define('getResponseTemplates', async (request) => {
  requireAdminRole(request);

  const { role, category, language = 'de', includeInactive = false } = request.params;

  if (!role) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'role is required');
  }

  const Template = Parse.Object.extend('CSRResponseTemplate');
  const query = new Parse.Query(Template);

  // Filter by role
  query.containedIn('availableForRoles', [role]);

  // Filter by category if provided
  if (category) {
    query.equalTo('categoryKey', category);
  }

  // Active only (unless includeInactive)
  if (!includeInactive) {
    query.equalTo('isActive', true);
  }

  // Sort by category, then title
  query.ascending('categoryKey');
  query.addAscending('title');

  const templates = await query.find({ useMasterKey: true });

  return templates.map(t => {
    const data = t.toJSON();

    // Return localized content based on language preference
    if (language === 'de') {
      data.title = data.titleDe || data.title;
      data.body = data.bodyDe || data.body;
      data.subject = data.subjectDe || data.subject;
    }

    return {
      id: data.objectId,
      templateKey: data.templateKey,
      title: data.title,
      category: data.categoryKey,
      subject: data.subject,
      body: data.body,
      isEmail: data.isEmail || false,
      placeholders: data.placeholders || [],
      shortcut: data.shortcut,
      usageCount: data.usageCount || 0,
      isDefault: data.isDefault || false,
      version: data.version || 1,
      updatedAt: data.updatedAt
    };
  });
});

/**
 * Get a single response template by ID or key
 * @param {string} [templateId] - Template ID
 * @param {string} [templateKey] - Template key
 * @returns {Object} Template details
 */
Parse.Cloud.define('getResponseTemplate', async (request) => {
  requireAdminRole(request);

  const { templateId, templateKey } = request.params;

  if (!templateId && !templateKey) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'templateId or templateKey required');
  }

  const Template = Parse.Object.extend('CSRResponseTemplate');
  const query = new Parse.Query(Template);

  let template;
  if (templateId) {
    template = await query.get(templateId, { useMasterKey: true });
  } else {
    query.equalTo('templateKey', templateKey);
    template = await query.first({ useMasterKey: true });
  }

  if (!template) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Template not found');
  }

  return template.toJSON();
});

/**
 * Create a new response template
 * @param {Object} templateData - Template data
 * @returns {Object} Created template
 */
Parse.Cloud.define('createResponseTemplate', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const {
    templateKey,
    title,
    titleDe,
    categoryKey,
    subject,
    subjectDe,
    body,
    bodyDe,
    isEmail = false,
    availableForRoles = ['level_1', 'level_2', 'teamlead'],
    placeholders = [],
    shortcut
  } = request.params;

  if (!title || !body || !categoryKey) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'title, body, and categoryKey are required');
  }

  // Check for duplicate templateKey
  if (templateKey) {
    const existingQuery = new Parse.Query('CSRResponseTemplate');
    existingQuery.equalTo('templateKey', templateKey);
    const existing = await existingQuery.first({ useMasterKey: true });
    if (existing) {
      throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'Template key already exists');
    }
  }

  // Check for duplicate shortcut
  if (shortcut) {
    const shortcutQuery = new Parse.Query('CSRResponseTemplate');
    shortcutQuery.equalTo('shortcut', shortcut);
    const existingShortcut = await shortcutQuery.first({ useMasterKey: true });
    if (existingShortcut) {
      throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'Shortcut already in use');
    }
  }

  const Template = Parse.Object.extend('CSRResponseTemplate');
  const template = new Template();

  template.set('templateKey', templateKey);
  template.set('title', title);
  template.set('titleDe', titleDe || title);
  template.set('categoryKey', categoryKey);
  template.set('subject', subject);
  template.set('subjectDe', subjectDe || subject);
  template.set('body', body);
  template.set('bodyDe', bodyDe || body);
  template.set('isEmail', isEmail);
  template.set('availableForRoles', availableForRoles);
  template.set('placeholders', placeholders);
  template.set('shortcut', shortcut);
  template.set('usageCount', 0);
  template.set('isActive', true);
  template.set('isDefault', false);
  template.set('version', 1);
  template.set('createdBy', request.user.id);

  await template.save(null, { useMasterKey: true });

  console.log(`[Templates] Created response template: ${title} by ${request.user.id}`);

  return template.toJSON();
});

/**
 * Update an existing response template
 * @param {string} templateId - Template ID
 * @param {Object} updates - Fields to update
 * @returns {Object} Updated template
 */
Parse.Cloud.define('updateResponseTemplate', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { templateId, ...updates } = request.params;

  if (!templateId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'templateId is required');
  }

  const Template = Parse.Object.extend('CSRResponseTemplate');
  const query = new Parse.Query(Template);
  const template = await query.get(templateId, { useMasterKey: true });

  // Check if it's a default template (limited editing)
  if (template.get('isDefault') && updates.hasOwnProperty('templateKey')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot change templateKey of default template');
  }

  // Check for duplicate shortcut if changing
  if (updates.shortcut && updates.shortcut !== template.get('shortcut')) {
    const shortcutQuery = new Parse.Query('CSRResponseTemplate');
    shortcutQuery.equalTo('shortcut', updates.shortcut);
    shortcutQuery.notEqualTo('objectId', templateId);
    const existingShortcut = await shortcutQuery.first({ useMasterKey: true });
    if (existingShortcut) {
      throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'Shortcut already in use');
    }
  }

  // Update allowed fields
  const allowedFields = [
    'title', 'titleDe', 'categoryKey', 'subject', 'subjectDe',
    'body', 'bodyDe', 'isEmail', 'availableForRoles', 'placeholders',
    'shortcut', 'isActive'
  ];

  for (const field of allowedFields) {
    if (updates.hasOwnProperty(field)) {
      template.set(field, updates[field]);
    }
  }

  // Increment version
  template.increment('version');
  template.set('updatedBy', request.user.id);

  await template.save(null, { useMasterKey: true });

  console.log(`[Templates] Updated response template: ${templateId} by ${request.user.id}`);

  return template.toJSON();
});

/**
 * Delete a response template (soft delete for non-defaults)
 * @param {string} templateId - Template ID
 * @returns {Object} Deletion result
 */
Parse.Cloud.define('deleteResponseTemplate', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { templateId } = request.params;

  if (!templateId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'templateId is required');
  }

  const Template = Parse.Object.extend('CSRResponseTemplate');
  const query = new Parse.Query(Template);
  const template = await query.get(templateId, { useMasterKey: true });

  // Cannot delete default templates
  if (template.get('isDefault')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot delete default templates');
  }

  // Soft delete
  template.set('isActive', false);
  template.set('deletedBy', request.user.id);
  template.set('deletedAt', new Date());

  await template.save(null, { useMasterKey: true });

  console.log(`[Templates] Deleted response template: ${templateId} by ${request.user.id}`);

  return { success: true, message: 'Template deleted' };
});

/**
 * Record template usage (for analytics)
 * @param {string} templateId - Template ID
 * @param {string} [ticketId] - Related ticket ID
 * @returns {Object} Success confirmation
 */
Parse.Cloud.define('recordTemplateUsage', async (request) => {
  requireAdminRole(request);

  const { templateId, ticketId } = request.params;

  if (!templateId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'templateId is required');
  }

  // Update usage count on template
  const Template = Parse.Object.extend('CSRResponseTemplate');
  const query = new Parse.Query(Template);
  const template = await query.get(templateId, { useMasterKey: true });

  template.increment('usageCount');
  template.set('lastUsedAt', new Date());
  await template.save(null, { useMasterKey: true });

  // Record usage stat
  const UsageStat = Parse.Object.extend('CSRTemplateUsageStat');
  const stat = new UsageStat();
  stat.set('templateId', templateId);
  stat.set('agentId', request.user.id);
  stat.set('ticketId', ticketId);
  stat.set('usedAt', new Date());
  await stat.save(null, { useMasterKey: true });

  return { success: true };
});

// ============================================================================
// EMAIL TEMPLATES
// ============================================================================

/**
 * Get all email templates
 * @param {boolean} [includeInactive] - Include inactive templates
 * @returns {Array} List of email templates
 */
Parse.Cloud.define('getEmailTemplates', async (request) => {
  requireAdminRole(request);

  const { includeInactive = false, language = 'de' } = request.params;

  const Template = Parse.Object.extend('CSREmailTemplate');
  const query = new Parse.Query(Template);

  if (!includeInactive) {
    query.equalTo('isActive', true);
  }

  query.ascending('type');

  const templates = await query.find({ useMasterKey: true });

  return templates.map(t => {
    const data = t.toJSON();

    // Return localized content
    if (language === 'de') {
      data.subject = data.subjectDe || data.subject;
      data.bodyTemplate = data.bodyTemplateDe || data.bodyTemplate;
    }

    return {
      id: data.objectId,
      type: data.type,
      displayName: data.displayName,
      icon: data.icon,
      subject: data.subject,
      bodyTemplate: data.bodyTemplate,
      availablePlaceholders: data.availablePlaceholders || [],
      isActive: data.isActive,
      version: data.version || 1,
      updatedAt: data.updatedAt
    };
  });
});

/**
 * Get email template by type
 * @param {string} type - Template type (ticket_created, ticket_response, etc.)
 * @returns {Object} Email template
 */
Parse.Cloud.define('getEmailTemplate', async (request) => {
  requireAdminRole(request);

  const { type, language = 'de' } = request.params;

  if (!type) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'type is required');
  }

  const Template = Parse.Object.extend('CSREmailTemplate');
  const query = new Parse.Query(Template);
  query.equalTo('type', type);

  const template = await query.first({ useMasterKey: true });

  if (!template) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Email template not found');
  }

  const data = template.toJSON();

  // Return localized content
  if (language === 'de') {
    data.subject = data.subjectDe || data.subject;
    data.bodyTemplate = data.bodyTemplateDe || data.bodyTemplate;
  }

  return data;
});

/**
 * Update an email template
 * @param {string} templateId - Template ID
 * @param {Object} updates - Fields to update
 * @returns {Object} Updated template
 */
Parse.Cloud.define('updateEmailTemplate', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { templateId, ...updates } = request.params;

  if (!templateId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'templateId is required');
  }

  const Template = Parse.Object.extend('CSREmailTemplate');
  const query = new Parse.Query(Template);
  const template = await query.get(templateId, { useMasterKey: true });

  // Update allowed fields
  const allowedFields = [
    'displayName', 'icon', 'subject', 'subjectDe', 'subjectEn',
    'bodyTemplate', 'bodyTemplateDe', 'bodyTemplateEn',
    'availablePlaceholders', 'isActive'
  ];

  for (const field of allowedFields) {
    if (updates.hasOwnProperty(field)) {
      template.set(field, updates[field]);
    }
  }

  // Increment version
  template.increment('version');
  template.set('updatedBy', request.user.id);

  await template.save(null, { useMasterKey: true });

  console.log(`[Templates] Updated email template: ${templateId} by ${request.user.id}`);

  return template.toJSON();
});

/**
 * Render an email template with values
 * @param {string} type - Template type
 * @param {Object} values - Placeholder values
 * @returns {Object} Rendered subject and body
 */
Parse.Cloud.define('renderEmailTemplate', async (request) => {
  requireAdminRole(request);

  const { type, values = {}, language = 'de' } = request.params;

  if (!type) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'type is required');
  }

  const Template = Parse.Object.extend('CSREmailTemplate');
  const query = new Parse.Query(Template);
  query.equalTo('type', type);
  query.equalTo('isActive', true);

  const template = await query.first({ useMasterKey: true });

  if (!template) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Email template not found or inactive');
  }

  // Get localized content
  let subject = language === 'de'
    ? (template.get('subjectDe') || template.get('subject'))
    : template.get('subject');
  let body = language === 'de'
    ? (template.get('bodyTemplateDe') || template.get('bodyTemplate'))
    : template.get('bodyTemplate');

  // Replace placeholders
  for (const [key, value] of Object.entries(values)) {
    const placeholder = `{{${key}}}`;
    subject = subject.replace(new RegExp(placeholder, 'g'), value);
    body = body.replace(new RegExp(placeholder, 'g'), value);
  }

  return {
    subject,
    body,
    type,
    renderedAt: new Date().toISOString()
  };
});

// ============================================================================
// TEMPLATE CATEGORIES
// ============================================================================

/**
 * Get all template categories
 * @returns {Array} List of categories
 */
Parse.Cloud.define('getTemplateCategories', async (request) => {
  requireAdminRole(request);

  const { language = 'de' } = request.params;

  const Category = Parse.Object.extend('CSRTemplateCategory');
  const query = new Parse.Query(Category);
  query.equalTo('isActive', true);
  query.ascending('sortOrder');

  const categories = await query.find({ useMasterKey: true });

  return categories.map(c => {
    const data = c.toJSON();

    return {
      id: data.objectId,
      key: data.key,
      displayName: language === 'de'
        ? (data.displayNameDe || data.displayName)
        : data.displayName,
      icon: data.icon,
      sortOrder: data.sortOrder
    };
  });
});

// ============================================================================
// ANALYTICS
// ============================================================================

/**
 * Get template usage statistics
 * @param {number} [days] - Number of days to include (default: 30)
 * @returns {Object} Usage statistics
 */
Parse.Cloud.define('getTemplateUsageStats', async (request) => {
  requireAdminRole(request);
  // Check permission - CSR users need viewAnalytics permission
  requirePermission(request, 'viewAnalytics');

  const { days = 30 } = request.params;

  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  // Get top templates
  const Template = Parse.Object.extend('CSRResponseTemplate');
  const templateQuery = new Parse.Query(Template);
  templateQuery.equalTo('isActive', true);
  templateQuery.descending('usageCount');
  templateQuery.limit(10);

  const topTemplates = await templateQuery.find({ useMasterKey: true });

  // Get usage stats for period
  const UsageStat = Parse.Object.extend('CSRTemplateUsageStat');
  const statQuery = new Parse.Query(UsageStat);
  statQuery.greaterThanOrEqualTo('usedAt', startDate);

  const stats = await statQuery.find({ useMasterKey: true });

  // Aggregate by agent
  const agentUsage = {};
  stats.forEach(s => {
    const agentId = s.get('agentId');
    if (!agentUsage[agentId]) {
      agentUsage[agentId] = 0;
    }
    agentUsage[agentId]++;
  });

  return {
    period: {
      start: startDate.toISOString(),
      end: new Date().toISOString(),
      days
    },
    totalUsage: stats.length,
    topTemplates: topTemplates.map(t => ({
      id: t.id,
      title: t.get('titleDe') || t.get('title'),
      category: t.get('categoryKey'),
      usageCount: t.get('usageCount')
    })),
    agentUsage: Object.entries(agentUsage).map(([agentId, count]) => ({
      agentId,
      usageCount: count
    })).sort((a, b) => b.usageCount - a.usageCount)
  };
});

console.log('CSR Templates Cloud Functions loaded');
