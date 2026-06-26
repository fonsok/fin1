#!/usr/bin/env node
'use strict';

/**
 * Load test: parallel signup users + saveOnboardingProgress burst (signup hot path).
 *
 * Creates users with mailbox signup+{runId}+{n}@test.com (cleanupSignupRunUsers compatible).
 *
 * Required env:
 *   PARSE_SERVER_URL or PARSE_URL  (e.g. https://192.168.178.20/parse)
 *   PARSE_APP_ID                   (default fin1-app-id)
 *
 * Optional:
 *   LOAD_TEST_USERS        (default 20)   — virtual users to simulate
 *   LOAD_TEST_CONCURRENCY  (default 10)   — parallel workers
 *   LOAD_TEST_SAVES_PER_USER (default 14) — saveOnboardingProgress calls per user
 *   LOAD_TEST_ROLE         investor|trader (default investor)
 *   LOAD_TEST_PASSWORD     (default LoadTestSignup1!)
 *   LOAD_TEST_RUN_ID       (default timestamp)
 *   LOAD_TEST_CLEANUP      1 — admin cleanup after run (needs BA_PASSWORD + server flags)
 *   PARSE_INSECURE_TLS     1 — allow self-signed HTTPS (default in wrapper for iobox)
 *
 * For realistic backend load (bypass nginx TLS/front door), run on the Parse host:
 *   ssh io@192.168.178.20 'cd ~/fin1-server && PARSE_URL=http://127.0.0.1:1338/parse node scripts/load-test-signup-onboarding.js'
 *   BA_PASSWORD            — for cleanup only
 *   SMOKE_ADMIN_EMAIL      — default admin@fin1.de
 *
 * Example:
 *   PARSE_URL=https://192.168.178.20/parse node scripts/load-test-signup-onboarding.js
 *   LOAD_TEST_USERS=50 LOAD_TEST_CONCURRENCY=25 node scripts/load-test-signup-onboarding.js
 */

function normalizeParseBase(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.endsWith('/parse') ? trimmed : `${trimmed}/parse`;
}

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[Math.max(0, idx)];
}

async function parseRequest({
  parseBase,
  appId,
  sessionToken,
  method,
  path,
  body,
  retries = 3,
}) {
  const headers = {
    'Content-Type': 'application/json',
    'X-Parse-Application-Id': appId,
  };
  if (sessionToken) headers['X-Parse-Session-Token'] = sessionToken;

  let lastError;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    const started = Date.now();
    try {
      const response = await fetch(`${parseBase}${path}`, {
        method,
        headers,
        body: body != null ? JSON.stringify(body) : undefined,
      });
      const json = await response.json().catch(() => ({}));
      const durationMs = Date.now() - started;

      if (!response.ok || json.error) {
        const detail = json.error || json;
        const retryable = response.status === 429 || response.status === 502 || response.status === 503;
        if (retryable && attempt < retries) {
          await new Promise((resolve) => setTimeout(resolve, 150 * attempt));
          continue;
        }
        const err = new Error(`Parse ${method} ${path} failed (${response.status}): ${JSON.stringify(detail)}`);
        err.durationMs = durationMs;
        throw err;
      }
      return { json, durationMs };
    } catch (err) {
      lastError = err;
      const retryable = err.message === 'fetch failed' || /failed \((502|503|429)\)/.test(err.message);
      if (retryable && attempt < retries) {
        await new Promise((resolve) => setTimeout(resolve, 150 * attempt));
        continue;
      }
      throw err;
    }
  }
  throw lastError;
}

async function cloudFunction(parseBase, appId, sessionToken, name, params = {}) {
  const { json, durationMs } = await parseRequest({
    parseBase,
    appId,
    sessionToken,
    method: 'POST',
    path: `/functions/${name}`,
    body: params,
  });
  return { result: json.result, durationMs };
}

async function signUpUser(parseBase, appId, body) {
  const { json, durationMs } = await parseRequest({
    parseBase,
    appId,
    method: 'POST',
    path: '/users',
    body,
  });
  return { user: json, durationMs };
}

