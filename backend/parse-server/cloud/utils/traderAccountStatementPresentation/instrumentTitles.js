'use strict';

/**
 * Kundensicht-Titel: KAUF/VERKAUF · Richtung · Basiswert · WKN/ISIN
 * @example KAUF · Put · Dow Jones · UB4PQLG
 */
function tradeStatementTitle(transactionType, instrument) {
  const directionLabel = transactionType === 'sell' ? 'VERKAUF' : 'KAUF';
  const parts = [directionLabel];
  if (instrument.securitiesDirection) {
    parts.push(instrument.securitiesDirection);
  }
  if (instrument.underlyingAsset) {
    parts.push(instrument.underlyingAsset);
  }
  if (instrument.wknOrIsin) {
    parts.push(instrument.wknOrIsin);
  }
  if (parts.length === 1) return directionLabel;
  return parts.join(' · ');
}

module.exports = {
  tradeStatementTitle,
};
