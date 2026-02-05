export interface SecurityStats {
  failedLoginsToday: number;
  failedLoginsWeek: number;
  lockedAccounts: number;
  activeSessions: number;
  suspiciousActivities: number;
}

export interface FailedLogin {
  objectId: string;
  email: string;
  ipAddress: string;
  userAgent: string;
  timestamp: string;
  reason: string;
}

export interface ActiveSession {
  objectId: string;
  userId: string;
  email: string;
  ipAddress: string;
  device: string;
  createdAt: string;
  lastActivity: string;
}

export interface SecurityAlert {
  objectId: string;
  type: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  userId?: string;
  email?: string;
  createdAt: string;
  reviewed: boolean;
}

export type TabType = 'overview' | 'logins' | 'sessions' | 'alerts';