/** Steps that mirror a fast signup navigation (partial saves). */
const SAVE_STEPS = [
  'welcome',
  'contact',
  'accountCreated',
  'personalInfo',
  'citizenshipTax',
  'identificationType',
  'addressConfirm',
  'financial',
  'experience',
  'desiredReturn',
  'nonInsiderDeclaration',
  'moneyLaunderingDeclaration',
  'terms',
  'summary',
];

function buildSavePayload(step, role, marker) {
  const base = {
    userRole: role,
    registrationMarker: marker,
    accountType: 'individual',
  };
  if (step === 'financial') {
    return {
      ...base,
      employmentStatus: 'employed',
      incomeRange: 'high',
      cashAndLiquidAssets: 'over_100k',
    };
  }
  if (step === 'experience') {
    return {
      ...base,
      stocksTransactionsCount: '50+',
      stocksInvestmentAmount: 'ten_thousand_to_hundred_thousand',
    };
  }
  if (step === 'desiredReturn') {
    return { ...base, desiredReturn: 'up_to_ten_percent' };
  }
  return base;
}

async function simulateUser({
  parseBase,
  appId,
  index,
  runId,
  password,
  role,
  savesPerUser,
  saveDelayMs,
}) {
  const email = `signup+${runId}+${index}@test.com`;
  const username = `su${String(index).padStart(4, '0')}${String(runId).slice(-10)}`;
  const customerNumber = `LT${String(runId).slice(-6)}${String(index).padStart(4, '0')}`.slice(0, 16);
  const marker = `load-${runId}-${index}`;
  const timings = [];
  const errors = [];

  const signUpBody = {
    username,
    password,
    email,
    role,
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

  let sessionToken;
  try {
    const signUp = await signUpUser(parseBase, appId, signUpBody);
    timings.push({ op: 'signUp', ms: signUp.durationMs });
    sessionToken = signUp.user.sessionToken;
    if (!sessionToken) {
      throw new Error('signUp missing sessionToken');
    }
  } catch (err) {
    errors.push({ op: 'signUp', message: err.message });
    return { email, ok: false, timings, errors };
  }

  const steps = SAVE_STEPS.slice(0, Math.min(savesPerUser, SAVE_STEPS.length));
  for (let i = 0; i < savesPerUser; i += 1) {
    const step = steps[i % steps.length];
    const isPositionOnly = i > 0 && i % 5 === 0;
    const params = isPositionOnly
      ? { step, partial: true, data: { _positionOnly: true } }
      : {
        step,
        partial: true,
        data: buildSavePayload(step, role, marker),
      };

    try {
      const { durationMs } = await cloudFunction(
        parseBase,
        appId,
        sessionToken,
        'saveOnboardingProgress',
        params,
      );
      timings.push({ op: isPositionOnly ? 'savePosition' : 'saveProgress', step, ms: durationMs });
      if (saveDelayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, saveDelayMs));
      }
    } catch (err) {
      errors.push({ op: 'saveOnboardingProgress', step, message: err.message });
      if (String(err.message).includes('Too many onboarding save requests')) {
        break;
      }
    }
  }

  try {
    const { durationMs } = await cloudFunction(
      parseBase,
      appId,
      sessionToken,
      'getOnboardingProgress',
      {},
    );
    timings.push({ op: 'getOnboardingProgress', ms: durationMs });
  } catch (err) {
    errors.push({ op: 'getOnboardingProgress', message: err.message });
  }

  return {
    email,
    ok: errors.length === 0,
    saveCount: timings.filter((t) => t.op === 'saveProgress' || t.op === 'savePosition').length,
    timings,
    errors,
  };
}

async function runPool(items, concurrency, worker) {
  const results = [];
  let cursor = 0;
  const runners = Array.from({ length: concurrency }, async () => {
    while (cursor < items.length) {
      const idx = cursor;
      cursor += 1;
      results[idx] = await worker(items[idx], idx);
    }
  });
  await Promise.all(runners);
  return results;
}

