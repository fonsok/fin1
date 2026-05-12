// CSR Portal Types

export interface CustomerSearchResult {
  objectId: string;
  /** Parse _User.objectId */
  userId: string;
  /** Business number (ANL-/TRD-…) */
  customerNumber: string;
  email: string;
  firstName?: string;
  lastName?: string;
  fullName?: string;
  status: string;
  role: string;
  kycStatus?: string;
}

export interface CustomerProfile {
  objectId: string;
  userId: string;
  customerNumber: string;
  email: string;
  firstName?: string;
  lastName?: string;
  fullName?: string;
  status: string;
  role: string;
  kycStatus?: string;
  createdAt: string;
  lastLoginAt?: string;
}

export interface CustomerInvestmentSummary {
  objectId: string;
  traderId: string;
  traderName: string;
  amount: number;
  investedAt: string;
  status: string;
}

export interface CustomerTradeSummary {
  objectId: string;
  traderId: string;
  traderName: string;
  tradeType: string;
  amount: number;
  executedAt: string;
  status: string;
}

export interface CustomerDocumentSummary {
  objectId: string;
  documentType: string;
  fileName: string;
  uploadedAt: string;
  status: string;
}

export interface CustomerKYCStatus {
  status: string;
  level: string;
  verifiedAt?: string;
  expiresAt?: string;
  documents: CustomerDocumentSummary[];
}

export interface SupportTicket {
  objectId: string;
  ticketNumber: string;
  subject: string;
  description: string;
  status: 'open' | 'in_progress' | 'waiting' | 'resolved' | 'closed' | 'archived';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  category: string;
  userId: string;
  userEmail?: string;
  assignedTo?: string;
  assignedToName?: string;
  createdAt: string;
  updatedAt: string;
  resolvedAt?: string;
  closedAt?: string;
  comments?: TicketComment[];
  internalNotes?: TicketComment[];
}

export interface TicketComment {
  objectId: string;
  content: string;
  isInternal: boolean;
  createdBy: string;
  createdByName?: string;
  createdAt: string;
}

export interface CSRAgent {
  objectId: string;
  email: string;
  firstName?: string;
  lastName?: string;
  csrSubRole?: string;
  status: string;
}

export interface TicketMetrics {
  totalTickets: number;
  openTickets: number;
  resolvedTickets: number;
  averageResolutionTime: number;
  averageResponseTime: number;
}

export interface AgentMetrics {
  agentId: string;
  agentName: string;
  ticketsAssigned: number;
  ticketsResolved: number;
  averageResolutionTime: number;
  customerSatisfaction: number;
}
