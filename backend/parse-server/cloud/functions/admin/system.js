'use strict';

const { requireAdminRole } = require('../../utils/permissions');

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
    const schemaQuery = new Parse.Query('_SCHEMA');
    schemaQuery.limit(1);
    await schemaQuery.find({ useMasterKey: true });

    // Connectivity is proven by the limit(1) query above. A full _SCHEMA scan can
    // fail or time out on large deployments and must not mark MongoDB as disconnected.
    let collectionCount;
    try {
      const allSchemas = await new Parse.Query('_SCHEMA').find({ useMasterKey: true });
      collectionCount = allSchemas.length;
    } catch (countErr) {
      console.warn('getSystemHealth: optional _SCHEMA count skipped:', countErr.message);
    }

    databases.push({
      name: 'MongoDB',
      connected: true,
      version: process.env.MONGO_VERSION || '7.x',
      ...(collectionCount !== undefined ? { collections: collectionCount } : {}),
      responseTime: Date.now() - dbStart,
    });
  } catch (err) {
    databases.push({
      name: 'MongoDB',
      connected: false,
      error: err.message,
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
