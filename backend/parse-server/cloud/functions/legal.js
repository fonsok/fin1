// ============================================================================
// Parse Cloud Code
// functions/legal.js - Legal Document Functions (Terms/Privacy/Imprint)
// ============================================================================
//
// Goals:
// - Server-driven legal documents with versioning + effective dates
// - Audit trail: which app version/device/user received which legal text version
// - Optional consent recording (acceptance)
//
// Parse Classes:
// - TermsContent              (source of truth for legal docs)
// - LegalDocumentDeliveryLog  (append-only delivery audit)
// - LegalConsent              (append-only acceptance audit)
//
// ============================================================================

'use strict';

function normalizeString(value) {
  if (typeof value !== 'string') return value;
  return value.trim();
}

function getRequestIP(request) {
  const headers = request?.headers || {};
  const forwarded = headers['x-forwarded-for'] || headers['X-Forwarded-For'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    // If multiple IPs, take first
    return forwarded.split(',')[0].trim();
  }
  return headers['x-real-ip'] || headers['X-Real-IP'] || null;
}

function getUserAgent(request) {
  const headers = request?.headers || {};
  return headers['user-agent'] || headers['User-Agent'] || null;
}

function validateLanguage(language) {
  const normalized = normalizeString(language || 'en');
  const allowed = ['en', 'de'];
  if (!allowed.includes(normalized)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid language: ${normalized}`);
  }
  return normalized;
}

function validateDocumentType(documentType) {
  const normalized = normalizeString(documentType || 'terms');
  const allowed = ['terms', 'privacy', 'imprint'];
  if (!allowed.includes(normalized)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid documentType: ${normalized}`);
  }
  return normalized;
}

// ----------------------------------------------------------------------------
// getCurrentTerms (backward-compatible name)
// ----------------------------------------------------------------------------
// Params:
// - language: "en" | "de"
// - documentType: "terms" | "privacy" | "imprint"
//
// Returns:
// {
//   objectId, version, language, documentType, effectiveDate, isActive,
//   documentHash, sections, createdAt, updatedAt
// }
Parse.Cloud.define('getCurrentTerms', async (request) => {
  const language = validateLanguage(request.params.language);
  const documentType = validateDocumentType(request.params.documentType);

  const query = new Parse.Query('TermsContent');
  query.equalTo('language', language);
  query.equalTo('documentType', documentType);
  query.equalTo('isActive', true);
  query.descending('effectiveDate');
  query.limit(1);

  const doc = await query.first({ useMasterKey: true });
  if (!doc) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'No active legal document found');
  }

  const effectiveDate = doc.get('effectiveDate');

  return {
    objectId: doc.id,
    version: doc.get('version'),
    language: doc.get('language'),
    documentType: doc.get('documentType'),
    effectiveDate: effectiveDate instanceof Date ? effectiveDate.toISOString() : null,
    isActive: !!doc.get('isActive'),
    documentHash: doc.get('documentHash') || null,
    sections: doc.get('sections') || [],
    createdAt: doc.createdAt ? doc.createdAt.toISOString() : null,
    updatedAt: doc.updatedAt ? doc.updatedAt.toISOString() : null
  };
});

// Alias with clearer naming for future clients
Parse.Cloud.define('getCurrentLegalDocument', async (request) => {
  return Parse.Cloud.run('getCurrentTerms', request.params, { useMasterKey: false });
});

