#!/usr/bin/env node

/**
 * Script to create CSR users for admin portal access
 * Usage: node create_csr_users.js
 */

const https = require('https');
const http = require('http');

const PARSE_SERVER_URL = process.env.PARSE_SERVER_URL || 'http://localhost:1337/parse';
const PARSE_APP_ID = process.env.PARSE_APP_ID || 'fin1-app-id';
const PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY || '';

// CSR Users to create
const CSR_USERS = [
  { email: 'L1@fin1.de', password: 'L1Secure2024!', firstName: 'Lisa', lastName: 'Level-1' },
  { email: 'L2@fin1.de', password: 'L2Secure2024!', firstName: 'Lars', lastName: 'Level-2' },
  { email: 'Fraud@fin1.de', password: 'FraudSecure2024!', firstName: 'Frank', lastName: 'Fraud-Analyst' },
  { email: 'Compliance@fin1.de', password: 'ComplianceSecure2024!', firstName: 'Claudia', lastName: 'Compliance' },
  { email: 'Tech@fin1.de', password: 'TechSecure2024!', firstName: 'Tim', lastName: 'Tech-Support' },
  { email: 'Lead@fin1.de', password: 'LeadSecure2024!', firstName: 'Tanja', lastName: 'Teamlead' },
];

/**
 * Call Parse Cloud Function
 */
function callCloudFunction(functionName, params, masterKey) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${PARSE_SERVER_URL}/functions/${functionName}`);
    const isHttps = url.protocol === 'https:';
    const client = isHttps ? https : http;

    const postData = JSON.stringify(params);
    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'X-Parse-Application-Id': PARSE_APP_ID,
        ...(masterKey && { 'X-Parse-Master-Key': masterKey }),
      },
    };

    const req = client.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(result.result || result);
          } else {
            reject(new Error(result.error || `HTTP ${res.statusCode}: ${data}`));
          }
        } catch (e) {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      });
    });

    req.on('error', (e) => {
      reject(e);
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Login as admin to get session token
 */
async function loginAsAdmin() {
  // Try to login with a known admin account or use master key
  // For now, we'll use master key directly
  return null;
}

/**
 * Create CSR users
 */
async function createCSRUsers() {
  console.log('🚀 Erstelle CSR Users...\n');

  // Read master key from environment or .env file
  let masterKey = PARSE_MASTER_KEY;
  if (!masterKey) {
    // Try to read from .env file
    try {
      const fs = require('fs');
      const envPath = require('path').join(__dirname, '../parse-server/.env');
      if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8');
        const match = envContent.match(/PARSE_MASTER_KEY=(.+)/);
        if (match) {
          masterKey = match[1].trim();
        }
      }
    } catch (e) {
      console.warn('⚠️  Konnte Master Key nicht aus .env lesen');
    }
  }

  if (!masterKey) {
    console.error('❌ PARSE_MASTER_KEY nicht gefunden. Bitte setzen Sie die Umgebungsvariable oder .env Datei.');
    process.exit(1);
  }

  const results = [];

  for (const user of CSR_USERS) {
    try {
      console.log(`📧 Erstelle User: ${user.email}...`);
      const result = await callCloudFunction('createCSRUser', {
        email: user.email,
        password: user.password,
        firstName: user.firstName,
        lastName: user.lastName,
      }, masterKey);

      if (result.success) {
        console.log(`  ✅ ${result.message}`);
        results.push({ email: user.email, status: 'created', csrSubRole: result.user?.csrSubRole });
      } else {
        console.log(`  ⚠️  ${result.message}`);
        results.push({ email: user.email, status: 'exists', csrSubRole: result.user?.csrSubRole });
      }
    } catch (error) {
      console.error(`  ❌ Fehler: ${error.message}`);
      results.push({ email: user.email, status: 'error', error: error.message });
    }
  }

  console.log('\n📊 Zusammenfassung:');
  console.log('==================');
  results.forEach((r) => {
    const icon = r.status === 'created' ? '✅' : r.status === 'exists' ? '⚠️' : '❌';
    console.log(`${icon} ${r.email} - ${r.status}${r.csrSubRole ? ` (${r.csrSubRole})` : ''}`);
  });

  const created = results.filter((r) => r.status === 'created').length;
  const exists = results.filter((r) => r.status === 'exists').length;
  const errors = results.filter((r) => r.status === 'error').length;

  console.log(`\n✅ Erstellt: ${created}`);
  console.log(`⚠️  Bereits vorhanden: ${exists}`);
  if (errors > 0) {
    console.log(`❌ Fehler: ${errors}`);
  }
}

// Run
createCSRUsers().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
