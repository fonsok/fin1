// ============================================================================
// CSR Ticket Templates - Default Fallback Templates
// ============================================================================
// These templates are used as fallback when the backend API is unavailable.
// Backend templates are loaded from CSRResponseTemplate collection via
// getResponseTemplates() cloud function.

export interface TicketSubjectTemplate {
  id: string;
  title: string;
  category: string;
}

export interface TicketDescriptionTemplate {
  id: string;
  title: string;
  category: string;
  body: string;
}

// Default SUBJECT templates - kurze, prägnante Betreffzeilen
export const defaultSubjectTemplates: TicketSubjectTemplate[] = [
  // Kontoprobleme
  { id: 'subj-1', title: 'Kontosperrung aufheben', category: 'account_issues' },
  { id: 'subj-2', title: 'Passwort zurücksetzen', category: 'account_issues' },
  { id: 'subj-3', title: 'Anmeldeproblem', category: 'account_issues' },
  { id: 'subj-4', title: 'E-Mail-Adresse ändern', category: 'account_issues' },
  { id: 'subj-5', title: 'Zwei-Faktor-Authentifizierung', category: 'account_issues' },
  // KYC
  { id: 'subj-6', title: 'KYC-Dokumente nachfordern', category: 'kyc_onboarding' },
  { id: 'subj-7', title: 'KYC-Verifizierung abgelehnt', category: 'kyc_onboarding' },
  { id: 'subj-8', title: 'KYC-Status prüfen', category: 'kyc_onboarding' },
  { id: 'subj-9', title: 'Adressnachweis erforderlich', category: 'kyc_onboarding' },
  // Technisch
  { id: 'subj-10', title: 'App-Fehler beheben', category: 'technical' },
  { id: 'subj-11', title: 'App-Update erforderlich', category: 'technical' },
  { id: 'subj-12', title: 'Verbindungsproblem', category: 'technical' },
  { id: 'subj-13', title: 'Push-Benachrichtigungen', category: 'technical' },
  // Finanzen
  { id: 'subj-14', title: 'Rückerstattung bearbeiten', category: 'billing' },
  { id: 'subj-15', title: 'Transaktion prüfen', category: 'billing' },
  { id: 'subj-16', title: 'Gebühren erklären', category: 'billing' },
  { id: 'subj-17', title: 'Kontoauszug anfordern', category: 'billing' },
  // Allgemein
  { id: 'subj-18', title: 'Allgemeine Anfrage', category: 'general' },
  { id: 'subj-19', title: 'Feedback erhalten', category: 'general' },
  { id: 'subj-20', title: 'Beschwerde bearbeiten', category: 'general' },
];