// ----------------------------------------------------------------------------
// logLegalDocumentDelivery (audit trail: what was served to which app/device)
// ----------------------------------------------------------------------------
// Params:
// - documentType, language, servedVersion, servedHash (optional), servedAt (optional)
// - source: "server" | "cache" | "bundled"
// - platform: "ios" | "macos" | "android" | "web" | ...
// - appVersion, buildNumber
// - deviceInstallId (pseudonymous stable UUID from client)
// - dedupeWindowSeconds (optional, default 86400 = 24h)
Parse.Cloud.define('logLegalDocumentDelivery', async (request) => {
  const documentType = validateDocumentType(request.params.documentType);
  const language = validateLanguage(request.params.language);

  const servedVersion = normalizeString(request.params.servedVersion);
  if (!servedVersion) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'servedVersion is required');
  }

  const source = normalizeString(request.params.source || 'server');
  const allowedSources = ['server', 'cache', 'bundled'];
  if (!allowedSources.includes(source)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid source: ${source}`);
  }

  const deviceInstallId = normalizeString(request.params.deviceInstallId);
  if (!deviceInstallId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'deviceInstallId is required');
  }

  const platform = normalizeString(request.params.platform || 'ios');
  const appVersion = normalizeString(request.params.appVersion || '');
  const buildNumber = normalizeString(request.params.buildNumber || '');
  const servedHash = normalizeString(request.params.servedHash || null);

  const dedupeWindowSecondsRaw = request.params.dedupeWindowSeconds;
  const dedupeWindowSeconds =
    typeof dedupeWindowSecondsRaw === 'number' && dedupeWindowSecondsRaw > 0
      ? dedupeWindowSecondsRaw
      : 86400;

  // Dedupe: same device/app/doc/version within window -> skip insert
  const since = new Date(Date.now() - dedupeWindowSeconds * 1000);
  const dedupeQuery = new Parse.Query('LegalDocumentDeliveryLog');
  dedupeQuery.equalTo('documentType', documentType);
  dedupeQuery.equalTo('language', language);
  dedupeQuery.equalTo('servedVersion', servedVersion);
  dedupeQuery.equalTo('deviceInstallId', deviceInstallId);
  dedupeQuery.equalTo('appVersion', appVersion);
  dedupeQuery.greaterThan('createdAt', since);
  dedupeQuery.limit(1);

  const existing = await dedupeQuery.first({ useMasterKey: true });
  if (existing) {
    return { skipped: true, objectId: existing.id };
  }

  const Delivery = Parse.Object.extend('LegalDocumentDeliveryLog');
  const entry = new Delivery();

  entry.set('documentType', documentType);
  entry.set('language', language);
  entry.set('servedVersion', servedVersion);
  if (servedHash) entry.set('servedHash', servedHash);
  entry.set('source', source);

  entry.set('platform', platform);
  entry.set('appVersion', appVersion);
  entry.set('buildNumber', buildNumber);
  entry.set('deviceInstallId', deviceInstallId);

  // Optional user association
  if (request.user) {
    entry.set('userId', request.user.id);
  }

  // Context
  entry.set('ipAddress', getRequestIP(request));
  entry.set('userAgent', getUserAgent(request));

  // Optional client timestamp (server stores createdAt anyway)
  const servedAt = request.params.servedAt ? new Date(request.params.servedAt) : null;
  if (servedAt instanceof Date && !isNaN(servedAt.valueOf())) {
    entry.set('servedAt', servedAt);
  }

  const saved = await entry.save(null, { useMasterKey: true });
  return { skipped: false, objectId: saved.id, createdAt: saved.createdAt?.toISOString?.() ?? null };
});

// ----------------------------------------------------------------------------
// recordLegalConsent (append-only acceptance record)
// ----------------------------------------------------------------------------
// Params:
// - consentType: "terms_of_service" | "privacy_policy" | "imprint"
// - version, documentHash (optional), documentUrl (optional)
// - platform, appVersion, buildNumber, deviceInstallId
// - acceptedAt (optional; default now)
Parse.Cloud.define('recordLegalConsent', async (request) => {
  const consentType = normalizeString(request.params.consentType);
  const allowedConsentTypes = ['terms_of_service', 'privacy_policy', 'imprint'];
  if (!allowedConsentTypes.includes(consentType)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid consentType: ${consentType}`);
  }

  const version = normalizeString(request.params.version);
  if (!version) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
  }

  const deviceInstallId = normalizeString(request.params.deviceInstallId);
  if (!deviceInstallId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'deviceInstallId is required');
  }

  const Consent = Parse.Object.extend('LegalConsent');
  const entry = new Consent();

  entry.set('consentType', consentType);
  entry.set('version', version);

  const documentHash = normalizeString(request.params.documentHash || null);
  if (documentHash) entry.set('documentHash', documentHash);

  const documentUrl = normalizeString(request.params.documentUrl || null);
  if (documentUrl) entry.set('documentUrl', documentUrl);

  entry.set('accepted', true);

  const acceptedAt = request.params.acceptedAt ? new Date(request.params.acceptedAt) : new Date();
  entry.set('acceptedAt', acceptedAt);

  entry.set('platform', normalizeString(request.params.platform || 'ios'));
  entry.set('appVersion', normalizeString(request.params.appVersion || ''));
  entry.set('buildNumber', normalizeString(request.params.buildNumber || ''));
  entry.set('deviceInstallId', deviceInstallId);

  if (request.user) {
    entry.set('userId', request.user.id);
  }

  entry.set('ipAddress', getRequestIP(request));
  entry.set('userAgent', getUserAgent(request));

  const saved = await entry.save(null, { useMasterKey: true });
  return { objectId: saved.id, acceptedAt: saved.get('acceptedAt')?.toISOString?.() ?? null };
});

