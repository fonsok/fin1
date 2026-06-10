'use strict';

const fs = require('fs');
const path = require('path');

describe('pairedTradeMirrorSync – buy-field immutability guard', () => {
  const filePath = path.resolve(__dirname, '../pairedTradeMirrorSync/sellSync.js');
  const source = fs.readFileSync(filePath, 'utf-8');

  const syncFnMatch = source.match(
    /async function applyMirrorSellSyncFromTraderLeg[\s\S]+?^}/m,
  );
  const syncFn = syncFnMatch ? syncFnMatch[0] : '';

  test('function body exists and is non-empty', () => {
    expect(syncFn.length).toBeGreaterThan(100);
  });

  test('does NOT contain mirrorTrade.set(\'quantity\'', () => {
    expect(syncFn).not.toMatch(/mirrorTrade\.set\(\s*['"]quantity['"]/);
  });

  test('does NOT contain mirrorTrade.set(\'buyAmount\'', () => {
    expect(syncFn).not.toMatch(/mirrorTrade\.set\(\s*['"]buyAmount['"]/);
  });

  test('does NOT contain mirrorTrade.set(\'buyPrice\'', () => {
    expect(syncFn).not.toMatch(/mirrorTrade\.set\(\s*['"]buyPrice['"]/);
  });

  test('does NOT contain mirrorTrade.set(\'buyOrder\'', () => {
    expect(syncFn).not.toMatch(/mirrorTrade\.set\(\s*['"]buyOrder['"]/);
  });

  test('contains GOBD immutability comment', () => {
    expect(syncFn).toMatch(/Kaufseite.*bleibt unverändert|immutable Buy-Leg|GOBD/i);
  });
});