// Default DESCRIPTION templates - ausführliche Antworttexte
export const defaultDescriptionTemplates: TicketDescriptionTemplate[] = [
  // Begrüßungen
  {
    id: 'desc-1',
    title: 'Standard-Begrüßung',
    category: 'greeting',
    body: 'Guten Tag,\n\nvielen Dank für Ihre Nachricht. Ich werde mich um Ihr Anliegen kümmern.',
  },
  {
    id: 'desc-2',
    title: 'Formelle Begrüßung',
    category: 'greeting',
    body: 'Sehr geehrte/r Kunde/Kundin,\n\nvielen Dank für Ihre Kontaktaufnahme. Ich freue mich, Ihnen helfen zu können.',
  },
  // Kontoprobleme
  {
    id: 'desc-3',
    title: 'Konto entsperrt',
    category: 'account_issues',
    body: 'Ihr Konto wurde erfolgreich entsperrt. Sie können sich jetzt wieder anmelden.\n\nWichtige Sicherheitshinweise:\n• Verwenden Sie ein starkes, einzigartiges Passwort\n• Aktivieren Sie die Zwei-Faktor-Authentifizierung (2FA)\n• Melden Sie verdächtige Aktivitäten sofort',
  },
  {
    id: 'desc-4',
    title: 'Passwort-Reset Anleitung',
    category: 'account_issues',
    body: 'Um Ihr Passwort zurückzusetzen, gehen Sie bitte wie folgt vor:\n\n1. Öffnen Sie die App\n2. Tippen Sie auf "Anmelden"\n3. Wählen Sie "Passwort vergessen?"\n4. Geben Sie Ihre E-Mail-Adresse ein\n5. Sie erhalten einen Link zum Zurücksetzen per E-Mail\n\nDer Link ist 24 Stunden gültig. Falls Sie keine E-Mail erhalten, prüfen Sie bitte auch Ihren Spam-Ordner.',
  },
  // KYC
  {
    id: 'desc-5',
    title: 'KYC-Dokumente anfordern',
    category: 'kyc_onboarding',
    body: 'Zur Vervollständigung Ihrer Identitätsprüfung (KYC) benötigen wir noch folgende Unterlagen:\n\n• Gültiger Personalausweis oder Reisepass (Vorder- und Rückseite)\n• Aktueller Adressnachweis (nicht älter als 3 Monate)\n\nAnforderungen an die Dokumente:\n• Gut lesbar und vollständig sichtbar\n• Gültiges Ablaufdatum\n• Maximal 10 MB pro Datei (JPG, PNG oder PDF)\n\nBitte laden Sie die Dokumente in der App unter "Profil" → "Dokumente" hoch.',
  },
  {
    id: 'desc-6',
    title: 'KYC erfolgreich',
    category: 'kyc_onboarding',
    body: 'Ihre Identitätsprüfung (KYC) wurde erfolgreich abgeschlossen. Sie haben nun vollen Zugriff auf alle Funktionen der App.\n\nVielen Dank für Ihre Geduld!',
  },
  // Technisch
  {
    id: 'desc-7',
    title: 'App-Update erforderlich',
    category: 'technical',
    body: 'Bitte aktualisieren Sie die App auf die neueste Version:\n\n• iOS: App Store → Updates → FIN1\n• Android: Play Store → Meine Apps → FIN1\n\nDie neueste Version behebt bekannte Probleme und verbessert die Stabilität.',
  },
  {
    id: 'desc-8',
    title: 'Cache leeren Anleitung',
    category: 'technical',
    body: 'Bitte versuchen Sie folgende Schritte:\n\n1. App vollständig schließen (nicht nur minimieren)\n2. In den Geräte-Einstellungen → Apps → FIN1 → Cache leeren\n3. Gerät neu starten\n4. App erneut öffnen\n\nSollte das Problem weiterhin bestehen, melden Sie sich bitte erneut.',
  },
  {
    id: 'desc-9',
    title: 'Neuinstallation empfohlen',
    category: 'technical',
    body: 'Wir empfehlen eine Neuinstallation der App:\n\n1. App deinstallieren\n2. Gerät neu starten\n3. App erneut aus dem App Store/Play Store installieren\n4. Mit Ihren Zugangsdaten anmelden\n\nIhre Daten bleiben dabei erhalten, da sie serverseitig gespeichert sind.',
  },
  // Finanzen
  {
    id: 'desc-10',
    title: 'Rückerstattung eingeleitet',
    category: 'billing',
    body: 'Ich habe eine Rückerstattung für Sie eingeleitet. Der Betrag wird innerhalb von 5-7 Werktagen auf Ihrem Konto gutgeschrieben.\n\nBitte beachten Sie, dass die tatsächliche Gutschrift von Ihrer Bank abhängt.',
  },
  {
    id: 'desc-11',
    title: 'Transaktion wird geprüft',
    category: 'billing',
    body: 'Wir haben Ihre Anfrage zur Transaktionsprüfung erhalten. Unser Team wird den Vorgang innerhalb von 2-3 Werktagen prüfen.\n\nSie erhalten eine Benachrichtigung, sobald die Prüfung abgeschlossen ist.',
  },
  // Abschlüsse
  {
    id: 'desc-12',
    title: 'Standard-Abschluss',
    category: 'closing',
    body: 'Bei weiteren Fragen stehe ich Ihnen gerne zur Verfügung.\n\nMit freundlichen Grüßen,\nIhr FIN1 Kundenservice',
  },
  {
    id: 'desc-13',
    title: 'Problem gelöst',
    category: 'closing',
    body: 'Es freut mich, dass wir Ihr Anliegen lösen konnten. Falls Sie weitere Unterstützung benötigen, melden Sie sich gerne.\n\nMit freundlichen Grüßen,\nIhr FIN1 Kundenservice',
  },
  {
    id: 'desc-14',
    title: 'Weiteres Vorgehen',
    category: 'closing',
    body: 'Ich werde Ihr Anliegen an die zuständige Fachabteilung weiterleiten. Sie erhalten innerhalb von 2 Werktagen eine Rückmeldung.\n\nVielen Dank für Ihre Geduld.',
  },
];

// Category icons for template display
export function getCategoryIcon(category: string): string {
  const icons: Record<string, string> = {
    greeting: '👋',
    closing: '🏁',
    account_issues: '👤',
    kyc_onboarding: '📋',
    technical: '🔧',
    billing: '💰',
    general: '📄',
  };
  return icons[category] || '📝';
}
