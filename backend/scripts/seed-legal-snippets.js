#!/usr/bin/env node
// ============================================================================
// Seed Legal Snippet Sections into TermsContent (AGB)
// ============================================================================
// Adds the default Legal Snippet sections (dashboard_risk_note, order_legal_warning_*,
// doc_*, riskclass7_*) to a new TermsContent version so the iOS app can load them
// via LegalSnippetProvider from getCurrentTerms(terms).
//
// Usage:
//   PARSE_SERVER_URL=https://your-server/parse PARSE_APP_ID=fin1-app-id PARSE_MASTER_KEY=xxx node seed-legal-snippets.js
//   Or from backend/scripts: node seed-legal-snippets.js  (reads ../parse-server/.env for PARSE_MASTER_KEY)
//
// Options (env):
//   SEED_LEGAL_LANGUAGE=de   Language (default: de)
//   SEED_LEGAL_DOCUMENT_TYPE=terms  (default: terms)
//
// After running: In Admin Portal → AGB & Rechtstexte, open the new version and click "Als aktiv setzen".
// ============================================================================

const http = require('http');
const https = require('https');

let PARSE_SERVER_URL = process.env.PARSE_SERVER_URL || process.env.PARSE_SERVER_PUBLIC_SERVER_URL || 'http://localhost:1337/parse';
let PARSE_APP_ID = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
let PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || process.env.PARSE_SERVER_MASTER_KEY || '';
const LANGUAGE = (process.env.SEED_LEGAL_LANGUAGE || 'de').trim();
const DOCUMENT_TYPE = (process.env.SEED_LEGAL_DOCUMENT_TYPE || 'terms').trim();

