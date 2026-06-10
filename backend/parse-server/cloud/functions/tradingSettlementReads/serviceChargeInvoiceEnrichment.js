'use strict';

function isBusinessCustomerNumber(value) {
  const trimmed = String(value || '').trim();
  return trimmed.startsWith('ANL-') || trimmed.startsWith('TRD-');
}

/**
 * Patches legacy service_charge rows for display (Kundennummer + INV list in metadata).
 */
async function enrichServiceChargeInvoicesForDisplay(invoices, sessionUser) {
  const serviceChargeRows = invoices.filter((inv) => {
    const type = String(inv.get('invoiceType') || '').toLowerCase();
    return type === 'service_charge' || type === 'app_service_charge' || type === 'platform_service_charge';
  });
  if (serviceChargeRows.length === 0) {
    return invoices;
  }

  const sessionCustomerNumber = String(
    sessionUser.get('customerNumber') || sessionUser.get('customerId') || '',
  ).trim();

  const parseIdsNeedingInvNumbers = new Set();
  for (const inv of serviceChargeRows) {
    const metadata = inv.get('metadata') || {};
    const numbers = Array.isArray(metadata.investmentNumbers)
      ? metadata.investmentNumbers.filter(Boolean)
      : [];
    if (numbers.length > 0) continue;
    const ids = inv.get('investmentIds') || [];
    ids.forEach((id) => {
      const trimmed = String(id || '').trim();
      if (trimmed && !trimmed.startsWith('INV-')) parseIdsNeedingInvNumbers.add(trimmed);
    });
  }

  const invNumberByObjectId = new Map();
  if (parseIdsNeedingInvNumbers.size > 0) {
    const Investment = Parse.Object.extend('Investment');
    const q = new Parse.Query(Investment);
    q.containedIn('objectId', [...parseIdsNeedingInvNumbers]);
    q.limit(1000);
    const rows = await q.find({ useMasterKey: true });
    rows.forEach((row) => {
      const num = String(row.get('investmentNumber') || '').trim();
      if (num) invNumberByObjectId.set(row.id, num);
    });
  }

  return invoices.map((inv) => {
    const type = String(inv.get('invoiceType') || '').toLowerCase();
    const isServiceCharge = type === 'service_charge'
      || type === 'app_service_charge'
      || type === 'platform_service_charge';
    if (!isServiceCharge) return inv;

    const storedCustomerId = String(inv.get('customerId') || '').trim();
    if (!isBusinessCustomerNumber(storedCustomerId) && isBusinessCustomerNumber(sessionCustomerNumber)) {
      inv.set('customerId', sessionCustomerNumber);
    }

    const metadata = { ...(inv.get('metadata') || {}) };
    let numbers = Array.isArray(metadata.investmentNumbers)
      ? metadata.investmentNumbers.filter(Boolean)
      : [];
    if (numbers.length === 0) {
      const ids = inv.get('investmentIds') || [];
      numbers = ids
        .map((id) => {
          const trimmed = String(id || '').trim();
          if (trimmed.startsWith('INV-')) return trimmed;
          return invNumberByObjectId.get(trimmed) || '';
        })
        .filter(Boolean);
      if (numbers.length > 0) {
        metadata.investmentNumbers = numbers;
        if (!metadata.investmentNumber) {
          metadata.investmentNumber = numbers[0];
        }
        inv.set('metadata', metadata);
      }
    }

    return inv;
  });
}

module.exports = {
  isBusinessCustomerNumber,
  enrichServiceChargeInvoicesForDisplay,
};
