'use strict';

const TERMS_EXPORT_FULL_LIMIT = 500;
const TERMS_EXPORT_ACTIVE_LIMIT = 50;
const TERMS_IMPORT_ARCHIVE_SCAN_LIMIT = 1000;
/** Page size when loading freshly imported rows for active-flag dedupe (must paginate; no hard cap on total). */
const TERMS_IMPORT_POST_RESTORE_PAGE = 1000;

module.exports = {
  TERMS_EXPORT_FULL_LIMIT,
  TERMS_EXPORT_ACTIVE_LIMIT,
  TERMS_IMPORT_ARCHIVE_SCAN_LIMIT,
  TERMS_IMPORT_POST_RESTORE_PAGE,
};
