#!/usr/bin/env node
'use strict';

/**
 * E2E smoke: retail role is immutable after POST /users (signup).
 *
 * 1. Sign up as trader
 * 2. saveOnboardingProgress with conflicting userRole → OPERATION_FORBIDDEN (119)
 * 3. saveOnboardingProgress with matching userRole → success
 * 4. PUT /users/:id role change → rejected (userBeforeSave)
 * 5. getUserMe → role unchanged
 *
 * Env: PARSE_URL / PARSE_SERVER_URL, PARSE_APP_ID (default fin1-app-id)
 * Optional: SMOKE_CLEANUP=1 + BA_PASSWORD → cleanupSignupRunUsers after run
 * Optional: PARSE_INSECURE_TLS=1 for self-signed iobox HTTPS
 */

const OPERATION_FORBIDDEN = 119;

function normalizeParseBase(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.endsWith('/parse') ? trimmed : `${trimmed}/parse`;
}

async function parseRequest({
  parseBase,
  appId,
  sessionToken,
  method,
  path,
  body,
  expectError = false,
}) {
  const headers = {
    'Content-Type': 'application/json',
    'X-Parse-Application-Id': appId,
  };
  if (sessionToken) headers['X-Parse-Session-Token'] = sessionToken;

  const response = await fetch(`${parseBase}${path}`, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  });
  const json = await response.json().catch(() => ({}));
  const failed = !response.ok || json.error;

  if (expectError) {
    if (!failed) {
      throw new Error(`Expected error for ${method} ${path}, got OK: ${JSON.stringify(json)}`);
    }
    return { json, status: response.status, error: json.error || json };
  }

  if (failed) {
    throw new Error(`Parse ${method} ${path} failed (${response.status}): ${JSON.stringify(json.error || json)}`);
  }
  return { json, status: response.status };
}

async function cloudFunction(parseBase, appId, sessionToken, name, params = {}, expectError = false) {
  const { json, error } = await parseRequest({
    parseBase,
    appId,
    sessionToken,
    method: 'POST',
    path: `/functions/${name}`,
    body: params,
    expectError,
  });
  if (expectError) return { error };
  return json.result;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL || process.env.PARSE_URL);
  const appId = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
  if (!parseBase) {
    console.error('FAIL: set PARSE_URL or PARSE_SERVER_URL');
    process.exit(2);
  }

  const runId = process.env.SMOKE_RUN_ID || String(Date.now());
  const email = `signup+role-smoke-${runId}@test.com`;
  const username = `rsmoke${String(runId).slice(-8)}`;
  const password = process.env.SMOKE_SIGNUP_PASSWORD || 'LoadTestSignup1!';
  const customerNumber = `RS${String(runId).slice(-10)}`.slice(0, 16);

  console.log('=== smoke-signup-role-immutability ===');
  console.log(`  parseBase=${parseBase}`);
  console.log(`  email=${email}`);

  const signUpBody = {
    username,
    password,
    email,
    role: 'trader',
    customerNumber,
    accountType: 'individual',
    status: 'active',
    onboardingCompleted: false,
    onboardingStep: 'accountCreated',
    kycStatus: 'pending',
    isEmailVerified: false,
    isPhoneVerified: false,
    salutation: 'mr',
    dateOfBirth: '1990-01-15',
    isNotUSCitizen: true,
    acceptedTerms: true,
    acceptedPrivacyPolicy: true,
  };

  const { json: signUpJson } = await parseRequest({
    parseBase,
    appId,
    method: 'POST',
    path: '/users',
    body: signUpBody,
  });

  const sessionToken = signUpJson.sessionToken;
  const objectId = signUpJson.objectId;
  assert(sessionToken, 'signUp missing sessionToken');
  assert(objectId, 'signUp missing objectId');

  const meAfterSignUp = await cloudFunction(parseBase, appId, sessionToken, 'getUserMe');
  assert(meAfterSignUp?.role === 'trader', `signUp role expected trader, got ${meAfterSignUp?.role}`);
  console.log('  OK signUp: role=trader');

  const { error: blobError } = await cloudFunction(
    parseBase,
    appId,
    sessionToken,
    'saveOnboardingProgress',
    {
      step: 'welcome',
      partial: true,
      data: {
        userRole: 'investor',
        registrationMarker: `role-smoke-${runId}`,
      },
    },
    true,
  );
  const blobCode = typeof blobError === 'object'
    ? (blobError?.code ?? blobError?.error?.code)
    : undefined;
  const blobMessage = typeof blobError === 'string'
    ? blobError
    : String(blobError?.error ?? blobError?.message ?? '');
  assert(
    blobCode === OPERATION_FORBIDDEN || /role cannot be changed/i.test(blobMessage),
    `saveOnboardingProgress role mismatch: expected forbidden, got ${JSON.stringify(blobError)}`,
  );
  console.log('  OK saveOnboardingProgress rejects investor blob (119)');

  await cloudFunction(parseBase, appId, sessionToken, 'saveOnboardingProgress', {
    step: 'welcome',
    partial: true,
    data: {
      userRole: 'trader',
      registrationMarker: `role-smoke-ok-${runId}`,
    },
  });
  console.log('  OK saveOnboardingProgress accepts matching trader blob');

  const { error: putError } = await parseRequest({
    parseBase,
    appId,
    sessionToken,
    method: 'PUT',
    path: `/users/${objectId}`,
    body: { role: 'investor' },
    expectError: true,
  });
  const putCode = typeof putError === 'object'
    ? (putError?.code ?? putError?.error?.code)
    : undefined;
  const putMessage = typeof putError === 'string'
    ? putError
    : String(putError?.error ?? putError?.message ?? '');
  assert(
    putCode === OPERATION_FORBIDDEN || /role cannot be changed/i.test(putMessage),
    `PUT /users role change: expected forbidden, got ${JSON.stringify(putError)}`,
  );
  console.log('  OK PUT /users rejects investor role change (119)');

  const me = await cloudFunction(parseBase, appId, sessionToken, 'getUserMe');
  assert(me?.role === 'trader', `getUserMe role expected trader, got ${me?.role}`);
  console.log('  OK getUserMe: role still trader');

  if (process.env.SMOKE_CLEANUP === '1' && process.env.BA_PASSWORD) {
    const adminEmail = process.env.SMOKE_ADMIN_EMAIL || 'admin@fin1.de';
    const login = await parseRequest({
      parseBase,
      appId,
      method: 'POST',
      path: '/login',
      body: { username: adminEmail, password: process.env.BA_PASSWORD },
    });
    const adminToken = login.json.sessionToken;
    if (adminToken) {
      const cleanup = await cloudFunction(parseBase, appId, adminToken, 'cleanupSignupRunUsers', {
        dryRun: false,
        limit: 50,
      });
      console.log(`  OK cleanup: deleted=${cleanup?.deleted ?? '?'} matched=${cleanup?.matched ?? '?'}`);
    }
  } else {
    console.log(`  hint: SMOKE_CLEANUP=1 BA_PASSWORD=… to remove signup+ test users`);
  }

  console.log('');
  console.log('OK: signup role immutability smoke passed.');
}

main().catch((err) => {
  console.error('FAIL:', err.message);
  process.exit(1);
});
