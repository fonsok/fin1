'use strict';

const { requireAdminRole } = require('../../utils/permissions');

Parse.Cloud.define('seedCSRTemplateCategories', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('CSRTemplateCategory');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} categories already exist.`,
      created: 0
    };
  }

  const categories = [
    { key: 'greeting', displayName: 'Greeting', displayNameDe: 'Begrüßung', icon: '👋', sortOrder: 10 },
    { key: 'closing', displayName: 'Closing', displayNameDe: 'Abschluss', icon: '🏁', sortOrder: 20 },
    { key: 'account_issues', displayName: 'Account Issues', displayNameDe: 'Kontoprobleme', icon: '👤', sortOrder: 30 },
    { key: 'kyc_onboarding', displayName: 'KYC & Onboarding', displayNameDe: 'KYC & Onboarding', icon: '✅', sortOrder: 40 },
    { key: 'transactions', displayName: 'Transactions', displayNameDe: 'Transaktionen', icon: '💰', sortOrder: 50 },
    { key: 'technical', displayName: 'Technical Support', displayNameDe: 'Technischer Support', icon: '🔧', sortOrder: 60 },
    { key: 'billing', displayName: 'Billing', displayNameDe: 'Abrechnung', icon: '💳', sortOrder: 70 },
    { key: 'security', displayName: 'Security', displayNameDe: 'Sicherheit', icon: '🔒', sortOrder: 80 },
    { key: 'compliance', displayName: 'Compliance', displayNameDe: 'Compliance', icon: '📋', sortOrder: 90 },
    { key: 'fraud', displayName: 'Fraud', displayNameDe: 'Betrugsprävention', icon: '⚠️', sortOrder: 100 },
    { key: 'escalation', displayName: 'Escalation', displayNameDe: 'Eskalation', icon: '⬆️', sortOrder: 110 },
    { key: 'general', displayName: 'General', displayNameDe: 'Allgemein', icon: '📄', sortOrder: 999 },
  ];

  const Category = Parse.Object.extend('CSRTemplateCategory');
  let created = 0;

  for (const catData of categories) {
    const cat = new Category();
    cat.set('key', catData.key);
    cat.set('displayName', catData.displayName);
    cat.set('displayNameDe', catData.displayNameDe);
    cat.set('icon', catData.icon);
    cat.set('sortOrder', catData.sortOrder);
    cat.set('isActive', true);
    await cat.save(null, { useMasterKey: true });
    created++;
  }

  return { success: true, message: `Created ${created} categories`, created };
});

/**
 * Seed CSR response templates
 */
Parse.Cloud.define('seedCSRResponseTemplates', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('CSRResponseTemplate');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} templates already exist.`,
      created: 0
    };
  }

  const allRoles = ['level_1', 'level_2', 'fraud_analyst', 'compliance_officer', 'tech_support', 'teamlead'];

  const templates = [
    // Greetings
    {
      templateKey: 'greeting_standard',
      title: 'Standard Greeting',
      titleDe: 'Standard Begrüßung',
      categoryKey: 'greeting',
      body: 'Hello {{KUNDENNAME}},\n\nThank you for your message. I will take care of your request.\n\nBest regards',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\nvielen Dank für Ihre Nachricht. Ich werde mich um Ihr Anliegen kümmern.\n\nMit freundlichen Grüßen',
      availableForRoles: allRoles,
      placeholders: ['{{KUNDENNAME}}'],
      shortcut: 'hi',
      isDefault: true
    },
    {
      templateKey: 'greeting_formal',
      title: 'Formal Greeting',
      titleDe: 'Formelle Begrüßung',
      categoryKey: 'greeting',
      body: 'Dear {{KUNDENNAME}},\n\nThank you for contacting us regarding ticket {{TICKETNUMMER}}. I am happy to assist you.',
      bodyDe: 'Sehr geehrte/r {{KUNDENNAME}},\n\nvielen Dank für Ihre Kontaktaufnahme bezüglich Ticket {{TICKETNUMMER}}. Ich freue mich, Ihnen helfen zu können.',
      availableForRoles: allRoles,
      placeholders: ['{{KUNDENNAME}}', '{{TICKETNUMMER}}'],
      shortcut: 'formal',
      isDefault: true
    },
    // Closings
    {
      templateKey: 'closing_standard',
      title: 'Standard Closing',
      titleDe: 'Standard Abschluss',
      categoryKey: 'closing',
      body: 'If you have any further questions, please do not hesitate to contact us.\n\nBest regards,\n{{AGENTNAME}}\nCustomer Support',
      bodyDe: 'Bei weiteren Fragen stehe ich Ihnen gerne zur Verfügung.\n\nMit freundlichen Grüßen,\n{{AGENTNAME}}\nKundensupport',
      availableForRoles: allRoles,
      placeholders: ['{{AGENTNAME}}'],
      shortcut: 'close',
      isDefault: true
    },
    {
      templateKey: 'closing_resolved',
      title: 'Issue Resolved',
      titleDe: 'Problem gelöst',
      categoryKey: 'closing',
      body: 'I am glad we could resolve your issue. If you need any further assistance, please let us know.\n\nBest regards,\n{{AGENTNAME}}',
      bodyDe: 'Es freut mich, dass wir Ihr Anliegen lösen konnten. Falls Sie weitere Unterstützung benötigen, melden Sie sich gerne.\n\nMit freundlichen Grüßen,\n{{AGENTNAME}}',
      availableForRoles: allRoles,
      placeholders: ['{{AGENTNAME}}'],
      shortcut: 'resolved',
      isDefault: true
    },
    // Account Issues
    {
      templateKey: 'password_reset_guide',
      title: 'Password Reset Guide',
      titleDe: 'Passwort-Reset Anleitung',
      categoryKey: 'account_issues',
      body: 'Hello {{KUNDENNAME}},\n\nTo reset your password, please follow these steps:\n\n1. Open the app\n2. Tap "Sign In"\n3. Select "Forgot Password?"\n4. Enter your email address\n5. You will receive a reset link via email\n\nThe link is valid for 24 hours. If you do not receive an email, please check your spam folder.',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\num Ihr Passwort zurückzusetzen, gehen Sie bitte wie folgt vor:\n\n1. Öffnen Sie die App\n2. Tippen Sie auf "Anmelden"\n3. Wählen Sie "Passwort vergessen?"\n4. Geben Sie Ihre E-Mail-Adresse ein\n5. Sie erhalten einen Link zum Zurücksetzen per E-Mail\n\nDer Link ist 24 Stunden gültig. Falls Sie keine E-Mail erhalten, prüfen Sie bitte auch Ihren Spam-Ordner.',
      availableForRoles: ['level_1', 'level_2', 'teamlead'],
      placeholders: ['{{KUNDENNAME}}'],
      isDefault: true
    },
    {
      templateKey: 'account_unlocked',
      title: 'Account Unlocked',
      titleDe: 'Konto entsperrt',
      categoryKey: 'account_issues',
      body: 'Hello {{KUNDENNAME}},\n\nYour account has been successfully unlocked. You can now log in again.\n\n**Important Security Notes:**\n• Use a strong, unique password\n• Enable Two-Factor Authentication (2FA)\n• Report suspicious activity immediately',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\nIhr Konto wurde erfolgreich entsperrt. Sie können sich jetzt wieder anmelden.\n\n**Wichtige Sicherheitshinweise:**\n• Verwenden Sie ein starkes, einzigartiges Passwort\n• Aktivieren Sie die Zwei-Faktor-Authentifizierung (2FA)\n• Melden Sie verdächtige Aktivitäten sofort',
      availableForRoles: ['level_2', 'teamlead'],
      placeholders: ['{{KUNDENNAME}}'],
      isDefault: true
    },
    // Technical Support
    {
      templateKey: 'app_update_required',
      title: 'App Update Required',
      titleDe: 'App-Update erforderlich',
      categoryKey: 'technical',
      body: 'Hello {{KUNDENNAME}},\n\nPlease update the app to the latest version:\n\n• iOS: App Store → Updates\n• Android: Play Store → My Apps\n\nThe latest version fixes known issues and improves stability.',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\nbitte aktualisieren Sie die App auf die neueste Version:\n\n• iOS: App Store → Updates\n• Android: Play Store → Meine Apps\n\nDie neueste Version behebt bekannte Probleme und verbessert die Stabilität.',
      availableForRoles: ['level_1', 'level_2', 'tech_support', 'teamlead'],
      placeholders: ['{{KUNDENNAME}}'],
      shortcut: 'update',
      isDefault: true
    },
    {
      templateKey: 'clear_cache',
      title: 'Clear Cache Instructions',
      titleDe: 'Cache leeren Anleitung',
      categoryKey: 'technical',
      body: 'Hello {{KUNDENNAME}},\n\nPlease try the following steps:\n\n1. Close the app completely\n2. Go to Device Settings → Apps → [App Name] → Clear Cache\n3. Restart the app\n\nIf the problem persists, please contact us again.',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\nbitte versuchen Sie folgende Schritte:\n\n1. App vollständig schließen\n2. In den Geräte-Einstellungen → Apps → [App-Name] → Cache leeren\n3. App neu starten\n\nSollte das Problem weiterhin bestehen, melden Sie sich bitte erneut.',
      availableForRoles: ['level_1', 'level_2', 'tech_support', 'teamlead'],
      placeholders: ['{{KUNDENNAME}}'],
      shortcut: 'cache',
      isDefault: true
    },
    // KYC
    {
      templateKey: 'kyc_documents_required',
      title: 'KYC Documents Required',
      titleDe: 'KYC-Dokumente nachfordern',
      categoryKey: 'kyc_onboarding',
      subject: 'Additional documents required',
      subjectDe: 'Zusätzliche Dokumente erforderlich',
      body: 'Hello {{KUNDENNAME}},\n\nTo complete your identity verification (KYC), we still need the following documents:\n\n{{FEHLENDE_DOKUMENTE}}\n\n**Document Requirements:**\n• Clearly readable\n• Fully visible (all corners)\n• Valid expiration date\n• Maximum 10 MB per file (JPG, PNG or PDF)\n\nPlease upload the documents in the app under "Profile" → "Documents".',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\nzur Vervollständigung Ihrer Identitätsprüfung (KYC) benötigen wir noch folgende Unterlagen:\n\n{{FEHLENDE_DOKUMENTE}}\n\n**Anforderungen an die Dokumente:**\n• Gut lesbar\n• Vollständig sichtbar (alle Ecken)\n• Gültiges Ablaufdatum\n• Maximal 10 MB pro Datei (JPG, PNG oder PDF)\n\nBitte laden Sie die Dokumente in der App unter "Profil" → "Dokumente" hoch.',
      isEmail: true,
      availableForRoles: ['level_2', 'compliance_officer', 'teamlead'],
      placeholders: ['{{KUNDENNAME}}', '{{FEHLENDE_DOKUMENTE}}'],
      isDefault: true
    },
    // Billing
    {
      templateKey: 'refund_initiated',
      title: 'Refund Initiated',
      titleDe: 'Rückerstattung eingeleitet',
      categoryKey: 'billing',
      body: 'Hello {{KUNDENNAME}},\n\nI have initiated a refund for you. The amount will be credited to your account within 5-7 business days.',
      bodyDe: 'Guten Tag {{KUNDENNAME}},\n\nich habe eine Rückerstattung für Sie eingeleitet. Der Betrag wird innerhalb von 5-7 Werktagen auf Ihrem Konto gutgeschrieben.',
      availableForRoles: ['level_2', 'teamlead'],
      placeholders: ['{{KUNDENNAME}}'],
      isDefault: true
    },
  ];

  const Template = Parse.Object.extend('CSRResponseTemplate');
  let created = 0;

  for (const tplData of templates) {
    const tpl = new Template();
    tpl.set('templateKey', tplData.templateKey);
    tpl.set('title', tplData.title);
    tpl.set('titleDe', tplData.titleDe);
    tpl.set('categoryKey', tplData.categoryKey);
    tpl.set('subject', tplData.subject || null);
    tpl.set('subjectDe', tplData.subjectDe || null);
    tpl.set('body', tplData.body);
    tpl.set('bodyDe', tplData.bodyDe);
    tpl.set('isEmail', tplData.isEmail || false);
    tpl.set('availableForRoles', tplData.availableForRoles);
    tpl.set('placeholders', tplData.placeholders);
    tpl.set('shortcut', tplData.shortcut || null);
    tpl.set('usageCount', 0);
    tpl.set('isActive', true);
    tpl.set('isDefault', tplData.isDefault || false);
    tpl.set('version', 1);
    await tpl.save(null, { useMasterKey: true });
    created++;
  }

  return { success: true, message: `Created ${created} response templates`, created };
});