// ============================================================================
// Default Legal Snippet Sections (In-App Kurz-Hinweise)
// section.id must match iOS LegalSnippetKey.rawValue. Placeholders: {{MAX_RISK_PERCENT}}, {{TAX_RATE}}, {{VAT_RATE}}
// ============================================================================

const DEFAULT_LEGAL_SNIPPETS_DE = [
  { id: 'dashboard_risk_note', title: 'Risikohinweis Dashboard', content: 'Hinweis: Setzen Sie nicht mehr als {{MAX_RISK_PERCENT}} % Ihres Vermögens einem Risiko aus.', icon: 'exclamationmark.triangle' },
  { id: 'order_legal_warning_buy', title: 'Rechtliche Hinweise Kauforder', content: 'Mit dem Klicken auf \'Kaufen\' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.', icon: 'doc.text' },
  { id: 'order_legal_warning_sell', title: 'Rechtliche Hinweise Verkauforder', content: 'Mit dem Klicken auf \'Verkaufen\' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.', icon: 'doc.text' },
  { id: 'doc_tax_note_sell', title: 'Steuerhinweis Verkauf', content: 'Beim Verkauf erfolgt die Besteuerung gemäß Abgeltungsteuer (dzt. {{TAX_RATE}}) auf den realisierten Gewinn. Die Steuer wird automatisch von der Bank einbehalten.', icon: 'percent' },
  { id: 'doc_tax_note_buy', title: 'Steuerhinweis Kauf', content: 'Beim Kauf werden keine Steuern abgezogen. Die Besteuerung erfolgt erst beim Verkauf bzw. Gewinnrealisierung gemäß Abgeltungsteuer (dzt. {{TAX_RATE}}).', icon: 'percent' },
  { id: 'doc_legal_note_wphg', title: 'Rechtlicher Hinweis WpHG', content: 'Die Versteuerung erfolgt mit Gewinnrealisierung laut aktueller Regelung (§ 20 EStG).\n\nDiese Abrechnung erfolgt nach den Bestimmungen des Wertpapierhandelsgesetzes (WpHG) und der Wertpapierhandelsverordnung (WpDVerOV).', icon: 'scale.3d' },
  { id: 'doc_tax_note_service_charge', title: 'Steuerhinweis Servicegebühr', content: 'Die Plattform-Servicegebühr unterliegt der Umsatzsteuer ({{VAT_RATE}}). Der Rechnungsbetrag ist bereits die Bruttosumme inklusive Umsatzsteuer.', icon: 'percent' },
  { id: 'riskclass7_max_loss_warning', title: 'Risikoklasse 7 – Totalverlust', content: 'Das Verlustrisiko bis zu 100 % des eingesetzten Kapitals ist bekannt.', icon: 'exclamationmark.triangle' },
  { id: 'riskclass7_experienced_only', title: 'Risikoklasse 7 – Eignung', content: 'Diese Risikoklasse ist nur für erfahrene Anleger geeignet.', icon: 'person.fill.checkmark' },
  { id: 'doc_collection_bill_reference_info', title: 'Collection Bill Referenztext', content: 'Der Differenzbetrag zwischen ∑ Ergebnis vor Steuern und dem auf Ihrem Konto überwiesenen Betrag resultiert aus dem Steuerabzug. Dies wird gemäß den gesetzlichen Vorgaben durchgeführt und transparent in Ihren Kontoauszügen sowie Steuerunterlagen ausgewiesen.\nSteuerpflicht besteht nur, wenn der Verkaufserlös die Anschaffungskosten übersteigt. Die Berechnung basiert auf dem Prinzip der Verrechnung der Kauf- und Verkaufskosten (First-in-First-out oder Durchschnittskostenermittlung).\nDetails dazu finden Sie im Steuerreport unter der Transaktion-Nr.:', icon: 'doc.text' },
  { id: 'doc_collection_bill_legal_disclaimer', title: 'Collection Bill Rechtlicher Hinweis', content: 'Wir buchen die Wertpapiere und den Gegenwert gemäß der Abrechnung mit dem angegebenen Valutatag. Bitte prüfen Sie diese Abrechnung auf Richtigkeit und Vollständigkeit. Einspruch gegen diese Abrechnung muss unverzüglich nach Erhalt bei der Bank erhoben werden. Unterlassen Sie den rechtzeitigen Einspruch, gilt dies als Genehmigung. Bitte beachten Sie mögliche Hinweise des Emittenten bezüglich vorzeitiger Fälligkeit, z.B. aufgrund eines Knock-out, in den jeweiligen Optionsscheinbedingungen und informieren Sie sich rechtzeitig, welche besondere Fälligkeitsregelung für die von Ihnen gehaltenen Wertpapiere gilt. Kapitalerträge unterliegen der Einkommensteuer.', icon: 'doc.text' },
  { id: 'doc_collection_bill_footer_note', title: 'Collection Bill Fußnote', content: 'Diese Mitteilung ist maschinell erstellt und wird nicht unterschrieben.\nFür weitergehende Fragen wenden Sie sich bitte an Ihr Fin1-Service-Team.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_de', title: 'Kontoauszug Wichtige Hinweise (DE)', content: 'Bitte erheben Sie Einwendungen gegen einzelne Buchungen unverzüglich. Schecks, Wechsel und sonstige Lastschriften schreiben wir unter dem Vorbehalt des Eingangs gut. Der angegebene Kontostand berücksichtigt nicht die Wertstellung der Buchungen (siehe oben unter "Valuta").\n\nSomit können bei Verfügungen möglicherweise Zinsen für die Inanspruchnahme einer eingeräumten oder geduldeten Kontoüberziehung anfallen.\n\nDie abgerechneten Leistungen sind als Bank- oder Finanzdienstleistungen von der Umsatzsteuer befreit, sofern Umsatzsteuer nicht gesondert ausgewiesen ist. {{LEGAL_COMPANY_LEGAL_NAME}}, {{LEGAL_COMPANY_ADDRESS_LINE}}. Umsatzsteuer-ID: {{LEGAL_COMPANY_VAT_ID}}.\n\nGuthaben sind als Einlagen nach Maßgabe des Einlagensicherungsgesetzes entschädigungsfähig. Nähere Informationen können dem "Informationsbogen für den Einleger" entnommen werden.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_en', title: 'Account Statement Important Notice (EN)', content: 'Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.\n\nAll deposits and credits are subject to final verification.\n\nThe ending balance may not reflect all pending transactions or holds on funds.\n\nOverdrafts may result in fees or interest charges.\n\nWe are not responsible for delays in posting or for errors unless required by law.\n\nYour account is subject to the terms and conditions governing your relationship with the bank.', icon: 'doc.text' }
];

