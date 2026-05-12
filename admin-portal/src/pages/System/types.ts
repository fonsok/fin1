// System Health types

export interface ServiceStatus {
  name: string;
  status: 'healthy' | 'degraded' | 'down' | 'unknown';
  responseTime?: number;
  lastCheck: string;
  details?: string;
}

export interface DatabaseStatus {
  name: string;
  connected: boolean;
  version?: string;
  collections?: number;
  size?: string;
}

export interface SystemHealth {
  /** `unknown` = client could not load status (e.g. network/auth), not a confirmed outage */
  overall: 'healthy' | 'degraded' | 'down' | 'unknown';
  services: ServiceStatus[];
  databases: DatabaseStatus[];
  serverTime: string;
  uptime: number;
  version: string;
  nodeVersion?: string;
  totalResponseTime?: number;
}
