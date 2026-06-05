#!/usr/bin/env node
'use strict';

/**
 * E2E smoke: Paired Buy (pool) → Sell → investor settlement → finance integrity healthy.
 *
 * Required env:
 * - PARSE_SERVER_URL
 * - PARSE_APP_ID
 * - PARSE_MASTER_KEY (settlement retry + health checks)
 *
 * Trader session (defaults match seedTestUsers / TestUserConstants.swift):
 * - E2E_TRADER_USERNAME (default trader1@test.com)
 * - E2E_TRADER_PASSWORD (default TestPassword123!)
 *
 * Optional:
 * - E2E_SMOKE_SYMBOL_PREFIX (default E2E-SMOKE)
 * - E2E_POLL_TIMEOUT_MS (default 90000)
 * - E2E_SKIP_SEED (if "1", only assert health — no new trade)
 */

function normalizeParseBase(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.endsWith('/parse') ? trimmed : `${trimmed}/parse`;
}

function emitOutput(name, value) {
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;
  const fs = require('fs');
  fs.appendFileSync(outputPath, `${name}=${String(value).replace(/\n/g, ' ')}\n`);
}

async function parseRequest({
  parseBase,
  appId,
  masterKey,
  sessionToken,
  method,
  path,
  body,
}) {
  const headers = {
    'Content-Type': 'application/json',
    'X-Parse-Application-Id': appId,
  };
  if (masterKey) headers['X-Parse-Master-Key'] = masterKey;
  if (sessionToken) headers['X-Parse-Session-Token'] = sessionToken;

  const response = await fetch(`${parseBase}${path}`, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok || json.error) {
    const detail = json.error || json;
    throw new Error(`Parse ${method} ${path} failed (${response.status}): ${JSON.stringify(detail)}`);
  }
  return json;
}

async function cloudFunction(parseBase, appId, auth, name, params = {}) {
  const json = await parseRequest({
    parseBase,
    appId,
    ...auth,
    method: 'POST',
    path: `/functions/${name}`,
    body: params,
  });
  return json.result;
}

async function login(parseBase, appId, username, password) {
  const json = await parseRequest({
    parseBase,
    appId,
    method: 'POST',
    path: '/login',
    body: { username, password },
  });
  if (!json.sessionToken) {
    throw new Error(`Login failed: ${JSON.stringify(json)}`);
  }
  return json.sessionToken;
}

async function updateOrderStatus(parseBase, appId, sessionToken, orderId, status, extra = {}) {
  await parseRequest({
    parseBase,
    appId,
    sessionToken,
    method: 'PUT',
    path: `/classes/Order/${orderId}`,
    body: { status, ...extra },
  });
}

