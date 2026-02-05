import type { SecurityStats, FailedLogin, ActiveSession, SecurityAlert } from './types';

export const mockStats: SecurityStats = {
  failedLoginsToday: 12,
  failedLoginsWeek: 47,
  lockedAccounts: 3,
  activeSessions: 156,
  suspiciousActivities: 2,
};

export const mockFailedLogins: FailedLogin[] = [
  {
    objectId: 'fl1',
    email: 'unknown@example.com',
    ipAddress: '192.168.1.100',
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    timestamp: '2026-02-02T14:30:00Z',
    reason: 'Invalid password',
  },
  {
    objectId: 'fl2',
    email: 'admin@test.com',
    ipAddress: '10.0.0.50',
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)',
    timestamp: '2026-02-02T13:45:00Z',
    reason: 'Account locked',
  },
  {
    objectId: 'fl3',
    email: 'investor@fin1.de',
    ipAddress: '203.0.113.42',
    userAgent: 'curl/7.68.0',
    timestamp: '2026-02-02T12:15:00Z',
    reason: 'Invalid password (attempt 3/5)',
  },
];

export const mockSessions: ActiveSession[] = [
  {
    objectId: 'sess1',
    userId: 'user123',
    email: 'admin@test.com',
    ipAddress: '192.168.178.1',
    device: 'Chrome on macOS',
    createdAt: '2026-02-02T08:00:00Z',
    lastActivity: '2026-02-02T14:30:00Z',
  },
  {
    objectId: 'sess2',
    userId: 'user456',
    email: 'trader@fin1.de',
    ipAddress: '10.0.0.25',
    device: 'FIN1 iOS App',
    createdAt: '2026-02-02T09:15:00Z',
    lastActivity: '2026-02-02T14:28:00Z',
  },
];

export const mockAlerts: SecurityAlert[] = [
  {
    objectId: 'alert1',
    type: 'brute_force',
    severity: 'high',
    message: 'Mehrfache fehlgeschlagene Login-Versuche von IP 203.0.113.42',
    createdAt: '2026-02-02T12:20:00Z',
    reviewed: false,
  },
  {
    objectId: 'alert2',
    type: 'unusual_location',
    severity: 'medium',
    message: 'Login aus ungewöhnlichem Standort (Russland) für Benutzer investor@fin1.de',
    userId: 'user789',
    email: 'investor@fin1.de',
    createdAt: '2026-02-02T10:00:00Z',
    reviewed: false,
  },
  {
    objectId: 'alert3',
    type: 'permission_escalation',
    severity: 'critical',
    message: 'Versuch, Admin-Rechte ohne Autorisierung zu erlangen',
    userId: 'user999',
    email: 'hacker@example.com',
    createdAt: '2026-02-01T22:30:00Z',
    reviewed: true,
  },
];