async function adminCleanup(parseBase, appId, adminEmail, adminPassword) {
  const login = await parseRequest({
    parseBase,
    appId,
    method: 'POST',
    path: '/login',
    body: { username: adminEmail, password: adminPassword },
  });
  const token = login.json.sessionToken;
  if (!token) throw new Error('admin login failed for cleanup');

  const { result } = await cloudFunction(
    parseBase,
    appId,
    token,
    'cleanupSignupRunUsers',
    { dryRun: false, limit: 1000 },
  );
  return result;
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL || process.env.PARSE_URL);
  const appId = process.env.PARSE_APP_ID || process.env.PARSE_SERVER_APPLICATION_ID || 'fin1-app-id';
  if (!parseBase) {
    console.error('FAIL: set PARSE_SERVER_URL or PARSE_URL');
    process.exit(2);
  }

  const users = Math.max(1, Number(process.env.LOAD_TEST_USERS) || 20);
  const concurrency = Math.max(1, Number(process.env.LOAD_TEST_CONCURRENCY) || 10);
  const savesPerUser = Math.max(1, Number(process.env.LOAD_TEST_SAVES_PER_USER) || 14);
  const saveDelayMs = Math.max(0, Number(process.env.LOAD_TEST_SAVE_DELAY_MS) || 50);
  const role = process.env.LOAD_TEST_ROLE === 'trader' ? 'trader' : 'investor';
  const password = process.env.LOAD_TEST_PASSWORD || 'LoadTestSignup1!';
  const runId = process.env.LOAD_TEST_RUN_ID || String(Date.now());

  console.log('=== load-test-signup-onboarding ===');
  console.log(`  parseBase=${parseBase}`);
  console.log(`  users=${users} concurrency=${concurrency} savesPerUser=${savesPerUser} saveDelayMs=${saveDelayMs} role=${role}`);
  console.log(`  runId=${runId}`);

  const started = Date.now();
  const indices = Array.from({ length: users }, (_, i) => i + 1);
  const results = await runPool(indices, concurrency, (index) => simulateUser({
    parseBase,
    appId,
    index,
    runId,
    password,
    role,
    savesPerUser,
    saveDelayMs,
  }));

  const elapsedMs = Date.now() - started;
  const okCount = results.filter((r) => r.ok).length;
  const failCount = results.length - okCount;
  const allSaveMs = results.flatMap((r) => r.timings
    .filter((t) => t.op === 'saveProgress' || t.op === 'savePosition')
    .map((t) => t.ms));
  allSaveMs.sort((a, b) => a - b);

  const totalSaves = results.reduce((sum, r) => sum + (r.saveCount || 0), 0);
  const throughput = totalSaves / (elapsedMs / 1000);

  console.log('');
  console.log('Results:');
  console.log(`  users ok=${okCount} fail=${failCount} elapsed=${elapsedMs}ms`);
  console.log(`  saveOnboardingProgress calls=${totalSaves} (~${throughput.toFixed(1)}/s)`);
  if (allSaveMs.length) {
    console.log(`  save latency ms: p50=${percentile(allSaveMs, 50)} p95=${percentile(allSaveMs, 95)} max=${allSaveMs[allSaveMs.length - 1]}`);
  }

  const failures = results.filter((r) => !r.ok);
  if (failures.length) {
    console.log('');
    console.log('Failures (first 5):');
    for (const row of failures.slice(0, 5)) {
      console.log(`  ${row.email}:`, row.errors);
    }
  }

  if (process.env.LOAD_TEST_CLEANUP === '1') {
    const baPassword = process.env.BA_PASSWORD;
    const adminEmail = process.env.SMOKE_ADMIN_EMAIL || 'admin@fin1.de';
    if (!baPassword) {
      console.warn('WARN: LOAD_TEST_CLEANUP=1 but BA_PASSWORD unset — skipping cleanup');
    } else {
      try {
        const cleanup = await adminCleanup(parseBase, appId, adminEmail, baPassword);
        console.log('');
        console.log('Cleanup:', {
          dryRun: cleanup.dryRun,
          matched: cleanup.matched,
          deleted: cleanup.deleted,
          skipped: cleanup.skipped,
        });
      } catch (err) {
        console.warn('WARN: cleanup failed:', err.message);
      }
    }
  } else {
    console.log('');
    console.log(`Hint: cleanup with cleanupSignupRunUsers or LOAD_TEST_CLEANUP=1 BA_PASSWORD=…`);
    console.log(`  matched emails: signup+${runId}+*@test.com`);
  }

  process.exit(failCount > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('FAIL:', err);
  process.exit(1);
});
