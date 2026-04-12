'use strict';

async function firstUser(match) {
  const q = new Parse.Query(Parse.User);
  Object.entries(match).forEach(([k, v]) => q.equalTo(k, v));
  return q.first({ useMasterKey: true });
}

/**
 * Resolve Parse _User.objectId from business customer number (ANL-/TRD-…).
 * Tries canonical field customerNumber, then legacy customerId on _User.
 */
async function userIdFromBusinessCustomerNumber(businessCustomerNumber) {
  let u = await firstUser({ customerNumber: businessCustomerNumber });
  if (!u) u = await firstUser({ customerId: businessCustomerNumber });
  return u ? u.id : businessCustomerNumber;
}

/** @deprecated Use userIdFromBusinessCustomerNumber */
const userIdFromCustomerId = userIdFromBusinessCustomerNumber;

async function adminUserId() {
  for (const email of ['admin@test.com', 'admin@fin1.de']) {
    const u = await firstUser({ email });
    if (u) return u.id;
  }
  return undefined;
}

/** Returns Parse objectId, or null if no user exists (never an email string). */
async function userIdFromEmailOrNull(email) {
  if (!email) return null;
  const u = await firstUser({ email });
  return u ? u.id : null;
}

module.exports = {
  firstUser,
  userIdFromBusinessCustomerNumber,
  userIdFromCustomerId,
  adminUserId,
  userIdFromEmailOrNull,
};