async function advanceSellOrderToExecuted(parseBase, appId, sessionToken, orderId, quantity) {
  for (const step of ['suspended', 'executed']) {
    const extra = step === 'executed' ? { executedQuantity: quantity } : {};
    await updateOrderStatus(parseBase, appId, sessionToken, orderId, step, extra);
    await sleep(500);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function pollHealth(parseBase, appId, masterKey, timeoutMs) {
  const started = Date.now();
  let lastChain = null;
  let lastIntegrity = null;

  while (Date.now() - started < timeoutMs) {
    lastChain = await cloudFunction(parseBase, appId, { masterKey }, 'getPairedSellInvestorChainStatus', { limit: 25 });
    lastIntegrity = await cloudFunction(parseBase, appId, { masterKey }, 'getFinanceIntegrityStatus', { settlementLimit: 50 });

    if (lastChain.overall === 'healthy' && lastIntegrity.overall === 'healthy') {
      return { chain: lastChain, integrity: lastIntegrity };
    }

    await cloudFunction(parseBase, appId, { masterKey }, 'runSettlementRetryQueue', { limit: 25 });
    await sleep(3000);
  }

  const err = new Error('Health poll timeout');
  err.chain = lastChain;
  err.integrity = lastIntegrity;
  throw err;
}

async function runSeedFlow(parseBase, appId, sessionToken, masterKey) {
  const intentId = `e2e-smoke-${Date.now()}-${process.pid}`;
  const symbol = `${process.env.E2E_SMOKE_SYMBOL_PREFIX || 'E2E-SMOKE'}-${Date.now()}`;
  const price = 100;
  const traderQuantity = 1;
  const mirrorPoolQuantity = 1;

  console.log(`[e2e] executePairedBuy symbol=${symbol} intent=${intentId}`);
  const buyResult = await cloudFunction(parseBase, appId, { sessionToken }, 'executePairedBuy', {
    symbol,
    price,
    orderInstruction: 'market',
    clientOrderIntentId: intentId,
    traderQuantity,
    mirrorPoolQuantity,
    description: 'E2E paired sell integrity smoke',
  });

  const pairExecutionId = buyResult.pairExecutionId;
  if (!pairExecutionId) throw new Error(`Missing pairExecutionId: ${JSON.stringify(buyResult)}`);

  console.log('[e2e] advancePairedOrderStatus → suspended');
  await cloudFunction(parseBase, appId, { sessionToken }, 'advancePairedOrderStatus', {
    pairExecutionId,
    status: 'suspended',
  });

  console.log('[e2e] commitPairedBuyExecution (finalize pool activation)');
  const commitResult = await cloudFunction(parseBase, appId, { sessionToken }, 'commitPairedBuyExecution', {
    pairExecutionId,
  });
  if (String(commitResult.status || '') !== 'SETTLED' && commitResult.committed !== true) {
    throw new Error(`commitPairedBuyExecution unexpected: ${JSON.stringify(commitResult)}`);
  }

  const traderLeg = (buyResult.orders || []).find((o) => o.legType === 'TRADER');
  const traderBuyOrderId = traderLeg?.orderId;

  const openTrades = await cloudFunction(parseBase, appId, { sessionToken }, 'getOpenTrades', {});
  const trades = openTrades.trades || [];
  const trade = trades.find((t) => String(t.pairExecutionId || '') === pairExecutionId)
    || trades.find((t) => String(t.buyOrderId || '') === String(traderBuyOrderId || ''))
    || trades[0];

  if (!trade?.objectId) {
    throw new Error(`No open trade after paired buy: ${JSON.stringify(trades.slice(0, 3))}`);
  }

  const tradeId = trade.objectId;
  const sellQty = Number(trade.remainingQuantity || trade.quantity || traderQuantity);
  const sellPrice = price + 5;

  console.log(`[e2e] placeOrder sell tradeId=${tradeId} qty=${sellQty}`);
  const sellOrder = await cloudFunction(parseBase, appId, { sessionToken }, 'placeOrder', {
    symbol,
    quantity: sellQty,
    price: sellPrice,
    side: 'sell',
    orderType: 'market',
    tradeId,
  });

  const sellOrderId = sellOrder.orderId;
  if (!sellOrderId) throw new Error(`placeOrder sell failed: ${JSON.stringify(sellOrder)}`);

  console.log('[e2e] advance sell order → executed');
  await advanceSellOrderToExecuted(parseBase, appId, sessionToken, sellOrderId, sellQty);

  console.log('[e2e] runSettlementRetryQueue');
  await cloudFunction(parseBase, appId, { masterKey }, 'runSettlementRetryQueue', { limit: 25 });

  return { pairExecutionId, tradeId, sellOrderId, symbol };
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL);
  const appId = process.env.PARSE_APP_ID;
  const masterKey = process.env.PARSE_MASTER_KEY;
  const username = process.env.E2E_TRADER_USERNAME || 'trader1@test.com';
  const password = process.env.E2E_TRADER_PASSWORD || 'TestPassword123!';
  const timeoutMs = Number(process.env.E2E_POLL_TIMEOUT_MS || 90000);
  const skipSeed = process.env.E2E_SKIP_SEED === '1';

  if (!parseBase || !appId || !masterKey) {
    throw new Error('Missing PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY');
  }

  let seedMeta = null;
  if (!skipSeed) {
    const sessionToken = await login(parseBase, appId, username, password);
    console.log(`[e2e] logged in as ${username}`);
    seedMeta = await runSeedFlow(parseBase, appId, sessionToken, masterKey);
    console.log(`[e2e] seed OK pair=${seedMeta.pairExecutionId} trade=${seedMeta.tradeId}`);
  } else {
    console.log('[e2e] E2E_SKIP_SEED=1 — assert-only mode');
  }

  const { chain, integrity } = await pollHealth(parseBase, appId, masterKey, timeoutMs);

  emitOutput('chain_overall', chain.overall);
  emitOutput('integrity_overall', integrity.overall);
  emitOutput('pair_execution_id', seedMeta?.pairExecutionId || 'skipped');
  emitOutput('trade_id', seedMeta?.tradeId || 'skipped');

  console.log(`chain_overall=${chain.overall}`);
  console.log(`integrity_overall=${integrity.overall}`);
  console.log(`sellSettledHealthy=${chain.sellSettledHealthy}`);
  console.log(`violationCount=${chain.violationCount}`);
  if (Array.isArray(integrity.checks)) {
    for (const check of integrity.checks) {
      console.log(`check_${check.id}=${check.overall}`);
    }
  }
  console.log('[e2e] PASS: paired sell → investor chain + finance integrity healthy');
}

main().catch((err) => {
  console.error(err.message || err);
  if (err.chain) console.error('last_chain', JSON.stringify(err.chain));
  if (err.integrity) console.error('last_integrity', JSON.stringify(err.integrity));
  process.exit(1);
});
