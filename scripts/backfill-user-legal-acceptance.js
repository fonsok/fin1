#!/usr/bin/env node
// ============================================================================
// Backfill _User legal acceptance version fields for legacy seed users
// ============================================================================
// Sets acceptedTermsVersion / acceptedPrivacyPolicyVersion when user accepted
// flags are true but version columns are missing.
//
// Usage:
//   node scripts/backfill-user-legal-acceptance.js
//   BACKFILL_LEGAL_VERSION=1.0.2 node scripts/backfill-user-legal-acceptance.js
//   BACKFILL_USER_EMAIL=investor5@test.com node scripts/backfill-user-legal-acceptance.js
// ============================================================================

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

let PARSE_SERVER_URL = process.env.PARSE_SERVER_URL || 'http://localhost:1337/parse';
let PARSE_APP_ID = process.env.PARSE_APP_ID || 'fin1-app-id';
let PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || '';
const TARGET_VERSION = (process.env.BACKFILL_LEGAL_VERSION || '1.0.2').trim();
const FILTER_EMAIL = (process.env.BACKFILL_USER_EMAIL || '').trim().toLowerCase();

function loadEnvFromFile() {
  const candidates = [
    path.join(__dirname, '../backend/parse-server/.env'),
    path.join(__dirname, '../backend/.env'),
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
    const u = getVal('PARSE_SERVER_PUBLIC_SERVER_URL') || getVal('PARSE_SERVER_URL');
    if (u) PARSE_SERVER_URL = u.replace(/\/parse\/?$/, '') + '/parse';
    PARSE_APP_ID = getVal('PARSE_SERVER_APPLICATION_ID') || getVal('PARSE_APP_ID') || PARSE_APP_ID;
    if (PARSE_MASTER_KEY) break;
  }
}

function callParse(method, apiPath, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(PARSE_SERVER_URL + apiPath);
    const client = url.protocol === 'https:' ? https : http;
    const postData = body ? JSON.stringify(body) : '';
    const req = client.request({
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Parse-Application-Id': PARSE_APP_ID,
        'X-Parse-Master-Key': PARSE_MASTER_KEY,
        ...(postData && { 'Content-Length': Buffer.byteLength(postData) }),
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data || '{}');
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(json);
          else reject(new Error(json.error?.message || `HTTP ${res.statusCode}: ${data}`));
        } catch (e) {
          reject(new Error(data));
        }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function fetchUsers() {
  const where = FILTER_EMAIL
    ? { email: FILTER_EMAIL }
    : {
      $or: [
        { acceptedTerms: true, acceptedTermsVersion: { $exists: false } },
        { acceptedTerms: true, acceptedTermsVersion: '' },
        { acceptedPrivacyPolicy: true, acceptedPrivacyPolicyVersion: { $exists: false } },
        { acceptedPrivacyPolicy: true, acceptedPrivacyPolicyVersion: '' },
      ],
    };

  const results = [];
  let skip = 0;
  const limit = 100;
  for (;;) {
    const encoded = encodeURIComponent(JSON.stringify(where));
    const page = await callParse('GET', `/classes/_User?where=${encoded}&limit=${limit}&skip=${skip}`);
    const rows = page.results || [];
    results.push(...rows);
    if (rows.length < limit) break;
    skip += limit;
  }
  return results;
}

async function main() {
  loadEnvFromFile();
  if (!PARSE_MASTER_KEY) {
    console.error('PARSE_MASTER_KEY required');
    process.exit(1);
  }

  const users = await fetchUsers();
  console.log('Found %d user(s) to inspect', users.length);

  let updated = 0;
  for (const user of users) {
    const patch = {};
    const now = { __type: 'Date', iso: new Date().toISOString() };

    if (user.acceptedTerms === true && !String(user.acceptedTermsVersion || '').trim()) {
      patch.acceptedTermsVersion = TARGET_VERSION;
      if (!user.acceptedTermsDate) patch.acceptedTermsDate = now;
    }
    if (user.acceptedPrivacyPolicy === true && !String(user.acceptedPrivacyPolicyVersion || '').trim()) {
      patch.acceptedPrivacyPolicyVersion = TARGET_VERSION;
      if (!user.acceptedPrivacyPolicyDate) patch.acceptedPrivacyPolicyDate = now;
    }

    if (!Object.keys(patch).length) continue;

    await callParse('PUT', `/classes/_User/${user.objectId}`, patch);
    updated += 1;
    console.log('Updated %s (%s): %j', user.email || user.username || user.objectId, user.objectId, patch);
  }

  console.log('Backfill complete. Updated %d user(s) to version %s.', updated, TARGET_VERSION);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
