#!/usr/bin/env node
/**
 * Seeds company investor test users (KYB draft / pending / approved).
 *
 * Usage:
 *   node backend/scripts/seed-company-test-users.js
 *   PARSE_SERVER_URL=https://127.0.0.1:8443/parse PARSE_MASTER_KEY=... node backend/scripts/seed-company-test-users.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

[
  path.join(__dirname, '../../scripts/.env.server'),
  path.join(__dirname, '../parse-server/.env'),
  path.join(__dirname, '../.env'),
].forEach((filePath) => {
  if (!fs.existsSync(filePath)) return;
  for (const line of fs.readFileSync(filePath, 'utf8').split('\n')) {
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
});

let PARSE_SERVER_URL = (process.env.PARSE_SERVER_URL || process.env.PARSE_URL || 'http://127.0.0.1:1337/parse').replace(/\/$/, '');
if (!PARSE_SERVER_URL.endsWith('/parse')) PARSE_SERVER_URL += '/parse';
const PARSE_APP_ID = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
const PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || process.env.PARSE_SERVER_MASTER_KEY || '';

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
        let parsed;
        try { parsed = data ? JSON.parse(data) : {}; } catch { parsed = { raw: data }; }
        if (res.statusCode >= 400) {
          reject(new Error(`HTTP ${res.statusCode}: ${parsed.error || data}`));
          return;
        }
        resolve(parsed);
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function main() {
  console.log(`Seeding company test users via ${PARSE_SERVER_URL}/functions/seedCompanyTestUsers …`);
  const result = await callParse('POST', '/functions/seedCompanyTestUsers', {});
  console.log(JSON.stringify(result, null, 2));
  console.log('\nLogin (iOS DEBUG landing):');
  for (const u of result.result?.users || result.users || []) {
    console.log(`  ${u.email}  →  KYB: ${u.companyKybStatus}`);
  }
  console.log(`  Password: TestPassword123! (TestConstants.password)`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