const DEFAULT_LEGAL_SNIPPETS_EN = [
  { id: 'dashboard_risk_note', title: 'Dashboard risk notice', content: 'Note: never expose more than {{MAX_RISK_PERCENT}} % of your assets to risk.', icon: 'exclamationmark.triangle' },
  { id: 'order_legal_warning_buy', title: 'Buy order legal notice', content: 'By clicking \'Buy\' you agree to the terms and conditions and confirm that you understand the risks of securities trading. This transaction is subject to fees.', icon: 'doc.text' },
  { id: 'order_legal_warning_sell', title: 'Sell order legal notice', content: 'By clicking \'Sell\' you agree to the terms and conditions and confirm that you understand the risks of securities trading. This transaction is subject to fees.', icon: 'doc.text' },
  { id: 'doc_tax_note_sell', title: 'Tax note (sell)', content: 'On sale, tax is levied according to the flat-rate withholding tax (currently {{TAX_RATE}}) on the realized gain. Tax is withheld automatically by the bank.', icon: 'percent' },
  { id: 'doc_tax_note_buy', title: 'Tax note (buy)', content: 'No tax is deducted on purchase. Taxation occurs on sale or gain realization according to the flat-rate withholding tax (currently {{TAX_RATE}}).', icon: 'percent' },
  { id: 'doc_legal_note_wphg', title: 'Legal note (WpHG)', content: 'Taxation is based on gain realization under current regulation (§ 20 EStG).\n\nThis statement is prepared in accordance with the German Securities Trading Act (WpHG) and the Securities Trading Ordinance (WpDVerOV).', icon: 'scale.3d' },
  { id: 'doc_tax_note_service_charge', title: 'Tax note (service charge)', content: 'The platform service charge is subject to VAT ({{VAT_RATE}}). The invoice amount is already the gross total including VAT.', icon: 'percent' },
  { id: 'riskclass7_max_loss_warning', title: 'Risk class 7 – total loss', content: 'The risk of loss of up to 100% of the capital invested is acknowledged.', icon: 'exclamationmark.triangle' },
  { id: 'riskclass7_experienced_only', title: 'Risk class 7 – suitability', content: 'This risk class is only suitable for experienced investors.', icon: 'person.fill.checkmark' },
  { id: 'doc_collection_bill_reference_info', title: 'Collection Bill reference text', content: 'The difference between ∑ result before tax and the amount transferred to your account results from tax withholding. This is carried out in accordance with legal requirements and shown transparently in your account statements and tax documents. Tax liability exists only if sale proceeds exceed acquisition costs. The calculation is based on the principle of offsetting purchase and sale costs (first-in-first-out or average cost). For details see the tax report under transaction no.:', icon: 'doc.text' },
  { id: 'doc_collection_bill_legal_disclaimer', title: 'Collection Bill legal notice', content: 'We book the securities and the equivalent in accordance with the statement with the specified value date. Please check this statement for correctness and completeness. Objections to this statement must be raised immediately upon receipt at the bank. Failure to object in time is deemed approval. Please note any issuer information on early maturity, e.g. due to knock-out, in the respective option certificate terms and inform yourself in good time of the specific maturity rules for the securities you hold. Capital gains are subject to income tax.', icon: 'doc.text' },
  { id: 'doc_collection_bill_footer_note', title: 'Collection Bill footer', content: 'This message is machine-generated and not signed.\nFor further questions please contact your Fin1 service team.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_de', title: 'Account statement important notice (DE)', content: 'Bitte erheben Sie Einwendungen gegen einzelne Buchungen unverzüglich. Schecks, Wechsel und sonstige Lastschriften schreiben wir unter dem Vorbehalt des Eingangs gut. Der angegebene Kontostand berücksichtigt nicht die Wertstellung der Buchungen (siehe oben unter "Valuta").\n\nSomit können bei Verfügungen möglicherweise Zinsen für die Inanspruchnahme einer eingeräumten oder geduldeten Kontoüberziehung anfallen.\n\nDie abgerechneten Leistungen sind als Bank- oder Finanzdienstleistungen von der Umsatzsteuer befreit, sofern Umsatzsteuer nicht gesondert ausgewiesen ist. {{LEGAL_COMPANY_LEGAL_NAME}}, {{LEGAL_COMPANY_ADDRESS_LINE}}. Umsatzsteuer-ID: {{LEGAL_COMPANY_VAT_ID}}.\n\nGuthaben sind als Einlagen nach Maßgabe des Einlagensicherungsgesetzes entschädigungsfähig. Nähere Informationen können dem "Informationsbogen für den Einleger" entnommen werden.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_en', title: 'Account statement important notice (EN)', content: 'Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.\n\nAll deposits and credits are subject to final verification.\n\nThe ending balance may not reflect all pending transactions or holds on funds.\n\nOverdrafts may result in fees or interest charges.\n\nWe are not responsible for delays in posting or for errors unless required by law.\n\nYour account is subject to the terms and conditions governing your relationship with the bank.', icon: 'doc.text' }
];

