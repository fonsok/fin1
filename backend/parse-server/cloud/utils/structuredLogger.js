'use strict';

/**
 * Strukturierter Audit-Logger (GoB / IFRS).
 *
 * Ziel: maschinenlesbare Logzeilen für Buchungs- und Settlement-Pfade,
 * sodass Aggregatoren (`tradeId`, `investmentId`, `businessCaseId`,
 * `documentId`, `participationId`, `entryType`, …) als **Felder** filterbar
 * sind statt nur im freien Text. Die menschenlesbare Form bleibt zusätzlich
 * über `message` erhalten.
 *
 * Output-Format pro Aufruf (eine Zeile, JSON):
 *   {"ts":"2026-…Z","level":"info","event":"escrow.split.book","category":"gob",
 *    "tradeId":"abc","investmentId":"def","businessCaseId":"BC-1",
 *    "message":"📒 RSV→TRD/AVA split booked"}
 *
 * Verwendung:
 *   const { audit } = require('../structuredLogger');
 *   audit.info('settlement.participation.failure', {
 *     tradeId, tradeNumber, participationId, investmentId,
 *     error: err.message,
 *     message: 'settleParticipation failed',
 *   });
 *
 * Sicherheits-/Compliance-Filter:
 *   - Felder mit den Namen `password`, `sessionToken`, `masterKey`,
 *     `parseMasterKey`, `authData`, `secret`, `accessToken`, `refreshToken`
 *     werden niemals serialisiert (auch nicht als `null`).
 *   - `error`-Felder werden auf String reduziert (kein nested-stack-leak).
 *
 * Test-Hooks:
 *   - `setAuditLoggerSinks({ info, warn, error })` ersetzt die Console-Sinks
 *     (für Jest-Assertions).
 *   - `resetAuditLogger()` stellt die Default-Sinks wieder her.
 */

const REDACTED_KEYS = new Set([
  'password',
  'sessiontoken',
  'session_token',
  'masterkey',
  'master_key',
  'parsemasterkey',
  'parse_master_key',
  'authdata',
  'secret',
  'accesstoken',
  'access_token',
  'refreshtoken',
  'refresh_token',
]);

const DEFAULT_SINKS = {
  info: (line) => console.log(line),
  warn: (line) => console.warn(line),
  error: (line) => console.error(line),
};

let sinks = { ...DEFAULT_SINKS };

function isRedactedKey(key) {
  if (typeof key !== 'string') return false;
  return REDACTED_KEYS.has(key.toLowerCase());
}

function normalizeValue(value, seen) {
  if (value == null) return value;
  if (value instanceof Date) return value.toISOString();
  if (value instanceof Error) return value.message || String(value);
  const t = typeof value;
  if (t === 'string' || t === 'number' || t === 'boolean') return value;
  if (t === 'object') {
    if (seen.has(value)) return '[Circular]';
    seen.add(value);
    if (Array.isArray(value)) {
      return value.map((v) => normalizeValue(v, seen));
    }
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      if (isRedactedKey(k)) continue;
      out[k] = normalizeValue(v, seen);
    }
    return out;
  }
  try {
    return String(value);
  } catch (_e) {
    return null;
  }
}

function sanitizeFields(fields) {
  if (!fields || typeof fields !== 'object') return {};
  const seen = new WeakSet();
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    if (isRedactedKey(k)) continue;
    if (v === undefined) continue;
    out[k] = normalizeValue(v, seen);
  }
  return out;
}

function buildLine(level, event, fields) {
  const payload = {
    ts: new Date().toISOString(),
    level,
    event: typeof event === 'string' && event.trim().length > 0 ? event : 'unknown',
    ...sanitizeFields(fields),
  };
  try {
    return JSON.stringify(payload);
  } catch (_e) {
    return JSON.stringify({
      ts: payload.ts,
      level,
      event: payload.event,
      message: '[structuredLogger] failed to serialize fields',
    });
  }
}

function emit(level, event, fields) {
  const sink = sinks[level] || sinks.info;
  sink(buildLine(level, event, fields));
}

const audit = {
  info(event, fields) {
    emit('info', event, fields);
  },
  warn(event, fields) {
    emit('warn', event, fields);
  },
  error(event, fields) {
    emit('error', event, fields);
  },
};

function setAuditLoggerSinks(custom = {}) {
  sinks = {
    info: typeof custom.info === 'function' ? custom.info : DEFAULT_SINKS.info,
    warn: typeof custom.warn === 'function' ? custom.warn : DEFAULT_SINKS.warn,
    error: typeof custom.error === 'function' ? custom.error : DEFAULT_SINKS.error,
  };
}

function resetAuditLogger() {
  sinks = { ...DEFAULT_SINKS };
}

module.exports = {
  audit,
  setAuditLoggerSinks,
  resetAuditLogger,
  REDACTED_KEYS,
};
