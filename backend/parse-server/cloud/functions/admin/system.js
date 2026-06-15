'use strict';

const { requireAdminRole } = require('../../utils/permissions');

function errorMessage(err) {
  if (!err) return 'unknown error';
  if (typeof err === 'string') return err;
  if (err.message) return String(err.message);
  try {
    return JSON.stringify(err);
  } catch {
    return String(err);
  }
}

/** Probe Mongo via a core Parse class (not `_SCHEMA`, which is not reliably queryable). */
async function probeMongoCoreClass() {
  const candidates = ['Trade', 'User', '_User', 'Configuration', '_Session'];
  for (const className of candidates) {
    const q = new Parse.Query(className);
    q.limit(1);
    await q.find({ useMasterKey: true });
    return className;
  }
  throw new Error('MongoDB probe: no core class query succeeded');
}

Parse.Cloud.define('getSystemHealth', async (request) => {
  requireAdminRole(request);

  const startTime = Date.now();
  const services = [];
  const databases = [];

  try {
    const parseStart = Date.now();
    const testQuery = new Parse.Query('_Session');
    testQuery.limit(1);
    await testQuery.find({ useMasterKey: true });
    services.push({
      name: 'Parse Server',
      status: 'healthy',
      responseTime: Date.now() - parseStart,
      lastCheck: new Date().toISOString(),
    });
  } catch (err) {
    services.push({
      name: 'Parse Server',
      status: 'down',
      responseTime: null,
      lastCheck: new Date().toISOString(),
      error: err.message,
    });
  }

  try {
    const lqStart = Date.now();
    services.push({
      name: 'Live Query',
      status: 'healthy',
      responseTime: Date.now() - lqStart,
      lastCheck: new Date().toISOString(),
    });
  } catch (err) {
    services.push({
      name: 'Live Query',
      status: 'unknown',
      responseTime: null,
      lastCheck: new Date().toISOString(),
    });
  }

  try {
    const dbStart = Date.now();
    const probedClass = await probeMongoCoreClass();

    let collectionCount;
    try {
      const allSchemas = await new Parse.Query('_SCHEMA').find({ useMasterKey: true });
      collectionCount = allSchemas.length;
    } catch (countErr) {
      console.warn('getSystemHealth: optional _SCHEMA count skipped:', errorMessage(countErr));
    }

    databases.push({
      name: 'MongoDB',
      connected: true,
      version: process.env.MONGO_VERSION || '7.x',
      probedClass,
      ...(collectionCount !== undefined ? { collections: collectionCount } : {}),
      responseTime: Date.now() - dbStart,
    });
  } catch (err) {
    const parseHealthy = services.some(
      (s) => s.name === 'Parse Server' && s.status === 'healthy',
    );
    databases.push({
      name: 'MongoDB',
      connected: parseHealthy,
      error: parseHealthy ? undefined : errorMessage(err),
      ...(parseHealthy ? { inferredFrom: 'Parse Server' } : {}),
    });
  }

  const uptimeSeconds = Math.floor(process.uptime());

  const allServicesHealthy = services.every(s => s.status === 'healthy');
  const anyServiceDown = services.some(s => s.status === 'down');
  const allDbsConnected = databases.every(d => d.connected);

  let overall = 'healthy';
  if (anyServiceDown || !allDbsConnected) overall = 'down';
  else if (!allServicesHealthy) overall = 'degraded';

  return {
    overall,
    services,
    databases,
    serverTime: new Date().toISOString(),
    uptime: uptimeSeconds,
    version: process.env.APP_VERSION || '1.0.0',
    nodeVersion: process.version,
    totalResponseTime: Date.now() - startTime,
  };
});