// ============================================================================
// ADMIN: TermsContent list / get / create / setActive (audit-safe, append-only)
// All functions support documentType: "terms" | "privacy" | "imprint" (AGB, Datenschutz, Impressum).
// ============================================================================

const { requireAdminRole, requirePermission } = require('../utils/permissions');

/**
 * List TermsContent versions (admin only). Optional filters: documentType, language.
 * documentType: "terms" | "privacy" | "imprint".
 */
Parse.Cloud.define('listTermsContent', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const documentType = request.params.documentType ? validateDocumentType(request.params.documentType) : null;
  const language = request.params.language ? validateLanguage(request.params.language) : null;

  const query = new Parse.Query('TermsContent');
  if (documentType) query.equalTo('documentType', documentType);
  if (language) query.equalTo('language', language);
  query.descending('effectiveDate');
  query.limit(200);

  const results = await query.find({ useMasterKey: true });
  return results.map((doc) => {
    const effectiveDate = doc.get('effectiveDate');
    return {
      objectId: doc.id,
      version: doc.get('version'),
      language: doc.get('language'),
      documentType: doc.get('documentType'),
      effectiveDate: effectiveDate instanceof Date ? effectiveDate.toISOString() : null,
      isActive: !!doc.get('isActive'),
      documentHash: doc.get('documentHash') || null,
      sectionCount: (doc.get('sections') || []).length,
      createdAt: doc.createdAt ? doc.createdAt.toISOString() : null,
      updatedAt: doc.updatedAt ? doc.updatedAt.toISOString() : null
    };
  });
});

