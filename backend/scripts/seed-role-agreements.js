#!/usr/bin/env node
/**
 * Seeds active TermsContent versions for trader_agreement and investor_agreement (DE).
 *
 * Usage:
 *   node backend/scripts/seed-role-agreements.js
 *   PARSE_SERVER_URL=http://127.0.0.1:1337/parse PARSE_MASTER_KEY=... node backend/scripts/seed-role-agreements.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

let PARSE_SERVER_URL = process.env.PARSE_SERVER_URL
  || process.env.PARSE_URL
  || process.env.PARSE_SERVER_PUBLIC_SERVER_URL
  || 'http://127.0.0.1:1337/parse';
let PARSE_APP_ID = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
let PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || process.env.PARSE_SERVER_MASTER_KEY || '';

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const text = fs.readFileSync(filePath, 'utf8');
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = value;
  }
}

[
  path.join(__dirname, '../../scripts/.env.server'),
  path.join(__dirname, '../parse-server/.env'),
  path.join(__dirname, '../.env'),
].forEach(loadEnvFile);

PARSE_APP_ID = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || PARSE_APP_ID;
PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || process.env.PARSE_SERVER_MASTER_KEY || PARSE_MASTER_KEY;
PARSE_SERVER_URL = (process.env.PARSE_SERVER_URL || process.env.PARSE_URL || PARSE_SERVER_URL).replace(/\/$/, '');
if (!PARSE_SERVER_URL.endsWith('/parse')) {
  PARSE_SERVER_URL = `${PARSE_SERVER_URL}/parse`;
}

if (!PARSE_MASTER_KEY) {
  console.error('PARSE_MASTER_KEY is required');
  process.exit(1);
}

function callParse(method, apiPath, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${PARSE_SERVER_URL}${apiPath.startsWith('/') ? apiPath : `/${apiPath}`}`);
    const client = url.protocol === 'https:' ? https : http;
    const postData = body ? JSON.stringify(body) : '';
    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Parse-Application-Id': PARSE_APP_ID,
        'X-Parse-Master-Key': PARSE_MASTER_KEY,
      },
      rejectUnauthorized: false,
    };
    if (postData) options.headers['Content-Length'] = Buffer.byteLength(postData);

    const req = client.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data || '{}');
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(json);
          else reject(new Error(json.error || `HTTP ${res.statusCode}: ${data}`));
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

const TRADER_SECTIONS = [
  {
    id: 'trader_freistellung',
    title: '1. Freistellung des App-Betreibers',
    content:
      'Der Trader stellt den App-Betreiber von allen Ansprüchen Dritter frei, die durch eine missbräuchliche oder gesetzeswidrige Nutzung seines Accounts entstehen.',
    icon: 'shield',
  },
  {
    id: 'trader_regulatorisch',
    title: '2. Regulatorischer Vorbehalt (Sperrklausel)',
    content:
      'Der App-Betreiber behält sich das Recht vor, das Konto des Traders ohne Angabe von Gründen temporär oder dauerhaft zu sperren, falls regulatorische Behörden (z. B. BaFin, ESMA) dies fordern oder sich die Lizenzanforderungen für die App ändern.',
    icon: 'exclamationmark.shield',
  },
  {
    id: 'trader_vertragsaenderung',
    title: '3. Recht auf einseitige Vertragsänderung',
    content:
      'Änderungen dieser Vereinbarung werden dem Trader mindestens vier Wochen im Voraus in der App angekündigt. Bei kritischen Updates blockiert die App das Platzieren neuer Trades, bis der Trader den geänderten Bedingungen aktiv zustimmt.',
    icon: 'doc.badge.gearshape',
  },
  {
    id: 'trader_status',
    title: '4. Vertragsgegenstand & Status des Traders',
    content:
      'Der Trader agiert ausschließlich als privater Signalgeber / unabhängiger Creator für sein eigenes, privates Depot. Es wird ausdrücklich vereinbart, dass der Trader keine Anlageberatung, keine Finanzportfolioverwaltung und keine Anlagevermittlung für Dritte erbringt.',
    icon: 'person.crop.circle',
  },
  {
    id: 'trader_blind_execution',
    title: '5. Blind-Execution-Klausel',
    content:
      'Der Trader erteilt der App die Erlaubnis, seine getätigten Orders nach deren vollständiger Ausführung (Post-Trade) anonymisiert zu Replikationszwecken auszulesen. Der Trader hat zu keinem Zeitpunkt vor oder während der Orderplatzierung Einblick in das potenzielle Pool-Mirror-Volumen oder die Anzahl der beteiligten Investoren. Nach Platzierung einer Kauf-Order wird ihm nur angezeigt, ob Pool-Mirror-Trade „aktiv“ ist.\n\nDem Trader ist es untersagt, Orders gezielt mit dem Zweck zu platzieren, Kurse zu beeinflussen (Marktmanipulation). Er darf keine Absprachen mit Dritten treffen und seine Trades nicht vorab auf anderen Kanälen ankündigen, um Follower als Liquidität zu nutzen.',
    icon: 'eye.slash',
  },
  {
    id: 'trader_haftung',
    title: '6. Haftungsausschluss',
    content:
      'Der Trader übernimmt keine Gewähr oder Haftung für die Performance seiner Handelsstrategie. Der Investor kopiert den Trader via Pool-Mirror-Trade auf eigenes Risiko. Der Trader kann von Investoren oder der App nicht für Verluste (Drawdowns) haftbar gemacht werden.',
    icon: 'hand.raised.slash',
  },
  {
    id: 'trader_verguetung',
    title: '7. Vergütung (Performance Fee)',
    content:
      'Der Trader erhält eine Erfolgsbeteiligung in Höhe von derzeit {{TRADER_PERFORMANCE_FEE_RATE}} des realisierten Nettogewinns des Pool-Mirror-Trades. Die Abrechnung erfolgt automatisiert über die App.',
    icon: 'percent',
  },
];

const INVESTOR_SECTIONS = [
  {
    id: 'investor_freistellung',
    title: '1. Freistellung des App-Betreibers',
    content:
      'Der Investor stellt den App-Betreiber von allen Ansprüchen Dritter frei, die durch eine missbräuchliche oder gesetzeswidrige Nutzung seines Accounts entstehen.',
    icon: 'shield',
  },
  {
    id: 'investor_regulatorisch',
    title: '2. Regulatorischer Vorbehalt (Sperrklausel)',
    content:
      'Der App-Betreiber behält sich das Recht vor, das Konto des Investors ohne Angabe von Gründen temporär oder dauerhaft zu sperren, falls regulatorische Behörden (z. B. BaFin, ESMA) dies fordern oder sich die Lizenzanforderungen für die App ändern.',
    icon: 'exclamationmark.shield',
  },
  {
    id: 'investor_vertragsaenderung',
    title: '3. Recht auf einseitige Vertragsänderung',
    content:
      'Änderungen dieser Vereinbarung werden dem Investor mindestens vier Wochen im Voraus in der App angekündigt. Bei kritischen Updates blockiert die App das Platzieren neuer Investments, bis der Investor den geänderten Bedingungen aktiv zustimmt.',
    icon: 'doc.badge.gearshape',
  },
  {
    id: 'investor_mandat',
    title: '4. Erteilung des Verwaltungsmandats',
    content:
      'Der Investor bevollmächtigt die App (und das dahinterstehende Haftungsdach {{LEGAL_COMPANY_LEGAL_NAME}}), Kauf- und Verkaufsorders auf sein jeweils reserviertes Investment (Pool-Mirror-Volumen-Anteil) vollautomatisch und ohne vorherige Einzelfreigabe auszuführen, sobald ein vom Investor ausgewählter Trader (Signalgeber) eine Order ausführt.',
    icon: 'signature',
  },
  {
    id: 'investor_gebuehren',
    title: '5. Gebührenstruktur',
    content:
      'Volumengebühr: {{INVESTOR_VOLUME_FEE_RATE}} des für den Pool-Mirror-Trade reservierten Investmentvolumens (sofort pro Transaktion). Bei Stoppen reservierter Investments wird die Volumengebühr nicht zurückerstattet.\n\nErfolgsgebühr (Performance Fee): derzeit {{INVESTOR_PERFORMANCE_FEE_RATE}} auf realisierte Gewinne.',
    icon: 'eurosign.circle',
  },
  {
    id: 'investor_latenz',
    title: '6. Technische Risikoaufklärung & Latenz',
    content:
      'Der Investor wird darüber aufgeklärt, dass es aufgrund von Marktbedingungen, Liquiditätsengpässen und technischer Datenübertragung zu Verzögerungen (Slippage) kommen kann. Einstands- und Verkaufspreis können minimal vom Signalgeber abweichen.',
    icon: 'clock.arrow.circlepath',
  },
  {
    id: 'investor_schutz',
    title: '7. Risikomanagement & Instant-Opt-Out',
    content:
      'Der Investor kann reservierte Investments jederzeit mit einem Klick stoppen (Instant-Opt-Out). Bereits aktive Pool-Mirror-Beteiligungen können nicht gestoppt werden. Das Totalverlustrisiko kann durch Verteilung des Investmentvolumens auf bis zu 10 aufeinanderfolgende Trades eines Traders zu gleichen Teilen begrenzt werden.',
    icon: 'hand.raised',
  },
];

async function findActiveRows(documentType, language) {
  const where = encodeURIComponent(JSON.stringify({
    documentType,
    language,
    isActive: true,
  }));
  const result = await callParse('GET', `/classes/TermsContent?where=${where}&limit=20`);
  return result.results || [];
}

async function deactivateExisting(documentType, language) {
  const rows = await findActiveRows(documentType, language);
  for (const row of rows) {
    await callParse('PUT', `/classes/TermsContent/${row.objectId}`, { isActive: false });
  }
}

async function createVersion({ documentType, language, version, sections }) {
  const result = await callParse('POST', '/classes/TermsContent', {
    documentType,
    language,
    version,
    effectiveDate: { __type: 'Date', iso: new Date().toISOString() },
    isActive: true,
    sections,
  });
  return result.objectId;
}

async function main() {
  const version = process.env.ROLE_AGREEMENT_VERSION || '1.0';
  console.log(`Seeding role agreements → ${PARSE_SERVER_URL} (v${version})`);

  for (const spec of [
    { documentType: 'trader_agreement', sections: TRADER_SECTIONS },
    { documentType: 'investor_agreement', sections: INVESTOR_SECTIONS },
  ]) {
    await deactivateExisting(spec.documentType, 'de');
    const objectId = await createVersion({
      documentType: spec.documentType,
      language: 'de',
      version,
      sections: spec.sections,
    });
    console.log(`Created active ${spec.documentType}/de v${version}: ${objectId}`);
  }

  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
