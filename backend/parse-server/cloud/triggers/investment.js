// ============================================================================
// Parse Cloud Code
// triggers/investment.js - Investment Triggers
// ============================================================================

'use strict';

const { generateSequentialNumber, calculateServiceCharge } = require('../utils/helpers');
const { getPlatformServiceChargeRate } = require('../utils/configHelper/index.js');
const { round2 } = require('../utils/accountingHelper/shared');
const { bookAccountStatementEntry } = require('../utils/accountingHelper/statements');
const { createWalletReceiptDocument } = require('../utils/accountingHelper/documents');
const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { validateInvestmentAmountAgainstLimits } = require('../utils/investmentLimitsValidation');

// Shared helper: record a set of app ledger entries atomically
async function recordAppLedgerEntries(entries) {
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const objects = entries.map((e) => {
    const obj = new AppLedgerEntry();
    obj.set('account', e.account);
    obj.set('side', e.side);
    obj.set('amount', e.amount);
    obj.set('userId', e.userId);
    obj.set('userRole', e.userRole);
    obj.set('transactionType', e.transactionType);
    obj.set('referenceId', e.referenceId);
    obj.set('referenceType', e.referenceType);
    obj.set('description', e.description);
    obj.set('metadata', e.metadata || {});
    return obj;
  });
  return Parse.Object.saveAll(objects, { useMasterKey: true });
}

// Shared helper: record contra postings for platform service charge (net + VAT) at bank level
async function recordBankContraPostingsForInvestment(investment) {
  const BankContraPosting = Parse.Object.extend('BankContraPosting');

  const investorId = investment.get('investorId') || '';
  const investorName = investment.get('investorName') || '';
  const batchId = investment.get('batchId') || investment.id;
  const serviceChargeNet = investment.get('serviceChargeAmount') || 0;
  const serviceChargeVat = investment.get('serviceChargeVat') || 0;
  const grossAmount = serviceChargeNet + serviceChargeVat;

  if (grossAmount <= 0) {
    return;
  }

  const reference = `PSC-${batchId}`;
  const createdAt = investment.get('createdAt') || new Date();
  const investmentId = investment.id;

  const netPosting = new BankContraPosting();
  netPosting.set('account', 'BANK-PS-NET');
  netPosting.set('side', 'credit');
  netPosting.set('amount', Math.round(serviceChargeNet * 100) / 100);
  netPosting.set('investorId', investorId);
  netPosting.set('investorName', investorName);
  netPosting.set('batchId', batchId);
  netPosting.set('investmentIds', [investmentId]);
  netPosting.set('reference', reference);
  netPosting.set('metadata', {
    component: 'net',
    grossAmount: grossAmount.toString(),
  });
  netPosting.set('createdAt', createdAt);

  const vatPosting = new BankContraPosting();
  vatPosting.set('account', 'BANK-PS-VAT');
  vatPosting.set('side', 'credit');
  vatPosting.set('amount', Math.round(serviceChargeVat * 100) / 100);
  vatPosting.set('investorId', investorId);
  vatPosting.set('investorName', investorName);
  vatPosting.set('batchId', batchId);
  vatPosting.set('investmentIds', [investmentId]);
  vatPosting.set('reference', reference);
  vatPosting.set('metadata', {
    component: 'vat',
    grossAmount: grossAmount.toString(),
  });
  vatPosting.set('createdAt', createdAt);

  await Parse.Object.saveAll([netPosting, vatPosting], { useMasterKey: true });
}

// ============================================================================
// BEFORE SAVE
// ============================================================================

