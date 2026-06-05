'use strict';

const {
  canAdvanceOneStep,
  canReachStatusForward,
  pairedLegsCanonicalStatus,
  normalizeStatus,
} = require('../pairedOrderStatusCoupling');

describe('pairedOrderStatusCoupling', () => {
  test('canAdvanceOneStep allows single progression step', () => {
    expect(canAdvanceOneStep('submitted', 'suspended')).toBe(true);
    expect(canAdvanceOneStep('suspended', 'executed')).toBe(true);
    expect(canAdvanceOneStep('executed', 'confirmed')).toBe(true);
    expect(canAdvanceOneStep('submitted', 'executed')).toBe(false);
    expect(canAdvanceOneStep('submitted', 'cancelled')).toBe(false);
  });

  test('pairedLegsCanonicalStatus requires unanimous status', () => {
    const mk = (status) => ({
      get: (k) => (k === 'status' ? status : null),
    });
    expect(pairedLegsCanonicalStatus([mk('submitted'), mk('submitted')])).toBe('submitted');
    expect(pairedLegsCanonicalStatus([mk('submitted'), mk('suspended')])).toBeNull();
  });

  test('normalizeStatus lowercases', () => {
    expect(normalizeStatus('Suspended')).toBe('suspended');
  });

  test('canReachStatusForward allows pending → suspended catch-up', () => {
    expect(canReachStatusForward('pending', 'suspended')).toBe(true);
    expect(canReachStatusForward('submitted', 'suspended')).toBe(true);
    expect(canReachStatusForward('submitted', 'executed')).toBe(true);
  });
});