// Fallback when getDefaultLegalSnippetSectionsPublic is not yet deployed on the server (sync with legal.js)
const DEFAULT_SNIPPETS_DE = [
  { id: 'dashboard_risk_note', title: 'Risikohinweis Dashboard', content: 'Hinweis: Setzen Sie nicht mehr als {{MAX_RISK_PERCENT}} % Ihres Vermögens einem Risiko aus.', icon: 'exclamationmark.triangle' },
  { id: 'order_legal_warning_buy', title: 'Rechtliche Hinweise Kauforder', content: 'Mit dem Klicken auf \'Kaufen\' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.', icon: 'doc.text' },
  { id: 'order_legal_warning_sell', title: 'Rechtliche Hinweise Verkauforder', content: 'Mit dem Klicken auf \'Verkaufen\' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.', icon: 'doc.text' },
  { id: 'doc_tax_note_sell', title: 'Steuerhinweis Verkauf', content: 'Beim Verkauf erfolgt die Besteuerung gemäß Abgeltungsteuer (dzt. {{TAX_RATE}}) auf den realisierten Gewinn. Die Steuer wird automatisch von der Bank einbehalten.', icon: 'percent' },
  { id: 'doc_tax_note_buy', title: 'Steuerhinweis Kauf', content: 'Beim Kauf werden keine Steuern abgezogen. Die Besteuerung erfolgt erst beim Verkauf bzw. Gewinnrealisierung gemäß Abgeltungsteuer (dzt. {{TAX_RATE}}).', icon: 'percent' },
  { id: 'doc_legal_note_wphg', title: 'Rechtlicher Hinweis WpHG', content: 'Die Versteuerung erfolgt mit Gewinnrealisierung laut aktueller Regelung (§ 20 EStG).\n\nDiese Abrechnung erfolgt nach den Bestimmungen des Wertpapierhandelsgesetzes (WpHG) und der Wertpapierhandelsverordnung (WpDVerOV).', icon: 'scale.3d' },
  { id: 'doc_tax_note_service_charge', title: 'Steuerhinweis Servicegebühr', content: 'Die Plattform-Servicegebühr unterliegt der Umsatzsteuer ({{VAT_RATE}}). Der Rechnungsbetrag ist bereits die Bruttosumme inklusive Umsatzsteuer.', icon: 'percent' },
  { id: 'riskclass7_max_loss_warning', title: 'Risikoklasse 7 – Totalverlust', content: 'Das Verlustrisiko bis zu 100 % des eingesetzten Kapitals ist bekannt.', icon: 'exclamationmark.triangle' },
  { id: 'riskclass7_experienced_only', title: 'Risikoklasse 7 – Eignung', content: 'Diese Risikoklasse ist nur für erfahrene Anleger geeignet.', icon: 'person.fill.checkmark' },
  {
    id: 'doc_collection_bill_reference_info',
    title: 'Collection Bill Referenztext',
    content: 'Der Differenzbetrag zwischen ∑ Ergebnis vor Steuern und dem auf Ihrem Konto überwiesenen Betrag resultiert aus dem Steuerabzug. Dies wird gemäß den gesetzlichen Vorgaben durchgeführt und transparent in Ihren Kontoauszügen sowie Steuerunterlagen ausgewiesen.\nSteuerpflicht besteht nur, wenn der Verkaufserlös die Anschaffungskosten übersteigt. Die Berechnung basiert auf dem Prinzip der Verrechnung der Kauf- und Verkaufskosten (First-in-First-out oder Durchschnittskostenermittlung).\nDetails dazu finden Sie im Steuerreport unter der Transaktion-Nr.:',
    icon: 'doc.text'
  },
  {
    id: 'doc_collection_bill_legal_disclaimer',
    title: 'Collection Bill Rechtlicher Hinweis',
    content: 'Wir buchen die Wertpapiere und den Gegenwert gemäß der Abrechnung mit dem angegebenen Valutatag. Bitte prüfen Sie diese Abrechnung auf Richtigkeit und Vollständigkeit. Einspruch gegen diese Abrechnung muss unverzüglich nach Erhalt bei der Bank erhoben werden. Unterlassen Sie den rechtzeitigen Einspruch, gilt dies als Genehmigung. Bitte beachten Sie mögliche Hinweise des Emittenten bezüglich vorzeitiger Fälligkeit, z.B. aufgrund eines Knock-out, in den jeweiligen Optionsscheinbedingungen und informieren Sie sich rechtzeitig, welche besondere Fälligkeitsregelung für die von Ihnen gehaltenen Wertpapiere gilt. Kapitalerträge unterliegen der Einkommensteuer.',
    icon: 'doc.text'
  },
  {
    id: 'doc_collection_bill_footer_note',
    title: 'Collection Bill Fußnote',
    content: 'Diese Mitteilung ist maschinell erstellt und wird nicht unterschrieben.\nFür weitergehende Fragen wenden Sie sich bitte an Ihr Fin1-Service-Team.',
    icon: 'doc.text'
  },
  {
    id: 'account_statement_important_notice_de',
    title: 'Kontoauszug Wichtige Hinweise (DE)',
    content: 'Bitte erheben Sie Einwendungen gegen einzelne Buchungen unverzüglich. Schecks, Wechsel und sonstige Lastschriften schreiben wir unter dem Vorbehalt des Eingangs gut. Der angegebene Kontostand berücksichtigt nicht die Wertstellung der Buchungen (siehe oben unter "Valuta").\n\nSomit können bei Verfügungen möglicherweise Zinsen für die Inanspruchnahme einer eingeräumten oder geduldeten Kontoüberziehung anfallen.\n\nDie abgerechneten Leistungen sind als Bank- oder Finanzdienstleistungen von der Umsatzsteuer befreit, sofern Umsatzsteuer nicht gesondert ausgewiesen ist. {{LEGAL_COMPANY_LEGAL_NAME}}, {{LEGAL_COMPANY_ADDRESS_LINE}}. Umsatzsteuer-ID: {{LEGAL_COMPANY_VAT_ID}}.\n\nGuthaben sind als Einlagen nach Maßgabe des Einlagensicherungsgesetzes entschädigungsfähig. Nähere Informationen können dem "Informationsbogen für den Einleger" entnommen werden.',
    icon: 'doc.text'
  },
  {
    id: 'account_statement_important_notice_en',
    title: 'Account Statement Important Notice (EN)',
    content: 'Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.\n\nAll deposits and credits are subject to final verification.\n\nThe ending balance may not reflect all pending transactions or holds on funds.\n\nOverdrafts may result in fees or interest charges.\n\nWe are not responsible for delays in posting or for errors unless required by law.\n\nYour account is subject to the terms and conditions governing your relationship with the bank.',
    icon: 'doc.text'
  }
];