Parse.Cloud.beforeSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !investment.existed();

  // ========== NEW INVESTMENT ==========
  if (isNew) {
    // Generate investment number
    if (!investment.get('investmentNumber')) {
      const investmentNumber = await generateSequentialNumber('INV', 'Investment', 'investmentNumber');
      investment.set('investmentNumber', investmentNumber);
    }

    // Validate amount (authoritative: admin limits from Configuration / getConfig)
    const amount = investment.get('amount');
    const limitCheck = await validateInvestmentAmountAgainstLimits(amount);
    if (!limitCheck.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, limitCheck.error);
    }

    // Validate investor != trader
    const investorId = investment.get('investorId');
    const traderId = investment.get('traderId');
    if (investorId === traderId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE,
        'Investoren können nicht im eigenen Pool investieren.');
    }

    // Calculate service charge using admin-configured rate
    const configuredRate = await getPlatformServiceChargeRate();
    const serviceChargeRate = investment.get('serviceChargeRate') || configuredRate;
    const serviceCharge = calculateServiceCharge(amount, serviceChargeRate);

    investment.set('serviceChargeRate', serviceCharge.rate);
    investment.set('serviceChargeAmount', serviceCharge.serviceCharge);
    investment.set('serviceChargeVat', serviceCharge.vat);
    investment.set('initialValue', serviceCharge.netAmount);
    investment.set('currentValue', serviceCharge.netAmount);

    // Set defaults
    investment.set('status', 'reserved');
    investment.set('profit', 0);
    investment.set('profitPercentage', 0);
    investment.set('totalCommissionPaid', 0);
    investment.set('numberOfTrades', 0);
    investment.set('reservedAt', new Date());

    // Set reservation expiry (24 hours)
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);
    investment.set('reservationExpiresAt', expiresAt);

    // Get trader info for snapshot (best-effort, must not block object creation)
    try {
      const traderQuery = new Parse.Query(Parse.User);
      const trader = await traderQuery.get(traderId, { useMasterKey: true });
      if (trader) {
        const profileQuery = new Parse.Query('UserProfile');
        profileQuery.equalTo('userId', traderId);
        const profile = await profileQuery.first({ useMasterKey: true });

        if (profile) {
          investment.set('traderName', `${profile.get('firstName')} ${profile.get('lastName').charAt(0)}.`);
        }
      }
    } catch (err) {
      // In dev/test flows the traderId may not be a real Parse _User objectId.
      // Do not reject the investment; just skip the snapshot.
      console.warn('beforeSave Investment: trader snapshot skipped:', err.message);
    }
  }

  // ========== STATUS CHANGE VALIDATION ==========
  if (!isNew && request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = investment.get('status');

    // Valid status transitions
    // Note: reserved→completed is allowed for backend settlement (trade completes
    // while investment was never individually activated, e.g. pool-based trading)
    const validTransitions = {
      'reserved': ['active', 'completed', 'cancelled'],
      'active': ['executing', 'paused', 'closing', 'completed', 'cancelled'],
      'executing': ['active', 'paused', 'completed'],
      'paused': ['active', 'closing', 'cancelled'],
      'closing': ['completed'],
      'completed': [],
      'cancelled': []
    };

    if (oldStatus !== newStatus) {
      const allowed = validTransitions[oldStatus] || [];
      if (!allowed.includes(newStatus)) {
        throw new Parse.Error(Parse.Error.INVALID_VALUE,
          `Ungültiger Statuswechsel von „${oldStatus}“ zu „${newStatus}“.`);
      }

      // Set timestamp (Parse schema stores these as String, not Date)
      if (newStatus === 'active') {
        investment.set('activatedAt', new Date().toISOString());
      } else if (newStatus === 'completed') {
        investment.set('completedAt', new Date().toISOString());
      } else if (newStatus === 'cancelled') {
        investment.set('cancelledAt', new Date().toISOString());
      }
    }
  }
});

// ============================================================================
// AFTER SAVE
// ============================================================================

