'use strict';

function formatAdminUserDate(date) {
  if (!date) return null;
  if (date instanceof Date) return date.toISOString();
  if (date.iso) return date.iso;
  return date;
}

module.exports = {
  formatAdminUserDate,
};