// Snippet-IDs, die in jeder AGB-Version vorhanden sein sollen (z. B. Kontoauszug „Wichtige Hinweise“).
// Wenn sie in der aktuellen Version fehlen, werden sie aus diesem Fallback ergänzt.
const REQUIRED_SNIPPET_IDS = ['account_statement_important_notice_de', 'account_statement_important_notice_en'];
const REQUIRED_SNIPPETS_FALLBACK = [
  { id: 'account_statement_important_notice_de', title: 'Kontoauszug Wichtige Hinweise (DE)', content: 'Bitte erheben Sie Einwendungen gegen einzelne Buchungen unverzüglich. Schecks, Wechsel und sonstige Lastschriften schreiben wir unter dem Vorbehalt des Eingangs gut. Der angegebene Kontostand berücksichtigt nicht die Wertstellung der Buchungen (siehe oben unter "Valuta").\n\nSomit können bei Verfügungen möglicherweise Zinsen für die Inanspruchnahme einer eingeräumten oder geduldeten Kontoüberziehung anfallen.\n\nDie abgerechneten Leistungen sind als Bank- oder Finanzdienstleistungen von der Umsatzsteuer befreit, sofern Umsatzsteuer nicht gesondert ausgewiesen ist. {{LEGAL_COMPANY_LEGAL_NAME}}, {{LEGAL_COMPANY_ADDRESS_LINE}}. Umsatzsteuer-ID: {{LEGAL_COMPANY_VAT_ID}}.\n\nGuthaben sind als Einlagen nach Maßgabe des Einlagensicherungsgesetzes entschädigungsfähig. Nähere Informationen können dem "Informationsbogen für den Einleger" entnommen werden.', icon: 'doc.text' },
  { id: 'account_statement_important_notice_en', title: 'Account Statement Important Notice (EN)', content: 'Please review your statement carefully and notify us immediately of any discrepancies or unauthorized transactions.\n\nAll deposits and credits are subject to final verification.\n\nThe ending balance may not reflect all pending transactions or holds on funds.\n\nOverdrafts may result in fees or interest charges.\n\nWe are not responsible for delays in posting or for errors unless required by law.\n\nYour account is subject to the terms and conditions governing your relationship with the bank.', icon: 'doc.text' }
];