/**
 * Get a single TermsContent by objectId (admin only). Returns full sections for editing/cloning.
 */
Parse.Cloud.define('getTermsContent', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { objectId } = request.params;
  if (!objectId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId is required');
  }

  const query = new Parse.Query('TermsContent');
  const doc = await query.get(objectId, { useMasterKey: true });
  if (!doc) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'TermsContent not found');
  }

  const effectiveDate = doc.get('effectiveDate');
  return {
    objectId: doc.id,
    version: doc.get('version'),
    language: doc.get('language'),
    documentType: doc.get('documentType'),
    effectiveDate: effectiveDate instanceof Date ? effectiveDate.toISOString() : null,
    isActive: !!doc.get('isActive'),
    documentHash: doc.get('documentHash') || null,
    sections: doc.get('sections') || [],
    createdAt: doc.createdAt ? doc.createdAt.toISOString() : null,
    updatedAt: doc.updatedAt ? doc.updatedAt.toISOString() : null
  };
});

/**
 * Create a new TermsContent version (admin only). Append-only; use setActiveTermsContent to make it live.
 * Params: version, language, documentType, effectiveDate (ISO string), isActive (default true), sections (array of { id, title, content, icon }).
 */
Parse.Cloud.define('createTermsContent', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { version, language, documentType, effectiveDate, isActive, sections } = request.params;

  const versionStr = normalizeString(version);
  if (!versionStr) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'version is required');
  }

  const lang = validateLanguage(language);
  const docType = validateDocumentType(documentType);

  if (!Array.isArray(sections) || sections.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'sections must be a non-empty array');
  }

  const effectiveDateObj = effectiveDate ? new Date(effectiveDate) : new Date();
  if (isNaN(effectiveDateObj.getTime())) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'effectiveDate must be a valid ISO date string');
  }

  const TermsContent = Parse.Object.extend('TermsContent');
  const doc = new TermsContent();
  doc.set('version', versionStr);
  doc.set('language', lang);
  doc.set('documentType', docType);
  doc.set('effectiveDate', effectiveDateObj);
  doc.set('sections', sections);
  doc.set('isActive', typeof isActive === 'boolean' ? isActive : true);

  await doc.save(null, { useMasterKey: true });

  const savedEffective = doc.get('effectiveDate');
  return {
    objectId: doc.id,
    version: doc.get('version'),
    language: doc.get('language'),
    documentType: doc.get('documentType'),
    effectiveDate: savedEffective instanceof Date ? savedEffective.toISOString() : null,
    isActive: !!doc.get('isActive'),
    documentHash: doc.get('documentHash') || null,
    sectionCount: (doc.get('sections') || []).length,
    createdAt: doc.createdAt ? doc.createdAt.toISOString() : null
  };
});

