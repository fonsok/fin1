'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

function registerResponseTemplateFunctions() {
  Parse.Cloud.define('getResponseTemplates', async (request) => {
    requireAdminRole(request);

    const { role, category, language = 'de', includeInactive = false } = request.params;

    if (!role) {
      throw new Parse.Error(Parse.Error.INVALID_QUERY, 'role is required');
    }

    const Template = Parse.Object.extend('CSRResponseTemplate');
    const query = new Parse.Query(Template);

    query.containedIn('availableForRoles', [role]);

    if (category) {
      query.equalTo('categoryKey', category);
    }

    if (!includeInactive) {
      query.equalTo('isActive', true);
    }

    query.ascending('categoryKey');
    query.addAscending('title');

    const templates = await query.find({ useMasterKey: true });

    return templates.map(t => {
      const data = t.toJSON();

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

    if (templateKey) {
      const existingQuery = new Parse.Query('CSRResponseTemplate');
      existingQuery.equalTo('templateKey', templateKey);
      const existing = await existingQuery.first({ useMasterKey: true });
      if (existing) {
        throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'Template key already exists');
      }
    }

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

    if (template.get('isDefault') && updates.hasOwnProperty('templateKey')) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot change templateKey of default template');
    }

    if (updates.shortcut && updates.shortcut !== template.get('shortcut')) {
      const shortcutQuery = new Parse.Query('CSRResponseTemplate');
      shortcutQuery.equalTo('shortcut', updates.shortcut);
      shortcutQuery.notEqualTo('objectId', templateId);
      const existingShortcut = await shortcutQuery.first({ useMasterKey: true });
      if (existingShortcut) {
        throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'Shortcut already in use');
      }
    }

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

    template.increment('version');
    template.set('updatedBy', request.user.id);

    await template.save(null, { useMasterKey: true });

    console.log(`[Templates] Updated response template: ${templateId} by ${request.user.id}`);

    return template.toJSON();
  });

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

    if (template.get('isDefault')) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot delete default templates');
    }

    template.set('isActive', false);
    template.set('deletedBy', request.user.id);
    template.set('deletedAt', new Date());

    await template.save(null, { useMasterKey: true });

    console.log(`[Templates] Deleted response template: ${templateId} by ${request.user.id}`);

    return { success: true, message: 'Template deleted' };
  });

  Parse.Cloud.define('recordTemplateUsage', async (request) => {
    requireAdminRole(request);

    const { templateId, ticketId } = request.params;

    if (!templateId) {
      throw new Parse.Error(Parse.Error.INVALID_QUERY, 'templateId is required');
    }

    const Template = Parse.Object.extend('CSRResponseTemplate');
    const query = new Parse.Query(Template);
    const template = await query.get(templateId, { useMasterKey: true });

    template.increment('usageCount');
    template.set('lastUsedAt', new Date());
    await template.save(null, { useMasterKey: true });

    const UsageStat = Parse.Object.extend('CSRTemplateUsageStat');
    const stat = new UsageStat();
    stat.set('templateId', templateId);
    stat.set('agentId', request.user.id);
    stat.set('ticketId', ticketId);
    stat.set('usedAt', new Date());
    await stat.save(null, { useMasterKey: true });

    return { success: true };
  });
}

module.exports = { registerResponseTemplateFunctions };
