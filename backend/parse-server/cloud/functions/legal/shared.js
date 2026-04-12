'use strict';

function normalizeString(value) {
  if (typeof value !== 'string') return value;
  return value.trim();
}

function getRequestIP(request) {
  const headers = request?.headers || {};
  const forwarded = headers['x-forwarded-for'] || headers['X-Forwarded-For'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
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

function serializeTermsContent(doc) {
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
    updatedAt: doc.updatedAt ? doc.updatedAt.toISOString() : null,
  };
}

function serializeTermsContentBackup(doc) {
  const json = doc.toJSON();
  return {
    objectId: json.objectId,
    version: json.version,
    language: json.language,
    documentType: json.documentType,
    effectiveDate: json.effectiveDate,
    isActive: json.isActive,
    documentHash: json.documentHash,
    sections: json.sections || [],
    createdAt: json.createdAt,
    updatedAt: json.updatedAt,
  };
}

const DEFAULT_LEGAL_SNIPPETS_DE = [
  { id: 'dashboard_risk_note', title: 'Risikohinweis Dashboard', content: 'Hinweis: Setzen Sie nicht mehr als {{MAX_RISK_PERCENT}} % Ihres Vermögens einem Risiko aus.', icon: 'exclamationmark.triangle' },
  { id: 'order_legal_warning_buy', title: 'Rechtliche Hinweise Kauforder', content: 'Mit dem Klicken auf \'Kaufen\' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.', icon: 'doc.text' },
  { id: 'order_legal_warning_sell', title: 'Rechtliche Hinweise Verkauforder', content: 'Mit dem Klicken auf \'Verkaufen\' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.', icon: 'doc.text' },
  { id: 'transaction_limit_warning_buy', title: 'Transaktionslimit erreicht', content: 'Ihr tägliches {{DAILY_LIMIT}} – Transaktionslimit wurde erreicht oder überschritten. Bitte reduzieren Sie den Orderbetrag oder wenden Sie sich an den Support, um Ihr Limit zu prüfen.', icon: 'chart.bar.xaxis' },
  { id: 'doc_tax_note_sell', title: 'Steuerhinweis Verkauf', content: 'Beim Verkauf erfolgt die Besteuerung gemäß Abgeltungsteuer (dzt. {{TAX_RATE}}) auf den realisierten Gewinn. Die Steuer wird automatisch von der Bank einbehalten.', icon: 'percent' },
  { id: 'doc_tax_note_buy', title: 'Steuerhinweis Kauf', content: 'Beim Kauf werden keine Steuern abgezogen. Die Besteuerung erfolgt erst beim Verkauf bzw. Gewinnrealisierung gemäß Abgeltungsteuer (dzt. {{TAX_RATE}}).', icon: 'percent' },
  { id: 'doc_legal_note_wphg', title: 'Rechtlicher Hinweis WpHG', content: 'Die Versteuerung erfolgt mit Gewinnrealisierung laut aktueller Regelung (§ 20 EStG).\n\nDiese Abrechnung erfolgt nach den Bestimmungen des Wertpapierhandelsgesetzes (WpHG) und der Wertpapierhandelsverordnung (WpDVerOV).', icon: 'scale.3d' },
  { id: 'doc_tax_note_service_charge', title: 'Steuerhinweis Servicegebühr', content: 'Die App-Servicegebühr unterliegt der Umsatzsteuer ({{VAT_RATE}}). Der Rechnungsbetrag ist bereits die Bruttosumme inklusive Umsatzsteuer.', icon: 'percent' },
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
  { id: 'transaction_limit_warning_buy', title: 'Transaction limit reached', content: 'Your daily {{DAILY_LIMIT}} transaction limit has been reached or exceeded. Please reduce the order amount or contact support to review your limit.', icon: 'chart.bar.xaxis' },
  { id: 'doc_tax_note_sell', title: 'Tax note (sell)', content: 'On sale, tax is levied according to the flat-rate withholding tax (currently {{TAX_RATE}}) on the realized gain. Tax is withheld automatically by the bank.', icon: 'percent' },
  { id: 'doc_tax_note_buy', title: 'Tax note (buy)', content: 'No tax is deducted on purchase. Taxation occurs on sale or gain realization according to the flat-rate withholding tax (currently {{TAX_RATE}}).', icon: 'percent' },
  { id: 'doc_legal_note_wphg', title: 'Legal note (WpHG)', content: 'Taxation is based on gain realization under current regulation (§ 20 EStG).\n\nThis statement is prepared in accordance with the German Securities Trading Act (WpHG) and the Securities Trading Ordinance (WpDVerOV).', icon: 'scale.3d' },
  { id: 'doc_tax_note_service_charge', title: 'Tax note (service charge)', content: 'The app service charge is subject to VAT ({{VAT_RATE}}). The invoice amount is already the gross total including VAT.', icon: 'percent' },
  { id: 'riskclass7_max_loss_warning', title: 'Risk class 7 – total loss', content: 'The risk of loss of up to 100% of the capital invested is acknowledged.', icon: 'exclamationmark.triangle' },
  { id: 'riskclass7_experienced_only', title: 'Risk class 7 – suitability', content: 'This risk class is only suitable for experienced investors.', icon: 'person.fill.checkmark' },
  { id: 'doc_collection_bill_reference_info', title: 'Collection Bill reference text', content: 'The difference between ∑ result before tax and the amount transferred to your account results from tax withholding. This is carried out in accordance with legal requirements and shown transparently in your account statements and tax documents. Tax liability exists only if sale proceeds exceed acquisition costs. The calculation is based on the principle of offsetting purchase and sale costs (first-in-first-out or average cost). For details see the tax report under transaction no.:', icon: 'doc.text' },
  { id: 'doc_collection_bill_legal_disclaimer', title: 'Collection Bill legal notice', content: 'We book the securities and the equivalent in accordance with the statement with the specified value date. Please check this statement for correctness and completeness. Objections to this statement must be raised immediately upon receipt at the bank. Failure to object in time is deemed approval. Please note any issuer information on early maturity, e.g. due to knock-out, in the respective option certificate terms and inform yourself in good time of the specific maturity rules for the securities you hold. Capital gains are subject to income tax.', icon: 'doc.text' },
  { id: 'doc_collection_bill_footer_note', title: 'Collection Bill footer', content: 'This message is machine-generated and not signed.\nFor further questions please contact your Fin1 service team.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_de', title: 'Account statement important notice (DE)', content: 'Bitte erheben Sie Einwendungen gegen einzelne Buchungen unverzüglich. Schecks, Wechsel und sonstige Lastschriften schreiben wir unter dem Vorbehalt des Eingangs gut. Der angegebene Kontostand berücksichtigt nicht die Wertstellung der Buchungen (siehe oben unter "Valuta").\n\nSomit können bei Verfügungen möglicherweise Zinsen für die Inanspruchnahme einer eingeräumten oder geduldeten Kontoüberziehung anfallen.\n\nDie abgerechneten Leistungen sind als Bank- oder Finanzdienstleistungen von der Umsatzsteuer befreit, sofern Umsatzsteuer nicht gesondert ausgewiesen ist. {{LEGAL_COMPANY_LEGAL_NAME}}, {{LEGAL_COMPANY_ADDRESS_LINE}}. Umsatzsteuer-ID: {{LEGAL_COMPANY_VAT_ID}}.\n\nGuthaben sind als Einlagen nach Maßgabe des Einlagensicherungsgesetzes entschädigungsfähig. Nähere Informationen können dem "Informationsbogen für den Einleger" entnommen werden.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_en', title: 'Account statement important notice (EN)', content: 'Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.\n\nAll deposits and credits are subject to final verification.\n\nThe ending balance may not reflect all pending transactions or holds on funds.\n\nOverdrafts may result in fees or interest charges.\n\nWe are not responsible for delays in posting or for errors unless required by law.\n\nYour account is subject to the terms and conditions governing your relationship with the bank.', icon: 'doc.text' }
];

module.exports = {
  normalizeString,
  getRequestIP,
  getUserAgent,
  validateLanguage,
  validateDocumentType,
  serializeTermsContent,
  serializeTermsContentBackup,
  DEFAULT_LEGAL_SNIPPETS_DE,
  DEFAULT_LEGAL_SNIPPETS_EN,
};
