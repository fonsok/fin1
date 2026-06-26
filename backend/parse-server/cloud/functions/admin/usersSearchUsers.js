'use strict';

const { applyQuerySort } = require('../../utils/applyQuerySort');
const { escapeRegExp } = require('../../utils/helpers');
const { readCustomerNumber } = require('../../utils/userIdentity');
const {
  SEED_TEST_USER_EMAIL_REGEX,
  SIGNUP_RUN_EMAIL_REGEX,
  isSeedTestUserEmail,
  isSignupRunEmail,
  shouldExcludeSignupRuns,
} = require('../../utils/testUserCatalog');

function applyTestUserFilter(query, testUserFilter) {
  const filter = String(testUserFilter || '').trim();
  if (filter === 'seed') {
    query.matches('email', SEED_TEST_USER_EMAIL_REGEX, 'i');
  } else if (filter === 'signupRuns') {
    query.matches('email', SIGNUP_RUN_EMAIL_REGEX, 'i');
  }
  return query;
}

function applySignupRunExclusion(query, { searchQuery, testUserFilter } = {}) {
  if (!shouldExcludeSignupRuns({ searchQuery, testUserFilter })) {
    return query;
  }
  const signupRunQuery = new Parse.Query(Parse.User);
  signupRunQuery.matches('email', SIGNUP_RUN_EMAIL_REGEX, 'i');
  return query.doesNotMatchKeyInQuery('email', 'email', signupRunQuery);
}

function buildUserListQuery(searchQuery, role, status, testUserFilter) {
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
  q = applyTestUserFilter(q, testUserFilter);
  q = applySignupRunExclusion(q, { searchQuery, testUserFilter });
  return q;
}

function rankSearchUsers(users, searchQuery) {
  if (!searchQuery || !Array.isArray(users) || users.length < 2) {
    return users;
  }
  const needle = String(searchQuery).trim().toLowerCase();
  const score = (user) => {
    const email = String(user.get('email') || '').toLowerCase();
    const username = String(user.get('username') || '').toLowerCase();
    const customerNumber = String(readCustomerNumber(user) || '').toLowerCase();
    if (email === needle) return 0;
    if (username === needle) return 1;
    if (customerNumber === needle) return 2;
    if (isSeedTestUserEmail(email)) return 3;
    if (email.includes(needle)) return 4;
    if (isSignupRunEmail(email)) return 6;
    return 5;
  };
  return [...users].sort((a, b) => {
    const diff = score(a) - score(b);
    if (diff !== 0) return diff;
    const aCreated = a.get('createdAt');
    const bCreated = b.get('createdAt');
    if (aCreated && bCreated) return bCreated - aCreated;
    return 0;
  });
}

function mapSearchUserRow(u) {
  return {
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
  };
}

async function handleSearchUsers(request) {
  const {
    query: searchQuery,
    role,
    status,
    testUserFilter,
    limit = 50,
    skip = 0,
  } = request.params;

  const query = buildUserListQuery(searchQuery, role, status, testUserFilter);
  applyQuerySort(query, request.params || {}, {
    allowed: ['createdAt', 'updatedAt', 'email', 'lastName', 'firstName', 'lastLoginAt'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  query.limit(limit);
  query.skip(skip);

  const countQuery = buildUserListQuery(searchQuery, role, status, testUserFilter);

  let users = await query.find({ useMasterKey: true });
  users = rankSearchUsers(users, searchQuery);
  const total = await countQuery.count({ useMasterKey: true });

  return {
    users: users.map(mapSearchUserRow),
    total,
  };
}

module.exports = {
  handleSearchUsers,
  buildUserListQuery,
  rankSearchUsers,
  applyTestUserFilter,
  applySignupRunExclusion,
};
