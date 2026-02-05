/**
 * German translations (default)
 * i18n-ready structure for future expansion
 */
export const de = {
  // Common
  common: {
    loading: 'Laden...',
    save: 'Speichern',
    cancel: 'Abbrechen',
    delete: 'Löschen',
    edit: 'Bearbeiten',
    search: 'Suchen',
    filter: 'Filtern',
    export: 'Exportieren',
    refresh: 'Aktualisieren',
    back: 'Zurück',
    next: 'Weiter',
    confirm: 'Bestätigen',
    yes: 'Ja',
    no: 'Nein',
    all: 'Alle',
    none: 'Keine',
    actions: 'Aktionen',
    details: 'Details',
    created: 'Erstellt',
    updated: 'Aktualisiert',
    status: 'Status',
    error: 'Fehler',
    success: 'Erfolgreich',
  },

  // Auth
  auth: {
    login: 'Anmelden',
    logout: 'Abmelden',
    email: 'E-Mail',
    password: 'Passwort',
    loginTitle: 'Admin-Portal Anmeldung',
    loginSubtitle: 'Melden Sie sich mit Ihrem Admin-Konto an',
    loginButton: 'Anmelden',
    loginError: 'Anmeldung fehlgeschlagen',
    invalidCredentials: 'Ungültige Anmeldedaten',
    noAccess: 'Kein Zugriff. Nur Admin-Rollen erlaubt.',
    sessionExpired: 'Sitzung abgelaufen. Bitte erneut anmelden.',
    twoFactor: {
      title: 'Zwei-Faktor-Authentifizierung',
      subtitle: 'Geben Sie den Code aus Ihrer Authenticator-App ein',
      code: '6-stelliger Code',
      verify: 'Verifizieren',
      invalid: 'Ungültiger Code',
      setup: '2FA einrichten',
      setupRequired: '2FA ist für Ihre Rolle erforderlich',
    },
  },

  // Navigation
  nav: {
    dashboard: 'Dashboard',
    users: 'Benutzer',
    tickets: 'Tickets',
    compliance: 'Compliance',
    finance: 'Finanzen',
    security: 'Sicherheit',
    approvals: 'Freigaben',
    audit: 'Audit-Logs',
    settings: 'Einstellungen',
  },

  // Dashboard
  dashboard: {
    title: 'Dashboard',
    welcome: 'Willkommen',
    stats: {
      totalUsers: 'Benutzer gesamt',
      activeUsers: 'Aktive Benutzer',
      pendingUsers: 'Ausstehend',
      suspendedUsers: 'Gesperrt',
      openTickets: 'Offene Tickets',
      pendingReviews: 'Ausstehende Reviews',
      pendingApprovals: 'Ausstehende Freigaben',
    },
  },

  // Users
  users: {
    title: 'Benutzerverwaltung',
    search: 'Benutzer suchen...',
    searchPlaceholder: 'Name, E-Mail oder Kunden-ID',
    noResults: 'Keine Benutzer gefunden',
    details: 'Benutzerdetails',
    customerId: 'Kunden-ID',
    email: 'E-Mail',
    role: 'Rolle',
    status: 'Status',
    kycStatus: 'KYC-Status',
    lastLogin: 'Letzter Login',
    createdAt: 'Registriert',
    actions: {
      suspend: 'Sperren',
      reactivate: 'Reaktivieren',
      resetPassword: 'Passwort zurücksetzen',
      viewDetails: 'Details anzeigen',
    },
    statusValues: {
      active: 'Aktiv',
      pending: 'Ausstehend',
      suspended: 'Gesperrt',
      locked: 'Gesperrt',
      closed: 'Geschlossen',
      deleted: 'Gelöscht',
    },
    roles: {
      investor: 'Anleger',
      trader: 'Händler',
      admin: 'Administrator',
      business_admin: 'Finance Admin',
      security_officer: 'Security Officer',
      compliance: 'Compliance',
      customer_service: 'Kundenservice',
    },
  },

  // Tickets
  tickets: {
    title: 'Support-Tickets',
    new: 'Neues Ticket',
    open: 'Offen',
    pending: 'Wartend',
    resolved: 'Gelöst',
    closed: 'Geschlossen',
    priority: {
      low: 'Niedrig',
      medium: 'Mittel',
      high: 'Hoch',
      urgent: 'Dringend',
    },
  },

  // Compliance
  compliance: {
    title: 'Compliance-Events',
    events: 'Events',
    reviews: 'Reviews',
    severity: {
      low: 'Niedrig',
      medium: 'Mittel',
      high: 'Hoch',
      critical: 'Kritisch',
    },
    markReviewed: 'Als geprüft markieren',
  },

  // Finance
  finance: {
    title: 'Finanzen',
    revenue: 'Umsatz',
    fees: 'Gebühren',
    corrections: 'Korrekturen',
    roundingDiffs: 'Rundungsdifferenzen',
  },

  // Security
  security: {
    title: 'Sicherheit',
    failedLogins: 'Fehlgeschlagene Logins',
    lockedAccounts: 'Gesperrte Konten',
    suspiciousActivity: 'Verdächtige Aktivitäten',
    terminateSession: 'Session beenden',
  },

  // Approvals
  approvals: {
    title: '4-Augen-Freigaben',
    pending: 'Ausstehend',
    approved: 'Genehmigt',
    rejected: 'Abgelehnt',
    approve: 'Genehmigen',
    reject: 'Ablehnen',
    reason: 'Begründung',
  },

  // Audit
  audit: {
    title: 'Audit-Logs',
    logType: 'Log-Typ',
    action: 'Aktion',
    user: 'Benutzer',
    resource: 'Ressource',
    timestamp: 'Zeitstempel',
  },

  // Errors
  errors: {
    generic: 'Ein Fehler ist aufgetreten',
    network: 'Netzwerkfehler',
    unauthorized: 'Nicht autorisiert',
    forbidden: 'Zugriff verweigert',
    notFound: 'Nicht gefunden',
  },
};

// Type for translations
export type Translations = typeof de;

// Current language (simple implementation)
let currentLang = de;

export function t(key: string): string {
  const keys = key.split('.');
  let value: unknown = currentLang;

  for (const k of keys) {
    if (value && typeof value === 'object' && k in value) {
      value = (value as Record<string, unknown>)[k];
    } else {
      return key; // Return key if translation not found
    }
  }

  return typeof value === 'string' ? value : key;
}

export function setLanguage(translations: Translations): void {
  currentLang = translations;
}
