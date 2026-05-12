'use strict';

const { applyQuerySort } = require('../../utils/applyQuerySort');
const { escapeRegExp } = require('../../utils/helpers');
const { readCustomerNumber } = require('../../utils/userIdentity');

function buildUserListQuery(searchQuery, role, status) {
  let q;
  if (searchQuery) {
    const emailQuery = new Parse.Query(Parse.User);
    emailQuery.contains('email', searchQuery.toLowerCase());
    const bizNumQuery = new Parse.Query(Parse.User);
    bizNumQuery.contains('customerNumber', searchQuery.toUpperCase());
    const legacyBizQuery = new Parse.Query(Parse.User);
    legacyBizQuery.contains('customerId', searchQuery.toUpperCase());
    const idQuery = Parse.Query.or(bizNumQuery, legacyBizQuery);
    const firstNameQuery = new Parse.Query(Parse.User);
    firstNameQuery.matches('firstName', new RegExp(escapeRegExp(searchQuery), 'i'));
    const lastNameQuery = new Parse.Query(Parse.User);
    lastNameQuery.matches('lastName', new RegExp(escapeRegExp(searchQuery), 'i'));
    const usernameQuery = new Parse.Query(Parse.User);
    usernameQuery.contains('username', searchQuery.toLowerCase());
    q = Parse.Query.or(emailQuery, idQuery, firstNameQuery, lastNameQuery, usernameQuery);
  } else {
    q = new Parse.Query(Parse.User);
  }
  if (role) q.equalTo('role', role);
  if (status) q.equalTo('status', status);
  return q;
}

async function handleSearchUsers(request) {
  const { query: searchQuery, role, status, limit = 50, skip = 0 } = request.params;

  const query = buildUserListQuery(searchQuery, role, status);
  applyQuerySort(query, request.params || {}, {
    allowed: ['createdAt', 'updatedAt', 'email', 'lastName', 'firstName', 'lastLoginAt'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  query.limit(limit);
  query.skip(skip);

  const countQuery = buildUserListQuery(searchQuery, role, status);

  const users = await query.find({ useMasterKey: true });
  const total = await countQuery.count({ useMasterKey: true });

  return {
    users: users.map(u => ({
      objectId: u.id,
      customerNumber: readCustomerNumber(u),
      email: u.get('email'),
      username: u.get('username') || u.get('email'),
      firstName: u.get('firstName'),
      lastName: u.get('lastName'),
      role: u.get('role'),
      status: u.get('status'),
      kycStatus: u.get('kycStatus'),
      accountType: u.get('accountType') || 'individual',
      companyKybStatus: u.get('companyKybStatus') || null,
      createdAt: u.get('createdAt'),
      updatedAt: u.get('updatedAt'),
      lastLoginAt: u.get('lastLoginAt'),
    })),
    total,
  };
}

module.exports = {
  handleSearchUsers,
};
