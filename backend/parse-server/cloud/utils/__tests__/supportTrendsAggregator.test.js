'use strict';

const { detectSupportTrends, isEscalatedTicket } = require('../supportTrendsAggregator');

describe('supportTrendsAggregator', () => {
  it('isEscalatedTicket uses flag or status', () => {
    expect(isEscalatedTicket({ status: 'open', escalated: true })).toBe(true);
    expect(isEscalatedTicket({ status: 'escalated' })).toBe(true);
    expect(isEscalatedTicket({ status: 'open' })).toBe(false);
  });

  it('detectSupportTrends finds high escalation rate', () => {
    const now = Date.now();
    const tickets = Array.from({ length: 10 }, (_, i) => ({
      objectId: `t${i}`,
      userId: `u${i}`,
      category: 'general',
      status: i < 3 ? 'escalated' : 'open',
      createdAt: new Date(now - 24 * 60 * 60 * 1000).toISOString(),
      escalated: i < 3,
    }));

    const trends = detectSupportTrends(tickets);
    const escalation = trends.find((t) => t.type === 'highEscalationRate');
    expect(escalation).toBeDefined();
    expect(escalation.ticketCount).toBe(3);
  });
});
