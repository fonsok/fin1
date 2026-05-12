'use strict';

function looksLikeParseObjectId(value) {
  return typeof value === 'string' && /^[A-Za-z0-9]{10}$/.test(value);
}

module.exports = {
  looksLikeParseObjectId,
};
