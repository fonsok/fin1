import type { CustomerSearchResult, CustomerProfile, SupportTicket } from '../types';

export interface TicketTemplateContext {
  customerName: string;
  customerEmail?: string;
  customerNumber?: string;
  ticketNumber?: string;
  agentName?: string;
  missingDocuments?: string;
}

function replaceTokenFlexible(haystack: string, token: string, replacement: string): string {
  if (!token) return haystack;
  const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const curly = new RegExp(`\\{\\{\\s*${escaped}\\s*\\}\\}`, 'gi');
  const paren = new RegExp(`\\{\\(\\s*${escaped}\\s*\\)\\}`, 'gi');
  return haystack.replace(curly, replacement).replace(paren, replacement);
}

type CustomerNameFields = {
  fullName?: string;
  firstName?: string;
  lastName?: string;
  email?: string;
};

/** Resolve display name for salutation (never leave raw {{KUNDENNAME}}). */
export function resolveCustomerDisplayName(
  customer: CustomerNameFields | null | undefined,
): string {
  if (!customer) return 'Kunde/Kundin';
  const full = customer.fullName?.trim();
  if (full) return full;
  const combined = `${customer.firstName || ''} ${customer.lastName || ''}`.trim();
  if (combined) return combined;
  const email = customer.email?.trim();
  if (email) {
    const local = email.split('@')[0];
    if (local) return local;
  }
  return 'Kunde/Kundin';
}

export function buildTicketTemplateContext(options: {
  customer?: CustomerSearchResult | null;
  customerProfile?: { fullName?: string; firstName?: string; lastName?: string; email?: string; customerNumber?: string } | null;
  agent?: { firstName?: string; lastName?: string; email?: string } | null;
  ticketNumber?: string;
  missingDocuments?: string;
}): TicketTemplateContext {
  const profile = options.customerProfile;
  const customer = options.customer;
  const merged = {
    fullName: customer?.fullName || profile?.fullName,
    firstName: customer?.firstName || profile?.firstName,
    lastName: customer?.lastName || profile?.lastName,
    email: customer?.email || profile?.email,
  };

  const agentName = options.agent
    ? `${options.agent.firstName || ''} ${options.agent.lastName || ''}`.trim() || options.agent.email || 'Support'
    : 'Ihr FIN1 Support-Team';

  return {
    customerName: resolveCustomerDisplayName(merged),
    customerEmail: merged.email,
    customerNumber: customer?.customerNumber || profile?.customerNumber,
    ticketNumber: options.ticketNumber,
    agentName,
    missingDocuments: options.missingDocuments,
  };
}

/**
 * Replace CSR text template placeholders before inserting into ticket fields.
 */
export function hydrateTicketTemplateText(
  input: string,
  context: TicketTemplateContext,
): string {
  if (!input) return input;

  let out = input;
  const name = context.customerName || 'Kunde/Kundin';
  const agent = context.agentName || 'Ihr FIN1 Support-Team';
  const ticketNo = context.ticketNumber || '—';
  const missingDocs = context.missingDocuments || '—';

  const tokens: Array<[string, string]> = [
    ['KUNDENNAME', name],
    ['CUSTOMER_NAME', name],
    ['customerName', name],
    ['KUNDEN_EMAIL', context.customerEmail || ''],
    ['CUSTOMER_EMAIL', context.customerEmail || ''],
    ['customerEmail', context.customerEmail || ''],
    ['TICKETNUMMER', ticketNo],
    ['TICKET_NUMBER', ticketNo],
    ['ticketNumber', ticketNo],
    ['AGENTNAME', agent],
    ['AGENT_NAME', agent],
    ['agentName', agent],
    ['FEHLENDE_DOKUMENTE', missingDocs],
    ['MISSING_DOCUMENTS', missingDocs],
    ['missingDocuments', missingDocs],
  ];

  tokens.forEach(([token, value]) => {
    out = replaceTokenFlexible(out, token, value);
  });

  return out;
}

/** Build template context from an existing support ticket (bulk respond / detail reply). */
export function buildTicketTemplateContextFromTicket(options: {
  ticket: Pick<SupportTicket, 'userId' | 'userEmail' | 'ticketNumber'>;
  customerProfile?: CustomerProfile | null;
  agent?: { firstName?: string; lastName?: string; email?: string } | null;
}): TicketTemplateContext {
  const { ticket, customerProfile } = options;
  return buildTicketTemplateContext({
    customer: ticket.userId
      ? {
          objectId: ticket.userId,
          userId: ticket.userId,
          customerNumber: customerProfile?.customerNumber ?? '',
          email: ticket.userEmail || customerProfile?.email || '',
          firstName: customerProfile?.firstName,
          lastName: customerProfile?.lastName,
          fullName: customerProfile?.fullName,
          status: customerProfile?.status ?? '',
          role: customerProfile?.role ?? '',
          kycStatus: customerProfile?.kycStatus,
        }
      : null,
    customerProfile,
    agent: options.agent,
    ticketNumber: ticket.ticketNumber,
  });
}