Parse.Cloud.afterSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !request.original;

  const investorId = investment.get('investorId');
  const traderId = investment.get('traderId');
  const amount = investment.get('amount');

  // ========== NEW INVESTMENT ==========
  if (isNew) {
    // Notify investor
    await createNotification(investorId, 'investment_created', 'investment',
      'Investment erstellt',
      `Ihr Investment über ${formatCurrency(amount)} wurde erstellt. ` +
      `Bitte bestätigen Sie innerhalb von 24 Stunden.`);

    // Notify trader
    await createNotification(traderId, 'investment_created', 'investment',
      'Neues Investment',
      `Ein neuer Investor hat ${formatCurrency(amount)} in Ihren Pool investiert.`);

    // Log compliance event
    await logComplianceEvent(investorId, 'order_placed', 'info',
      `Investment created: ${investment.get('investmentNumber')}`,
      { amount, traderId });

    try {
      await investmentEscrow.bookReserve({
        investorId,
        amount: round2(amount),
        investmentId: investment.id,
        investmentNumber: investment.get('investmentNumber') || '',
      });
    } catch (err) {
      console.error(`❌ investmentEscrow.bookReserve failed ${investment.id}:`, err.message);
    }
  }

  // ========== STATUS CHANGE ==========
  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = investment.get('status');

    if (oldStatus !== newStatus) {
      // Log audit
      await logInvestmentAudit(investment.id,
        newStatus === 'active' ? 'activated' :
        newStatus === 'completed' ? 'completed' :
        newStatus === 'cancelled' ? 'cancelled' : 'status_change',
        oldStatus, newStatus);

      // Notify investor
      if (newStatus === 'active') {
        // CLT-LIAB RSV→TRD must not be skipped if wallet/notification/receipt fail (those run after save).
        try {
          await investmentEscrow.bookDeployToTrading({
            investorId,
            amount: round2(amount),
            investmentId: investment.id,
            investmentNumber: investment.get('investmentNumber') || '',
          });
        } catch (err) {
          console.error(`❌ investmentEscrow.bookDeployToTrading failed ${investment.id}:`, err.message);
        }

        try {
          await createNotification(investorId, 'investment_activated', 'investment',
            'Investment aktiviert',
            `Ihr Investment ${investment.get('investmentNumber')} ist jetzt aktiv.`);
        } catch (err) {
          console.error(`❌ createNotification (investment_activated) failed ${investment.id}:`, err.message);
        }

        try {
          await processWalletTransaction(investorId, 'investment', -amount,
            `Investment ${investment.get('investmentNumber')}`,
            'investment', investment.id);
        } catch (err) {
          console.error(`❌ processWalletTransaction (investment activation) failed ${investment.id}:`, err.message);
        }

        // GoB: Beleg + AccountStatement for investment activation
        try {
          const receipt = await createWalletReceiptDocument({
            userId: investorId,
            receiptType: 'investment',
            amount: -amount,
            description: `Investment Aktivierung ${investment.get('investmentNumber')}`,
            referenceType: 'Investment',
            referenceId: investment.id,
            metadata: { investmentNumber: investment.get('investmentNumber'), traderId },
          });

          await bookAccountStatementEntry({
            userId: investorId,
            entryType: 'investment_activate',
            amount: -Math.abs(amount),
            investmentId: investment.id,
            description: `Investment ${investment.get('investmentNumber')} aktiviert`,
            referenceDocumentId: receipt.id,
          });
        } catch (err) {
          console.error(`❌ GoB receipt failed for investment activation ${investment.id}:`, err.message);
        }

        // Service-Charge-Buchungen (PLT-REV-PSC, PLT-TAX-VAT, BANK-PS-NET, BANK-PS-VAT) werden
        // zentral im Invoice-Trigger (afterSave Invoice) erzeugt – eine Quelle, keine Doppelbuchung.

      } else if (newStatus === 'completed') {
        const profit = investment.get('profit') || 0;
        const finalValue = investment.get('currentValue');

        await createNotification(investorId, 'investment_completed', 'investment',
          'Investment abgeschlossen',
          `Ihr Investment wurde abgeschlossen. Gewinn: ${formatCurrency(profit)}`);

        // Credit to wallet
        await processWalletTransaction(investorId, 'investment_return', finalValue,
          `Investment Rückzahlung ${investment.get('investmentNumber')}`,
          'investment', investment.id);

        // GoB: Beleg + AccountStatement for investment return
        // Skip if settlement already booked investment_return (reserved → completed path)
        const existingReturn = await new Parse.Query('AccountStatement')
          .equalTo('investmentId', investment.id)
          .equalTo('entryType', 'investment_return')
          .equalTo('source', 'backend')
          .first({ useMasterKey: true });

        if (!existingReturn) {
          try {
            const receipt = await createWalletReceiptDocument({
              userId: investorId,
              receiptType: 'investment_return',
              amount: finalValue,
              description: `Investment Rückzahlung ${investment.get('investmentNumber')}`,
              referenceType: 'Investment',
              referenceId: investment.id,
              metadata: {
                investmentNumber: investment.get('investmentNumber'),
                profit,
                finalValue,
              },
            });

            await bookAccountStatementEntry({
              userId: investorId,
              entryType: 'investment_return',
              amount: Math.abs(finalValue),
              investmentId: investment.id,
              description: `Investment ${investment.get('investmentNumber')} Rückzahlung`,
              referenceDocumentId: receipt.id,
            });
          } catch (err) {
            console.error(`❌ GoB receipt failed for investment return ${investment.id}:`, err.message);
          }
        }

        try {
          const invNo = investment.get('investmentNumber') || '';
          const fv = round2(finalValue || 0);
          if (oldStatus === 'reserved') {
            await investmentEscrow.bookReleaseReservedOnComplete({
              investorId,
              amount: fv,
              investmentId: investment.id,
              investmentNumber: invNo,
            });
          } else if (['active', 'executing', 'paused', 'closing'].includes(oldStatus)) {
            await investmentEscrow.bookReleaseTrading({
              investorId,
              amount: fv,
              investmentId: investment.id,
              investmentNumber: invNo,
              reason: 'complete',
            });
          }
        } catch (err) {
          console.error(`❌ investmentEscrow release on complete failed ${investment.id}:`, err.message);
        }

      } else if (newStatus === 'cancelled') {
        // Refund if was active (or mid-trade states)
        const activeLike = ['active', 'executing', 'paused', 'closing'];
        if (activeLike.includes(oldStatus)) {
          const refundAmount = investment.get('currentValue');
          await processWalletTransaction(investorId, 'refund', refundAmount,
            `Investment Stornierung ${investment.get('investmentNumber')}`,
            'investment', investment.id);

          // GoB: Beleg + AccountStatement for refund
          try {
            const receipt = await createWalletReceiptDocument({
              userId: investorId,
              receiptType: 'refund',
              amount: refundAmount,
              description: `Investment Stornierung ${investment.get('investmentNumber')}`,
              referenceType: 'Investment',
              referenceId: investment.id,
              metadata: { investmentNumber: investment.get('investmentNumber'), refundAmount },
            });

            await bookAccountStatementEntry({
              userId: investorId,
              entryType: 'investment_refund',
              amount: Math.abs(refundAmount),
              investmentId: investment.id,
              description: `Investment ${investment.get('investmentNumber')} Stornierung/Rückerstattung`,
              referenceDocumentId: receipt.id,
            });
          } catch (err) {
            console.error(`❌ GoB receipt failed for investment refund ${investment.id}:`, err.message);
          }

          try {
            await investmentEscrow.bookReleaseTrading({
              investorId,
              amount: round2(refundAmount || 0),
              investmentId: investment.id,
              investmentNumber: investment.get('investmentNumber') || '',
              reason: 'refund',
            });
          } catch (err) {
            console.error(`❌ investmentEscrow.bookReleaseTrading (refund) failed ${investment.id}:`, err.message);
          }
        }

        // reserved → cancelled: escrow zurück + Wallet-Gutschrift (serverseitige Quelle)
        if (oldStatus === 'reserved') {
          const refundReserved = round2(amount);
          if (refundReserved > 0) {
            try {
              await investmentEscrow.bookReleaseReservation({
                investorId,
                amount: refundReserved,
                investmentId: investment.id,
                investmentNumber: investment.get('investmentNumber') || '',
              });
            } catch (err) {
              console.error(`❌ investmentEscrow.bookReleaseReservation failed ${investment.id}:`, err.message);
            }

            try {
              await processWalletTransaction(investorId, 'refund', refundReserved,
                `Investment Reservierung aufgehoben ${investment.get('investmentNumber')}`,
                'investment', investment.id);

              const receipt = await createWalletReceiptDocument({
                userId: investorId,
                receiptType: 'refund',
                amount: refundReserved,
                description: `Investment Reservierung aufgehoben ${investment.get('investmentNumber')}`,
                referenceType: 'Investment',
                referenceId: investment.id,
                metadata: { investmentNumber: investment.get('investmentNumber'), reason: 'reserved_cancel' },
              });

              await bookAccountStatementEntry({
                userId: investorId,
                entryType: 'investment_refund',
                amount: Math.abs(refundReserved),
                investmentId: investment.id,
                description: `Reservierung storniert ${investment.get('investmentNumber')}`,
                referenceDocumentId: receipt.id,
              });
            } catch (err) {
              console.error(`❌ GoB refund failed for reserved cancel ${investment.id}:`, err.message);
            }
          }
        }

        await createNotification(investorId, 'investment_cancelled', 'investment',
          'Investment storniert',
          `Ihr Investment ${investment.get('investmentNumber')} wurde storniert.`,
          'high');
      }
    }
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR'
  }).format(amount);
}

async function createNotification(userId, type, category, title, message, priority = 'normal') {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('priority', priority);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

async function logComplianceEvent(userId, eventType, severity, description, metadata = {}) {
  const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
  const event = new ComplianceEvent();
  event.set('userId', userId);
  event.set('eventType', eventType);
  event.set('severity', severity);
  event.set('description', description);
  event.set('metadata', metadata);
  event.set('occurredAt', new Date());
  await event.save(null, { useMasterKey: true });
}

async function logInvestmentAudit(investmentId, action, oldStatus, newStatus) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', action);
  log.set('resourceType', 'Investment');
  log.set('resourceId', investmentId);
  log.set('oldValues', { status: oldStatus });
  log.set('newValues', { status: newStatus });
  await log.save(null, { useMasterKey: true });
}

async function processWalletTransaction(userId, type, amount, description, refType, refId) {
  // This would call the wallet function
  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const tx = new WalletTransaction();
  tx.set('userId', userId);
  tx.set('transactionType', type);
  tx.set('amount', amount);
  tx.set('description', description);
  tx.set('referenceType', refType);
  tx.set('referenceId', refId);
  tx.set('status', 'completed');
  tx.set('completedAt', new Date());
  await tx.save(null, { useMasterKey: true });
}