/**
 * Seed CSR email templates
 */
Parse.Cloud.define('seedCSREmailTemplates', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('CSREmailTemplate');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} email templates already exist.`,
      created: 0
    };
  }

  const emailTemplates = [
    {
      type: 'ticket_created',
      displayName: 'Ticket Created',
      icon: '📩',
      subject: '[{{companyName}}] Ticket {{ticketNumber}} created',
      subjectDe: '[{{companyName}}] Ticket {{ticketNumber}} wurde erstellt',
      bodyTemplate: 'Hello {{customerName}},\n\nThank you for your inquiry. We have created your support ticket.\n\nTicket: {{ticketNumber}}\nSubject: {{ticketSubject}}\n\nOur support team will get back to you soon.\n\nBest regards,\nYour {{companyName}} Support Team',
      bodyTemplateDe: 'Guten Tag {{customerName}},\n\nvielen Dank für Ihre Anfrage. Wir haben Ihr Support-Ticket erstellt.\n\nTicket: {{ticketNumber}}\nBetreff: {{ticketSubject}}\n\nUnser Support-Team wird sich schnellstmöglich bei Ihnen melden.\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
      availablePlaceholders: ['customerName', 'ticketNumber', 'ticketSubject', 'ticketDescription', 'companyName']
    },
    {
      type: 'ticket_response',
      displayName: 'New Response',
      icon: '💬',
      subject: '[{{companyName}}] New response to Ticket {{ticketNumber}}',
      subjectDe: '[{{companyName}}] Neue Antwort auf Ticket {{ticketNumber}}',
      bodyTemplate: 'Hello {{customerName}},\n\nYou have received a new response to your support ticket.\n\nTicket: {{ticketNumber}}\n\nResponse from {{agentName}}:\n{{responseMessage}}\n\nBest regards,\nYour {{companyName}} Support Team',
      bodyTemplateDe: 'Guten Tag {{customerName}},\n\nSie haben eine neue Antwort auf Ihr Support-Ticket erhalten.\n\nTicket: {{ticketNumber}}\n\nAntwort von {{agentName}}:\n{{responseMessage}}\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
      availablePlaceholders: ['customerName', 'ticketNumber', 'ticketSubject', 'agentName', 'responseMessage', 'companyName']
    },
    {
      type: 'ticket_resolved',
      displayName: 'Ticket Resolved',
      icon: '✅',
      subject: '[{{companyName}}] Ticket {{ticketNumber}} resolved ✓',
      subjectDe: '[{{companyName}}] Ticket {{ticketNumber}} wurde gelöst ✓',
      bodyTemplate: 'Hello {{customerName}},\n\nYour support ticket has been resolved.\n\nTicket: {{ticketNumber}}\nHandled by: {{agentName}}\n\nResolution:\n{{resolutionSummary}}\n\nIf the problem persists, you can reopen this ticket within 7 days.\n\nBest regards,\nYour {{companyName}} Support Team',
      bodyTemplateDe: 'Guten Tag {{customerName}},\n\nIhr Support-Ticket wurde gelöst.\n\nTicket: {{ticketNumber}}\nBearbeitet von: {{agentName}}\n\nLösung:\n{{resolutionSummary}}\n\nSollte das Problem weiterhin bestehen, können Sie dieses Ticket innerhalb von 7 Tagen wiedereröffnen.\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
      availablePlaceholders: ['customerName', 'ticketNumber', 'ticketSubject', 'agentName', 'resolutionSummary', 'companyName']
    },
    {
      type: 'survey_request',
      displayName: 'Survey Request',
      icon: '⭐',
      subject: '[{{companyName}}] How was our support? ⭐',
      subjectDe: '[{{companyName}}] Wie war unser Support? ⭐',
      bodyTemplate: 'Hello {{customerName}},\n\nYour support ticket {{ticketNumber}} was handled by {{agentName}}.\n\nWe would appreciate your feedback. Please rate our service:\n\n→ Rate now: {{surveyLink}}\n\nThank you!\n\nBest regards,\nYour {{companyName}} Support Team',
      bodyTemplateDe: 'Guten Tag {{customerName}},\n\nIhr Support-Ticket {{ticketNumber}} wurde von {{agentName}} bearbeitet.\n\nWir würden uns über Ihr Feedback freuen. Bitte bewerten Sie unseren Service:\n\n→ Jetzt bewerten: {{surveyLink}}\n\nVielen Dank!\n\nMit freundlichen Grüßen,\nIhr {{companyName}} Support-Team',
      availablePlaceholders: ['customerName', 'ticketNumber', 'agentName', 'surveyLink', 'companyName']
    },
  ];

  const Template = Parse.Object.extend('CSREmailTemplate');
  let created = 0;

  for (const tplData of emailTemplates) {
    const tpl = new Template();
    tpl.set('type', tplData.type);
    tpl.set('displayName', tplData.displayName);
    tpl.set('icon', tplData.icon);
    tpl.set('subject', tplData.subject);
    tpl.set('subjectDe', tplData.subjectDe);
    tpl.set('bodyTemplate', tplData.bodyTemplate);
    tpl.set('bodyTemplateDe', tplData.bodyTemplateDe);
    tpl.set('availablePlaceholders', tplData.availablePlaceholders);
    tpl.set('isActive', true);
    tpl.set('version', 1);
    await tpl.save(null, { useMasterKey: true });
    created++;
  }

  return { success: true, message: `Created ${created} email templates`, created };
});

/**
 * Seed all CSR template data at once
 */
Parse.Cloud.define('seedCSRTemplates', async (request) => {
  requireAdminRole(request);

  const results = {};

  // Seed categories first
  try {
    results.categories = await Parse.Cloud.run('seedCSRTemplateCategories', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.categories = { success: false, error: e.message };
  }

  // Seed response templates
  try {
    results.responseTemplates = await Parse.Cloud.run('seedCSRResponseTemplates', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.responseTemplates = { success: false, error: e.message };
  }

  // Seed email templates
  try {
    results.emailTemplates = await Parse.Cloud.run('seedCSREmailTemplates', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.emailTemplates = { success: false, error: e.message };
  }

  return results;
});
