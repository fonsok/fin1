'use strict';

/**
 * FAQ admin Cloud Functions (CRUD, backup/import, migration).
 * Loaded via require('../user/faqAdmin') from user.js — resolves to this directory.
 */
require('./crud');
require('./importExport');
require('./migrate');
