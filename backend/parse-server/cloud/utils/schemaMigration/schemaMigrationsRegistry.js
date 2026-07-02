'use strict';

const { putParseSchemaFields } = require('./putParseSchemaFields');
const { createAdminListSearchIndexes } = require('./createAdminListSearchIndexes');
const { createOnboardingIndexes } = require('./createOnboardingIndexes');
const { backfillInvestmentTraderUsername } = require('./backfillInvestmentTraderUsername');
const { backfillTradeNumberYear } = require('./backfillTradeNumberYear');

/**
 * Zentrale, versionierte Schema-Migrationen (Reihenfolge = Ausführungsreihenfolge).
 * Neue Felder: **neue** `migrationId` anlegen — niemals bestehende Migration „umbiegen“,
 * damit Audit (`SchemaMigration`) nachvollziehbar bleibt.
 *
 * @typedef {{ migrationId: string, title: string, apply: () => Promise<Record<string, unknown>> }} SchemaMigrationDef
 */

/** @type {SchemaMigrationDef[]} */
const SCHEMA_MIGRATIONS = [
  {
    migrationId: 'gob_investment_schema_v1',
    title: 'Investment: businessCaseId, feeConfigSnapshot (GoB / Reservierung)',
    apply: () => putParseSchemaFields('Investment', {
      businessCaseId: { type: 'String' },
      /**
       * GoB: Gebührenbasis (`Configuration.financial`) eingefroren bei Reservierung.
       * Wird von `mergeInvestorFeeConfig` für Pool-Aktivierung, Settlement und Repair gelesen.
       */
      feeConfigSnapshot: { type: 'Object' },
    }),
  },
  {
    migrationId: 'gob_document_schema_v1',
    title: 'Document: businessCaseId, accountingSummaryText (Eigenbeleg GoB)',
    apply: () => putParseSchemaFields('Document', {
      businessCaseId: { type: 'String' },
      /** Mehrzeiliger Eigenbeleg-/Buchungstext (Reservierung GoB), Anzeige in App ohne PDF. */
      accountingSummaryText: { type: 'String' },
    }),
  },
  {
    migrationId: 'gob_investment_pool_trading_amount_v1',
    title: 'Investment: poolTradingAmount (gebuchte Kaufseite = Total Buy Cost, Investor-UI)',
    apply: () => putParseSchemaFields('Investment', {
      /** Nominal − Restbetrag nach Aktivierung; entspricht `metadata.totalBuyCost` der Collection Bill. */
      poolTradingAmount: { type: 'Number' },
    }),
  },
  {
    migrationId: 'admin_list_search_v1',
    title: 'Investment/Trade: adminSearchBlob + MongoDB text indexes (admin lists)',
    apply: async () => {
      const schemaInv = await putParseSchemaFields('Investment', {
        adminSearchBlob: { type: 'String' },
      });
      const schemaTrade = await putParseSchemaFields('Trade', {
        adminSearchBlob: { type: 'String' },
      });
      const indexes = await createAdminListSearchIndexes();
      return {
        ok: Boolean(schemaInv && schemaInv.ok && schemaTrade && schemaTrade.ok && indexes && indexes.ok),
        schemaInvestment: schemaInv,
        schemaTrade,
        indexes,
      };
    },
  },
  {
    migrationId: 'trade_summary_report_flags_v1',
    title: 'Trade: hasPoolParticipation, traderPartialSellEventCount (admin lists / SSOT)',
    apply: () => putParseSchemaFields('Trade', {
      hasPoolParticipation: { type: 'Boolean' },
      traderPartialSellEventCount: { type: 'Number' },
    }),
  },
  {
    migrationId: 'gob_user_cash_balance_v1',
    title: 'UserCashBalance: atomarer Kundensaldo (Phase 3b, Mongo $inc + unique userId)',
    apply: async () => {
      try {
        const seed = new Parse.Object('UserCashBalance');
        seed.set('userId', '__schema_seed__');
        seed.set('currentBalance', 0);
        await seed.save(null, { useMasterKey: true });
        await seed.destroy({ useMasterKey: true });
      } catch (e) {
        const msg = e && e.message ? String(e.message) : '';
        if (!msg.toLowerCase().includes('duplicate') && !msg.includes('already exists')) {
          // ignore — class either now exists or save was rejected because it
          // already exists; subsequent PUT will reveal real schema issues.
        }
      }

      const schemaResult = await putParseSchemaFields('UserCashBalance', {
        userId: { type: 'String' },
        currentBalance: { type: 'Number' },
      });

      const uri = process.env.PARSE_SERVER_DATABASE_URI;
      let indexResult = { uniqueIndex: 'skipped', reason: 'PARSE_SERVER_DATABASE_URI missing' };
      if (uri && typeof uri === 'string' && uri.trim()) {
        const { MongoClient } = require('mongodb');
        const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
        await client.connect();
        try {
          await client.db().collection('UserCashBalance').createIndex(
            { userId: 1 },
            { unique: true, name: 'userId_unique_1' },
          );
          indexResult = { uniqueIndex: 'created' };
        } catch (e) {
          const code = e && e.code;
          const msg = e && e.message ? String(e.message) : '';
          if (code === 85 || msg.includes('already exists') || msg.includes('same name')) {
            indexResult = { uniqueIndex: 'already_present' };
          } else {
            await client.close();
            throw e;
          }
        } finally {
          await client.close();
        }
      }
      return { ok: schemaResult && schemaResult.ok === true, schema: schemaResult, ...indexResult };
    },
  },
  {
    migrationId: 'gob_user_cash_balance_cents_v1',
    title: 'UserCashBalance: currentBalanceCents (ADR-018 P3c-4 dual-write)',
    apply: () => putParseSchemaFields('UserCashBalance', {
      currentBalanceCents: { type: 'Number' },
    }),
  },
  {
    migrationId: 'investment_number_unique_sparse_v1',
    title: 'Investment.investmentNumber: unique+sparse (E11000 ohne Nummer vermeiden)',
    apply: async () => {
      const uri = process.env.PARSE_SERVER_DATABASE_URI;
      if (!uri || typeof uri !== 'string' || !uri.trim()) {
        return { ok: true, skipped: true, reason: 'PARSE_SERVER_DATABASE_URI missing' };
      }
      const { MongoClient } = require('mongodb');
      const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
      await client.connect();
      try {
        const coll = client.db().collection('Investment');
        const idxName = 'investmentNumber_1';
        const existing = (await coll.indexes()).find((i) => i.name === idxName);
        if (existing && existing.unique === true && existing.sparse === true) {
          return { ok: true, index: 'already_unique_sparse' };
        }
        if (existing) {
          try {
            await coll.dropIndex(idxName);
          } catch (dropErr) {
            const msg = dropErr && dropErr.message ? String(dropErr.message) : '';
            if (!msg.includes('index not found')) throw dropErr;
          }
        }
        try {
          await coll.createIndex({ investmentNumber: 1 }, { unique: true, sparse: true, name: idxName });
          return { ok: true, index: 'recreated_unique_sparse' };
        } catch (createErr) {
          await coll.createIndex({ investmentNumber: 1 }, { sparse: true, name: idxName });
          return {
            ok: true,
            index: 'recreated_sparse_non_unique_fallback',
            warning: createErr && createErr.message ? String(createErr.message) : 'create unique failed',
          };
        }
      } finally {
        await client.close();
      }
    },
  },
  {
    migrationId: 'investment_trader_username_v1',
    title: 'Investment: traderUsername (Parse _User.username SSOT for sync/display)',
    apply: () => putParseSchemaFields('Investment', {
      traderUsername: { type: 'String' },
    }),
  },
  {
    migrationId: 'investment_trader_username_backfill_v1',
    title: 'Investment: backfill traderUsername from traderId (_User.username)',
    apply: backfillInvestmentTraderUsername,
  },
  {
    migrationId: 'investment_number_per_investor_compound_unique_v1',
    title: 'Investment: compound unique (investorId, investmentNumber) — per-investor INV sequence',
    apply: async () => {
      const uri = process.env.PARSE_SERVER_DATABASE_URI;
      if (!uri || typeof uri !== 'string' || !uri.trim()) {
        return { ok: true, skipped: true, reason: 'PARSE_SERVER_DATABASE_URI missing' };
      }
      const { MongoClient } = require('mongodb');
      const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
      const compoundName = 'investorId_1_investmentNumber_1';
      const legacyName = 'investmentNumber_1';
      await client.connect();
      try {
        const coll = client.db().collection('Investment');
        const indexes = await coll.indexes();
        const compound = indexes.find((i) => i.name === compoundName);
        if (compound && compound.unique === true && compound.sparse === true) {
          return { ok: true, index: 'compound_already_present' };
        }
        const legacy = indexes.find((i) => i.name === legacyName);
        if (legacy && legacy.unique === true) {
          try {
            await coll.dropIndex(legacyName);
          } catch (dropErr) {
            const msg = dropErr && dropErr.message ? String(dropErr.message) : '';
            if (!msg.includes('index not found')) throw dropErr;
          }
        }
        await coll.createIndex(
          { investorId: 1, investmentNumber: 1 },
          { unique: true, sparse: true, name: compoundName },
        );
        return { ok: true, index: 'compound_unique_sparse_created', droppedLegacy: Boolean(legacy) };
      } finally {
        await client.close();
      }
    },
  },
  {
    migrationId: 'gob_investment_commission_snapshot_v1',
    title: 'Investment: commissionRateBundleSnapshot (GoB / Provisions-Lock-in bei Reservierung)',
    apply: () => putParseSchemaFields('Investment', {
      /**
       * GoB: Erfolgsprovision-Bundle eingefroren bei Reservierung (inkl. source).
       * Settlement liest vor Live-Overrides via `readInvestmentCommissionRateSnapshot`.
       */
      commissionRateBundleSnapshot: { type: 'Object' },
    }),
  },
  {
    migrationId: 'onboarding_signup_indexes_v1',
    title: 'OnboardingProgress/Audit/VerificationCode indexes (signup load)',
    apply: () => createOnboardingIndexes(),
  },
  {
    migrationId: 'trade_number_year_v1',
    title: 'Trade: tradeNumberYear (annual per-trader sequence) + compound unique index',
    apply: async () => {
      const schemaResult = await putParseSchemaFields('Trade', {
        tradeNumberYear: { type: 'Number' },
      });

      const backfill = await backfillTradeNumberYear();

      const uri = process.env.PARSE_SERVER_DATABASE_URI;
      if (!uri || typeof uri !== 'string' || !uri.trim()) {
        return {
          ok: schemaResult && schemaResult.ok === true,
          schema: schemaResult,
          backfill,
          index: 'skipped',
          reason: 'PARSE_SERVER_DATABASE_URI missing',
        };
      }

      const { MongoClient } = require('mongodb');
      const client = new MongoClient(uri.trim(), { maxPoolSize: 2 });
      const legacyIndex = 'traderId_1_tradeNumber_1';
      const compoundIndex = 'traderId_1_tradeNumberYear_1_tradeNumber_1';
      await client.connect();
      try {
        const coll = client.db().collection('Trade');
        try {
          await coll.dropIndex(legacyIndex);
        } catch (dropErr) {
          const msg = dropErr && dropErr.message ? String(dropErr.message) : '';
          if (!msg.includes('index not found')) {
            // ignore missing legacy index
          }
        }
        const existing = (await coll.indexes()).find((i) => i.name === compoundIndex);
        if (!(existing && existing.unique === true && existing.sparse === true)) {
          if (existing) {
            try { await coll.dropIndex(compoundIndex); } catch (_) { void _; }
          }
          await coll.createIndex(
            { traderId: 1, tradeNumberYear: 1, tradeNumber: 1 },
            { unique: true, sparse: true, name: compoundIndex },
          );
        }
        return {
          ok: schemaResult && schemaResult.ok === true,
          schema: schemaResult,
          backfill,
          index: 'traderId_tradeNumberYear_tradeNumber_unique_sparse',
        };
      } finally {
        await client.close();
      }
    },
  },
];

module.exports = {
  SCHEMA_MIGRATIONS,
};
