'use strict';

const { escapeRegExp } = require('../../../utils/helpers');
const { normalizeAdminSearchTerm } = require('../../../utils/adminListSearch');

const MAX_TRADER_SEARCH_MATCHES = 50;

function traderIdVariantsForUser(user) {
  const ids = new Set([user.id]);
  const email = String(user.get('email') || '').trim().toLowerCase();
  if (email) ids.add(`user:${email}`);
  return [...ids];
}

async function findTradersByUserOrQuery(query) {
  query.equalTo('role', 'trader');
  query.limit(MAX_TRADER_SEARCH_MATCHES);
  return query.find({ useMasterKey: true });
}

async function loadTradersForProfileMatches(search) {
  const term = normalizeAdminSearchTerm(search);
  const re = new RegExp(escapeRegExp(term), 'i');
  const profileQueries = [];

  const profileFirstQ = new Parse.Query('UserProfile');
  profileFirstQ.matches('firstName', re);
  profileQueries.push(profileFirstQ);

  const profileLastQ = new Parse.Query('UserProfile');
  profileLastQ.matches('lastName', re);
  profileQueries.push(profileLastQ);

  const words = term.split(/\s+/).filter(Boolean);
  if (words.length >= 2) {
    const profileFullQ = new Parse.Query('UserProfile');
    profileFullQ.matches('firstName', new RegExp(escapeRegExp(words[0]), 'i'));
    profileFullQ.matches('lastName', new RegExp(escapeRegExp(words.slice(1).join(' ')), 'i'));
    profileQueries.push(profileFullQ);
  }

  const profiles = await Parse.Query.or(...profileQueries)
    .limit(MAX_TRADER_SEARCH_MATCHES)
    .find({ useMasterKey: true });

  const userIds = [...new Set(profiles.map((p) => p.get('userId')).filter(Boolean))];
  if (userIds.length === 0) return [];

  const userQ = new Parse.Query(Parse.User);
  userQ.containedIn('objectId', userIds);
  return findTradersByUserOrQuery(userQ);
}

/**
 * Resolve traderId values (objectId + legacy `user:email`) matching a free-text search term.
 * Used by Summary Report trade list live search (Mongo aggregate path).
 */
async function resolveTraderIdsMatchingAdminSearch(search) {
  const term = normalizeAdminSearchTerm(search);
  if (!term || term.length < 2) return [];

  const re = new RegExp(escapeRegExp(term), 'i');
  const userQueries = [];

  const firstNameQ = new Parse.Query(Parse.User);
  firstNameQ.matches('firstName', re);
  userQueries.push(firstNameQ);

  const lastNameQ = new Parse.Query(Parse.User);
  lastNameQ.matches('lastName', re);
  userQueries.push(lastNameQ);

  const usernameQ = new Parse.Query(Parse.User);
  usernameQ.matches('username', re);
  userQueries.push(usernameQ);

  const emailQ = new Parse.Query(Parse.User);
  emailQ.matches('email', re);
  userQueries.push(emailQ);

  const customerNumberQ = new Parse.Query(Parse.User);
  customerNumberQ.matches('customerNumber', re);
  userQueries.push(customerNumberQ);

  const words = term.split(/\s+/).filter(Boolean);
  if (words.length >= 2) {
    const fullNameQ = new Parse.Query(Parse.User);
    fullNameQ.matches('firstName', new RegExp(escapeRegExp(words[0]), 'i'));
    fullNameQ.matches('lastName', new RegExp(escapeRegExp(words.slice(1).join(' ')), 'i'));
    userQueries.push(fullNameQ);
  }

  const [usersFromFields, usersFromProfiles] = await Promise.all([
    findTradersByUserOrQuery(Parse.Query.or(...userQueries)),
    loadTradersForProfileMatches(term),
  ]);

  const traderIds = new Set();
  for (const user of [...usersFromFields, ...usersFromProfiles]) {
    for (const id of traderIdVariantsForUser(user)) traderIds.add(id);
  }
  return [...traderIds];
}

async function enrichTradeListFiltersForSearch(filters) {
  if (!filters.search) return filters;
  const traderIdsFromSearch = await resolveTraderIdsMatchingAdminSearch(filters.search);
  if (traderIdsFromSearch.length === 0) return filters;
  return { ...filters, traderIdsFromSearch };
}

module.exports = {
  resolveTraderIdsMatchingAdminSearch,
  enrichTradeListFiltersForSearch,
};
