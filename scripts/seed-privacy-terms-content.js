#!/usr/bin/env node
// ============================================================================
// Seed active Privacy Policy TermsContent (de/en) from exported Swift sections
// ============================================================================
// Usage:
//   node scripts/seed-privacy-terms-content.js
//   SEED_PRIVACY_VERSION=1.0.2 node scripts/seed-privacy-terms-content.js
//
// Reads PARSE_* from backend/parse-server/.env when not set in environment.
// Creates privacy de/en at the configured version and activates them.
// ============================================================================

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

let PARSE_SERVER_URL = process.env.PARSE_SERVER_URL || process.env.PARSE_SERVER_PUBLIC_SERVER_URL || 'http://localhost:1337/parse';
let PARSE_APP_ID = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
let PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || process.env.PARSE_SERVER_MASTER_KEY || '';
const TARGET_VERSION = (process.env.SEED_PRIVACY_VERSION || '1.0.2').trim();
const GENERATED_DIR = path.join(__dirname, 'generated');

function loadEnvFromFile() {
  const candidates = [
    path.join(__dirname, '../backend/parse-server/.env'),
    path.join(__dirname, '../backend/.env'),
    path.join(__dirname, '../.env'),
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
    if (!PARSE_APP_ID || PARSE_APP_ID === 'fin1-app-id') {
      PARSE_APP_ID = getVal('PARSE_SERVER_APPLICATION_ID') || getVal('PARSE_APP_ID') || PARSE_APP_ID;
    }
    if (PARSE_MASTER_KEY) break;
  }
}

function callParse(method, apiPath, body, useMasterKey) {
  return new Promise((resolve, reject) => {
    const url = new URL(PARSE_SERVER_URL + (apiPath.startsWith('/') ? apiPath : '/' + apiPath));
    const isHttps = url.protocol === 'https:';
    const client = isHttps ? https : http;
    const postData = body ? JSON.stringify(body) : '';
    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Parse-Application-Id': PARSE_APP_ID,
        ...(useMasterKey && PARSE_MASTER_KEY && { 'X-Parse-Master-Key': PARSE_MASTER_KEY }),
      },
    };
    if (postData) options.headers['Content-Length'] = Buffer.byteLength(postData);
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

async function queryTermsContent(where) {
  const encoded = encodeURIComponent(JSON.stringify(where));
  const result = await callParse('GET', `/classes/TermsContent?where=${encoded}&limit=5`, null, true);
  return result.results || [];
}

async function deactivateActivePrivacy(language) {
  const rows = await queryTermsContent({
    documentType: 'privacy',
    language,
    isActive: true,
  });
  for (const row of rows) {
    if (row.documentType !== 'privacy') {
      console.warn('  Skip deactivate (not privacy): objectId=%s type=%s', row.objectId, row.documentType);
      continue;
    }
    await callParse('PUT', `/classes/TermsContent/${row.objectId}`, { isActive: false }, true);
    console.log('  Deactivated privacy %s objectId=%s version=%s', language, row.objectId, row.version);
  }
}

async function activateTermsContent(objectId) {
  await callParse('PUT', `/classes/TermsContent/${objectId}`, { isActive: true }, true);
}

async function createPrivacy(language, sections) {
  await deactivateActivePrivacy(language);
  const effectiveDate = { __type: 'Date', iso: new Date().toISOString() };
  const created = await callParse('POST', '/classes/TermsContent', {
    version: TARGET_VERSION,
    language,
    documentType: 'privacy',
    effectiveDate,
    sections,
    isActive: true,
    archived: false,
  }, true);
  console.log('Created privacy %s objectId=%s version=%s (%d sections)', language, created.objectId, TARGET_VERSION, sections.length);
  return created.objectId;
}

async function upsertPrivacy(language, sections) {
  const active = await queryTermsContent({
    documentType: 'privacy',
    language,
    isActive: true,
    version: TARGET_VERSION,
  });

  if (active.length > 0) {
    console.log('Active privacy %s version=%s already present (objectId=%s)', language, TARGET_VERSION, active[0].objectId);
    return active[0].objectId;
  }

  const inactiveSameVersion = await queryTermsContent({
    documentType: 'privacy',
    language,
    version: TARGET_VERSION,
  });
  if (inactiveSameVersion.length > 0) {
    const objectId = inactiveSameVersion[0].objectId;
    await deactivateActivePrivacy(language);
    await activateTermsContent(objectId);
    console.log('Reactivated privacy %s objectId=%s version=%s', language, objectId, TARGET_VERSION);
    return objectId;
  }

  return createPrivacy(language, sections);
}

function loadPrivacyPayload(language) {
  const filePath = path.join(GENERATED_DIR, `privacy_${language}.json`);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing ${filePath}. Run: python3 scripts/export_legal_sections_from_swift.py --out-dir scripts/generated`);
  }
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  return {
    sections: raw.sections || [],
  };
}

function patchVersionInSections(sections) {
  return (sections || []).map((section) => {
    if (!section || typeof section.content !== 'string') return section;
    const content = section.content
      .replace(/Version 1\.0\b/g, `Version ${TARGET_VERSION}`)
      .replace(/Version 1\.0\.0\b/g, `Version ${TARGET_VERSION}`);
    return { ...section, content };
  });
}

async function main() {
  loadEnvFromFile();
  if (!PARSE_MASTER_KEY) {
    console.error('PARSE_MASTER_KEY is required.');
    process.exit(1);
  }

  console.log('Seeding privacy TermsContent version=%s on %s', TARGET_VERSION, PARSE_SERVER_URL);

  for (const language of ['de', 'en']) {
    const { sections } = loadPrivacyPayload(language);
    if (!sections.length) {
      throw new Error(`No sections in privacy_${language}.json`);
    }
    await upsertPrivacy(language, patchVersionInSections(sections));
  }

  console.log('Done. Verify with getCurrentTerms(documentType=privacy, language=de).');
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});
