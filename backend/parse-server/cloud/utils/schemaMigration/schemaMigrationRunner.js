'use strict';

const { SCHEMA_MIGRATIONS } = require('./schemaMigrationsRegistry');

/** Parse-Klasse für Audit / Idempotenz (Master-Key writes only). */
const SCHEMA_MIGRATION_CLASS = 'SchemaMigration';

function isApplySuccess(r) {
  if (!r) return false;
  if (r.skipped === true) return false;
  return Boolean(r.ok);
}

async function hasSuccessfulMigration(migrationId) {
  const q = new Parse.Query(SCHEMA_MIGRATION_CLASS);
  q.equalTo('migrationId', migrationId);
  q.equalTo('success', true);
  q.limit(1);
  const row = await q.first({ useMasterKey: true });
  return Boolean(row);
}

/**
 * Persistiert Versuch (Erfolg oder harten Fehler). Bei fehlendem Master-Key (`skipped`)
 * wird **nichts** persistiert, damit nach Bereitstellung des Keys erneut versucht wird.
 */
async function recordMigrationAttempt({
  migrationId,
  title,
  applyResult,
  durationMs,
  errorMessage,
}) {
  const SchemaMigration = Parse.Object.extend(SCHEMA_MIGRATION_CLASS);
  const row = new SchemaMigration();
  row.set('migrationId', migrationId);
  row.set('title', title);
  const success = isApplySuccess(applyResult) && !errorMessage;
  row.set('success', success);
  row.set('applySkipped', Boolean(applyResult && applyResult.skipped));
  row.set('durationMs', Math.max(0, Number(durationMs) || 0));
  row.set('appliedAt', new Date());
  if (applyResult) {
    if (applyResult.status !== undefined) row.set('applyStatus', applyResult.status);
    if (applyResult.note) row.set('applyNote', applyResult.note);
    if (applyResult.message) row.set('applyMessage', applyResult.message);
  }
  if (errorMessage) row.set('errorMessage', String(errorMessage));
  await row.save(null, { useMasterKey: true });
}

/**
 * Führt alle registrierten Migrationen aus, sofern noch keine erfolgreiche Zeile existiert.
 *
 * @param {{ stopOnError?: boolean }} [opts]
 * @returns {Promise<{
 *   ok: boolean,
 *   results: Array<{ migrationId: string, title: string, status: string, applyResult?: unknown, errorMessage?: string|null, durationMs?: number }>,
 *   fatalError?: string|null
 * }>}
 */
async function runPendingSchemaMigrations({ stopOnError = false } = {}) {
  const results = [];
  let fatalError = null;

  for (const m of SCHEMA_MIGRATIONS) {
    if (await hasSuccessfulMigration(m.migrationId)) {
      results.push({
        migrationId: m.migrationId,
        title: m.title,
        status: 'already_applied',
      });
      continue;
    }

    const started = Date.now();
    let applyResult = null;
    let errMsg = null;
    try {
      applyResult = await m.apply();
    } catch (e) {
      errMsg = e && e.message ? e.message : String(e);
    }
    const durationMs = Date.now() - started;

    if (applyResult && applyResult.skipped) {
      results.push({
        migrationId: m.migrationId,
        title: m.title,
        status: 'skipped_no_master_key',
        applyResult,
        durationMs,
      });
      if (stopOnError) {
        fatalError = applyResult.message || 'master_key_missing';
        break;
      }
      continue;
    }

    const success = isApplySuccess(applyResult) && !errMsg;
    try {
      await recordMigrationAttempt({
        migrationId: m.migrationId,
        title: m.title,
        applyResult: applyResult || {},
        durationMs,
        errorMessage: errMsg,
      });
    } catch (e) {
      console.error(`SchemaMigration persist failed (${m.migrationId}):`, e && e.message ? e.message : e);
    }

    results.push({
      migrationId: m.migrationId,
      title: m.title,
      status: success ? 'applied' : 'failed',
      applyResult,
      errorMessage: errMsg || null,
      durationMs,
    });

    if (!success && stopOnError) {
      fatalError = errMsg || 'schema_apply_not_ok';
      break;
    }
  }

  const ok = !fatalError && results.every((r) => (
    r.status === 'already_applied'
    || r.status === 'applied'
    || r.status === 'skipped_no_master_key'
  ));

  return { ok, results, fatalError: fatalError || null };
}

module.exports = {
  runPendingSchemaMigrations,
  SCHEMA_MIGRATION_CLASS,
  hasSuccessfulMigration,
};
