'use strict';

/**
 * Schema-Felder für GoB (Investment / Document) — **versioniert** über
 * `utils/schemaMigration` + Audit-Klasse `SchemaMigration`.
 */

const { requireAdminRole } = require('../../../utils/permissions');
const { putParseSchemaFields } = require('../../../utils/schemaMigration/putParseSchemaFields');
const {
  runPendingSchemaMigrations,
  SCHEMA_MIGRATION_CLASS,
} = require('../../../utils/schemaMigration/schemaMigrationRunner');

/** Alle GoB-Schema-Migrationen (idempotent, mit `SchemaMigration`-Audit). */
async function ensureGoBInvestmentEscrowSchemaFields() {
  return runPendingSchemaMigrations({ stopOnError: false });
}

function registerEnsureInvestmentSchemaParseFields() {
  Parse.Cloud.define('updateInvestmentClassSchemaFields', async (request) => {
    requireAdminRole(request);
    const result = await runPendingSchemaMigrations({ stopOnError: false });
    return { success: Boolean(result.ok), result };
  });

  Parse.Cloud.define('listSchemaMigrations', async (request) => {
    requireAdminRole(request);
    const limit = Math.min(Math.max(Number(request.params?.limit) || 50, 1), 200);
    const q = new Parse.Query(SCHEMA_MIGRATION_CLASS);
    q.descending('appliedAt');
    q.limit(limit);
    const rows = await q.find({ useMasterKey: true });
    return {
      className: SCHEMA_MIGRATION_CLASS,
      count: rows.length,
      rows: rows.map((r) => ({
        id: r.id,
        migrationId: r.get('migrationId') || null,
        title: r.get('title') || null,
        success: Boolean(r.get('success')),
        applySkipped: Boolean(r.get('applySkipped')),
        appliedAt: r.get('appliedAt') ? new Date(r.get('appliedAt')).toISOString() : null,
        durationMs: r.get('durationMs') ?? null,
        applyStatus: r.get('applyStatus') ?? null,
        applyNote: r.get('applyNote') || null,
        applyMessage: r.get('applyMessage') || null,
        errorMessage: r.get('errorMessage') || null,
      })),
    };
  });

  const { round2 } = require('../../../utils/accountingHelper/shared');
  const investmentEscrow = require('../../../utils/accountingHelper/investmentEscrow');

  /** Repariert fehlende Reserve-Leg (AVA→RSV) für Investments im Status reserved, sofern noch kein leg=reserve existiert. */
  Parse.Cloud.define('repairMissingInvestmentReserveEscrow', async (request) => {
    requireAdminRole(request);
    const limit = Math.min(Math.max(Number(request.params?.limit) || 50, 1), 200);
    const q = new Parse.Query('Investment');
    q.equalTo('status', 'reserved');
    q.descending('createdAt');
    q.limit(limit);
    const investments = await q.find({ useMasterKey: true });

    const out = { scanned: investments.length, repaired: [], skipped: [], errors: [] };
    for (const inv of investments) {
      const id = inv.id;
      if (!id) {
        out.errors.push({ reason: 'no_id' });
        continue;
      }
      if (await investmentEscrow.hasEscrowLeg(id, 'reserve')) {
        out.skipped.push(id);
        continue;
      }
      try {
        const br = await investmentEscrow.bookReserve({
          investorId: inv.get('investorId'),
          amount: round2(inv.get('amount')),
          investmentId: id,
          investmentNumber: inv.get('investmentNumber') || '',
          parseInvestment: inv,
        });
        if (br && br.ok === false) {
          out.errors.push({ id, reason: br.reason, detail: br.detail });
          continue;
        }
        if (await investmentEscrow.hasEscrowLeg(id, 'reserve')) {
          out.repaired.push(id);
        } else {
          out.errors.push({ id, reason: 'reserve_leg_still_missing', bookReserve: br || null });
        }
      } catch (e) {
        out.errors.push({ id, reason: e.message });
      }
    }
    return out;
  });
}

module.exports = {
  putParseSchemaFields,
  ensureGoBInvestmentEscrowSchemaFields,
  registerEnsureInvestmentSchemaParseFields,
  runPendingSchemaMigrations,
};