function loadEnvFromFile() {
  try {
    const fs = require('fs');
    const path = require('path');
    const candidates = [
      path.join(__dirname, '../parse-server/.env'),
      path.join(__dirname, '../.env'),   // backend/.env (Docker env_file)
      path.join(__dirname, '../../.env')
    ];
    for (const envPath of candidates) {
      if (!fs.existsSync(envPath)) continue;
      const envContent = fs.readFileSync(envPath, 'utf8');
      const getVal = (name) => {
        const re = new RegExp(`^\\s*${name}=(.+)`, 'm');
        const m = envContent.match(re);
        return m ? m[1].trim().replace(/^["']|["']$/g, '') : null;
      };
      if (!PARSE_MASTER_KEY) PARSE_MASTER_KEY = getVal('PARSE_SERVER_MASTER_KEY') || getVal('PARSE_MASTER_KEY') || '';
      if (!PARSE_SERVER_URL || PARSE_SERVER_URL.includes('localhost')) {
        const u = getVal('PARSE_SERVER_PUBLIC_SERVER_URL') || getVal('PARSE_SERVER_URL');
        if (u) PARSE_SERVER_URL = u.replace(/\/parse\/?$/, '') + '/parse';
      }
      if (!PARSE_APP_ID || PARSE_APP_ID === 'fin1-app-id') PARSE_APP_ID = getVal('PARSE_SERVER_APPLICATION_ID') || getVal('PARSE_APP_ID') || PARSE_APP_ID;
      if (PARSE_MASTER_KEY) break;
    }
  } catch (_) {}
}

function callParse(method, path, body, useMasterKey) {
  return new Promise((resolve, reject) => {
    const url = new URL(PARSE_SERVER_URL + (path.startsWith('/') ? path : '/' + path));
    const isHttps = url.protocol === 'https:';
    const client = isHttps ? https : http;
    const postData = body ? JSON.stringify(body) : '';
    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname,
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Parse-Application-Id': PARSE_APP_ID,
        ...(useMasterKey && PARSE_MASTER_KEY && { 'X-Parse-Master-Key': PARSE_MASTER_KEY })
      }
    };
    if (postData) {
      options.headers['Content-Length'] = Buffer.byteLength(postData);
    }
    const req = client.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data || '{}');
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(json);
          else reject(new Error(json.error?.message || `HTTP ${res.statusCode}: ${data}`));
        } catch (e) {
          reject(new Error(`Parse response error: ${data}`));
        }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function callCloudFunction(name, params, useMasterKey = false) {
  const result = await callParse('POST', '/functions/' + name, params, useMasterKey);
  if (result.result !== undefined) return result.result;
  throw new Error('Cloud function did not return result');
}

async function getCurrentTerms(language, documentType) {
  try {
    return await callCloudFunction('getCurrentTerms', { language, documentType }, false);
  } catch (e) {
    if (e.message && (e.message.includes('OBJECT_NOT_FOUND') || e.message.includes('No active'))) return null;
    throw e;
  }
}

async function getDefaultSnippetSections(language) {
  try {
    const out = await callCloudFunction('getDefaultLegalSnippetSectionsPublic', { language }, false);
    if (out && Array.isArray(out.sections) && out.sections.length > 0) return out.sections;
  } catch (e) {
    if (!e.message || !e.message.includes('Invalid function')) throw e;
  }
  return language === 'de' ? DEFAULT_SNIPPETS_DE : DEFAULT_SNIPPETS_DE; // EN same structure, DE used as fallback
}

function mergeSections(existingSections, snippetSections) {
  const byId = new Map();
  for (const s of existingSections || []) {
    const id = (s && s.id && String(s.id).trim()) || '';
    if (id) byId.set(id, { id: s.id, title: s.title || '', content: s.content || '', icon: s.icon || '' });
  }
  for (const s of snippetSections || []) {
    const id = (s && s.id && String(s.id).trim()) || '';
    if (id && !byId.has(id)) {
      byId.set(id, { id: s.id, title: s.title || '', content: s.content || '', icon: s.icon || '' });
    }
  }
  // Immer fehlende Pflicht-Snippets (z. B. Kontoauszug) ergänzen
  for (const fallback of REQUIRED_SNIPPETS_FALLBACK) {
    const id = (fallback && fallback.id && String(fallback.id).trim()) || '';
    if (id && !byId.has(id)) byId.set(id, { id: fallback.id, title: fallback.title || '', content: fallback.content || '', icon: fallback.icon || '' });
  }
  return Array.from(byId.values());
}

async function createTermsContent(payload) {
  const body = {
    version: payload.version,
    language: payload.language,
    documentType: payload.documentType,
    effectiveDate: { __type: 'Date', iso: payload.effectiveDate },
    sections: payload.sections,
    isActive: payload.isActive === true
  };
  const result = await callParse('POST', '/classes/TermsContent', body, true);
  return result;
}

async function main() {
  loadEnvFromFile();
  if (!PARSE_MASTER_KEY) {
    console.error('PARSE_MASTER_KEY (or PARSE_SERVER_MASTER_KEY) is required. Set env or add to parse-server/.env');
    process.exit(1);
  }

  console.log('Legal Snippets Seed – documentType=%s, language=%s', DOCUMENT_TYPE, LANGUAGE);
  console.log('Fetching current active TermsContent and default snippet sections...');

  const [current, defaultSnippets] = await Promise.all([
    getCurrentTerms(LANGUAGE, DOCUMENT_TYPE),
    getDefaultSnippetSections(LANGUAGE)
  ]);

  const existingSections = (current && current.sections) || [];
  const merged = mergeSections(existingSections, defaultSnippets);
  const addedCount = merged.length - existingSections.length;
  const missingRequired = REQUIRED_SNIPPET_IDS.filter((id) => !existingSections.some((s) => (s && s.id && String(s.id).trim()) === id));

  if (addedCount === 0 && existingSections.length > 0) {
    if (missingRequired.length > 0) {
      console.log('Adding missing required snippet(s):', missingRequired.join(', '));
    } else {
      console.log('All snippet sections already present in current version. Nothing to do.');
      return;
    }
  }
  if (addedCount === 0 && missingRequired.length === 0) {
    console.log('All snippet sections already present in current version. Nothing to do.');
    return;
  }

  const version = current
    ? `${(current.version || '1.0').trim()}-snippets`
    : '1.0-legal-snippets';
  const effectiveDate = new Date().toISOString();

  console.log('Creating new TermsContent version: %s with %d sections (%d new snippet sections).', version, merged.length, addedCount);

  const created = await createTermsContent({
    version,
    language: LANGUAGE,
    documentType: DOCUMENT_TYPE,
    effectiveDate,
    sections: merged,
    isActive: false
  });

  const newId = created.objectId;
  console.log('Created TermsContent objectId: %s', newId);
  console.log('In Admin Portal → AGB & Rechtstexte, open this version and click "Als aktiv setzen" to activate.');
}

main().catch((e) => {
  console.error('Error:', e.message || e);
  process.exit(1);
});
