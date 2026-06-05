'use strict';

const { looksLikeIosMockTraderUuid } = require('../resolveTraderParseUser');

describe('resolveTraderParseUser helpers', () => {
  test('looksLikeIosMockTraderUuid detects UUID v4 style ids', () => {
    expect(looksLikeIosMockTraderUuid('43326556-F631-401E-856E-95AFA5793F11')).toBe(true);
    expect(looksLikeIosMockTraderUuid('yqpmpTiBK9')).toBe(false);
    expect(looksLikeIosMockTraderUuid('')).toBe(false);
  });
});
