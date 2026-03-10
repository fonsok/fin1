// CSR Template Types

export interface ResponseTemplate {
  id: string;
  templateKey?: string;
  title: string;
  category: string;
  subject?: string;
  body: string;
  isEmail: boolean;
  placeholders: string[];
  shortcut?: string;
  usageCount: number;
  isDefault: boolean;
  version: number;
  updatedAt?: string;
}

export interface EmailTemplate {
  id: string;
  type: string;
  displayName: string;
  icon?: string;
  subject: string;
  bodyTemplate: string;
  availablePlaceholders: string[];
  isActive: boolean;
  version: number;
  updatedAt?: string;
}

export interface TemplateCategory {
  id: string;
  key: string;
  displayName: string;
  icon: string;
  sortOrder: number;
}

export interface TemplateUsageStats {
  period: {
    start: string;
    end: string;
    days: number;
  };
  totalUsage: number;
  topTemplates: Array<{
    id: string;
    title: string;
    category: string;
    usageCount: number;
  }>;
  agentUsage: Array<{
    agentId: string;
    usageCount: number;
  }>;
}

export interface CreateTemplateRequest {
  templateKey?: string;
  title: string;
  titleDe?: string;
  categoryKey: string;
  subject?: string;
  subjectDe?: string;
  body: string;
  bodyDe?: string;
  isEmail?: boolean;
  availableForRoles?: string[];
  placeholders?: string[];
  shortcut?: string;
}

export interface UpdateTemplateRequest {
  title?: string;
  titleDe?: string;
  categoryKey?: string;
  subject?: string;
  subjectDe?: string;
  body?: string;
  bodyDe?: string;
  isEmail?: boolean;
  availableForRoles?: string[];
  placeholders?: string[];
  shortcut?: string;
  isActive?: boolean;
}

// CSR Roles
export const CSR_ROLES = [
  { key: 'level_1', label: 'Level 1 Support' },
  { key: 'level_2', label: 'Level 2 Support' },
  { key: 'fraud_analyst', label: 'Fraud Analyst' },
  { key: 'compliance_officer', label: 'Compliance Officer' },
  { key: 'tech_support', label: 'Technical Support' },
  { key: 'teamlead', label: 'Teamleiter' },
] as const;

// Template Categories
export const TEMPLATE_CATEGORIES = [
  { key: 'greeting', label: 'Begrüßung', icon: '👋' },
  { key: 'closing', label: 'Abschluss', icon: '🏁' },
  { key: 'account_issues', label: 'Kontoprobleme', icon: '👤' },
  { key: 'kyc_onboarding', label: 'KYC & Onboarding', icon: '✅' },
  { key: 'transactions', label: 'Transaktionen', icon: '💰' },
  { key: 'technical', label: 'Technischer Support', icon: '🔧' },
  { key: 'billing', label: 'Abrechnung', icon: '💳' },
  { key: 'security', label: 'Sicherheit', icon: '🔒' },
  { key: 'compliance', label: 'Compliance', icon: '📋' },
  { key: 'fraud', label: 'Betrugsprävention', icon: '⚠️' },
  { key: 'escalation', label: 'Eskalation', icon: '⬆️' },
  { key: 'general', label: 'Allgemein', icon: '📄' },
] as const;
