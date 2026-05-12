#!/usr/bin/env node
/**
 * CI/local: minimaler HTTP-Server auf 127.0.0.1, prüft Antwortform von
 * GET /health und POST /parse/functions/getConfig (Parse-REST-Form).
 * Keine DB, kein Parse Server — nur Vertrags-/Smoke-Form.
 */
import http from 'http';

const getConfigResult = {
  financial: {
    orderFeeRate: 0.005,
    orderFeeMin: 5,
    orderFeeMax: 50,
    traderCommissionRate: 0.1,
    appServiceChargeRate: 0.02,
    minimumCashReserve: 20,
    initialAccountBalance: 0,
  },
  features: {
    priceAlertsEnabled: true,
    darkModeEnabled: false,
    biometricAuthEnabled: true,
  },
  limits: {
    minDeposit: 10,
    maxDeposit: 100000,
    minInvestment: 20,
    maxInvestment: 100000,
    dailyTransactionLimit: 10000,
  },
  display: {
    showCommissionBreakdownInCreditNote: true,
    showDocumentReferenceLinksInAccountStatement: true,
    maximumRiskExposurePercent: 2,
    walletFeatureEnabled: false,
    walletActionModeGlobal: 'disabled',
    walletActionModeInvestor: 'deposit_and_withdrawal',
    walletActionModeTrader: 'deposit_and_withdrawal',
    walletActionModeIndividual: 'deposit_and_withdrawal',
    walletActionModeCompany: 'deposit_and_withdrawal',
    walletActionMode: 'disabled',
    serviceChargeInvoiceFromBackend: false,
    serviceChargeLegacyClientFallbackEnabled: true,
    serviceChargeLegacyDisableAllowedFrom: '2026-05-15',
  },
};

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    sendJson(res, 200, {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: 'ci-mock',
    });
    return;
  }
  if (req.method === 'POST' && req.url === '/parse/functions/getConfig') {
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1_000_000) req.destroy();
    });
    req.on('end', () => {
      sendJson(res, 200, { result: getConfigResult });
    });
    return;
  }
  sendJson(res, 404, { error: 'Not Found' });
});

server.listen(0, '127.0.0.1', async () => {
  const addr = server.address();
  const port = typeof addr === 'object' && addr ? addr.port : 0;
  const base = `http://127.0.0.1:${port}`;

  const fail = (msg) => {
    console.error(`FAIL: ${msg}`);
    server.close();
    process.exit(1);
  };

  try {
    const hRes = await fetch(`${base}/health`);
    const hJson = await hRes.json();
    if (!hRes.ok || hJson.status !== 'healthy') fail('GET /health status');
    if (typeof hJson.timestamp !== 'string' || typeof hJson.version !== 'string') {
      fail('GET /health shape (timestamp, version)');
    }

    const cRes = await fetch(`${base}/parse/functions/getConfig`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Parse-Application-Id': 'ci-smoke',
      },
      body: '{}',
    });
    const cJson = await cRes.json();
    if (!cRes.ok || !cJson || typeof cJson.result !== 'object') {
      fail('POST /parse/functions/getConfig envelope { result }');
    }
    const { result } = cJson;
    if (typeof result.financial !== 'object') fail('getConfig.result.financial');
    if (typeof result.display !== 'object') fail('getConfig.result.display');
    if (typeof result.limits !== 'object') fail('getConfig.result.limits');
    if (typeof result.features !== 'object') fail('getConfig.result.features');
  } catch (e) {
    fail(e instanceof Error ? e.message : String(e));
  }

  console.log('OK: ci-smoke-local-mock (/health + /parse/functions/getConfig shape)');
  server.close();
  process.exit(0);
});