/**
 * Set a TermsContent version as the active one for its documentType+language (admin only).
 * Deactivates the current active version and sets the given one active.
 */
Parse.Cloud.define('setActiveTermsContent', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const { objectId } = request.params;
  if (!objectId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'objectId is required');
  }

  const query = new Parse.Query('TermsContent');
  const doc = await query.get(objectId, { useMasterKey: true });
  if (!doc) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'TermsContent not found');
  }

  const language = doc.get('language');
  const documentType = doc.get('documentType');

  const currentQuery = new Parse.Query('TermsContent');
  currentQuery.equalTo('language', language);
  currentQuery.equalTo('documentType', documentType);
  currentQuery.equalTo('isActive', true);
  const currentActive = await currentQuery.find({ useMasterKey: true });

  for (const d of currentActive) {
    if (d.id !== doc.id) {
      d.set('isActive', false);
      await d.save(null, { useMasterKey: true });
    }
  }

  doc.set('isActive', true);
  await doc.save(null, { useMasterKey: true });

  return {
    success: true,
    objectId: doc.id,
    version: doc.get('version'),
    language: doc.get('language'),
    documentType: doc.get('documentType')
  };
});

/**
 * Returns default Legal Snippet sections for a given language (admin only).
 * Used by admin panel to add In-App snippet sections when creating a new TermsContent version.
 * Params: language ("de" | "en").
 * Returns: { sections: Array<{ id, title, content, icon }> }
 */
Parse.Cloud.define('getDefaultLegalSnippetSections', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'manageTemplates');

  const language = validateLanguage(request.params.language || 'de');
  const sections = language === 'de' ? DEFAULT_LEGAL_SNIPPETS_DE : DEFAULT_LEGAL_SNIPPETS_EN;
  return { sections: [...sections] };
});

/**
 * Public (no auth) version that returns default Legal Snippet sections. Used by seed scripts only; returns static content only.
 * Params: language ("de" | "en"). Returns: { sections: Array<{ id, title, content, icon }> }
 */
Parse.Cloud.define('getDefaultLegalSnippetSectionsPublic', async (request) => {
  const language = validateLanguage(request.params.language || 'de');
  const sections = language === 'de' ? DEFAULT_LEGAL_SNIPPETS_DE : DEFAULT_LEGAL_SNIPPETS_EN;
  return { sections: [...sections] };
});

