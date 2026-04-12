'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

function registerEmailTemplateFunctions() {
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

    if (language === 'de') {
      data.subject = data.subjectDe || data.subject;
      data.bodyTemplate = data.bodyTemplateDe || data.bodyTemplate;
    }

    return data;
  });

  Parse.Cloud.define('createEmailTemplate', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'manageTemplates');

    const {
      type,
      displayName,
      subject,
      bodyTemplate,
      availablePlaceholders = [],
      icon = '✉️',
      isActive = true,
    } = request.params || {};

    if (!type || !displayName || !subject || !bodyTemplate) {
      throw new Parse.Error(Parse.Error.INVALID_QUERY, 'type, displayName, subject and bodyTemplate are required');
    }

    const normalizedType = String(type).trim();
    const existing = await new Parse.Query('CSREmailTemplate')
      .equalTo('type', normalizedType)
      .first({ useMasterKey: true });
    if (existing) {
      throw new Parse.Error(Parse.Error.DUPLICATE_VALUE, 'Email template type already exists');
    }

    const Template = Parse.Object.extend('CSREmailTemplate');
    const template = new Template();
    template.set('type', normalizedType);
    template.set('displayName', displayName);
    template.set('icon', icon);
    template.set('subject', subject);
    template.set('subjectDe', subject);
    template.set('subjectEn', subject);
    template.set('bodyTemplate', bodyTemplate);
    template.set('bodyTemplateDe', bodyTemplate);
    template.set('bodyTemplateEn', bodyTemplate);
    template.set('availablePlaceholders', Array.isArray(availablePlaceholders) ? availablePlaceholders : []);
    template.set('isActive', !!isActive);
    template.set('version', 1);
    template.set('createdBy', request.user?.id || 'system');

    await template.save(null, { useMasterKey: true });
    return template.toJSON();
  });

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

    template.increment('version');
    template.set('updatedBy', request.user.id);

    await template.save(null, { useMasterKey: true });

    console.log(`[Templates] Updated email template: ${templateId} by ${request.user.id}`);

    return template.toJSON();
  });

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

    let subject = language === 'de'
      ? (template.get('subjectDe') || template.get('subject'))
      : template.get('subject');
    let body = language === 'de'
      ? (template.get('bodyTemplateDe') || template.get('bodyTemplate'))
      : template.get('bodyTemplate');

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
}

module.exports = { registerEmailTemplateFunctions };
