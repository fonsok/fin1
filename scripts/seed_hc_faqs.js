/* eslint-disable */
// Seed Help Center FAQs for trader/investor/all roles
// Run inside parse-server container: node -e "require('./cloud/main'); ..." or via docker exec

const helpCenterFAQs = [
  // Security (all roles)
  { q: "Wie kann ich mein Passwort \u00e4ndern?", a: "Gehe zu **Profil > Einstellungen > Passwort \u00e4ndern**. Du ben\u00f6tigst dein aktuelles Passwort und ein neues Passwort mit mindestens 8 Zeichen, einer Zahl und einem Sonderzeichen.", cat: "security", roles: ["all"], order: 1 },
  { q: "Was ist Zwei-Faktor-Authentifizierung (2FA)?", a: "2FA f\u00fcgt eine zus\u00e4tzliche Sicherheitsebene hinzu. Nach der Passworteingabe wird ein einmaliger Code per E-Mail oder SMS gesendet, den du eingeben musst. So ist dein Konto auch bei einem kompromittierten Passwort gesch\u00fctzt.", cat: "security", roles: ["all"], order: 2 },
  { q: "Mein Account wurde gesperrt \u2014 was tun?", a: "Dein Account wird nach mehreren fehlgeschlagenen Anmeldeversuchen automatisch gesperrt. Warte 30 Minuten oder kontaktiere den Support \u00fcber **Hilfe > Kontakt**.", cat: "security", roles: ["all"], order: 3 },

  // Investments (all roles)
  { q: "Wie investiere ich in einen Trading-Pool?", a: "Navigiere zu **Trader entdecken**, w\u00e4hle einen Trader aus und tippe auf **Investieren**. Gib den gew\u00fcnschten Betrag ein (Mindestbetrag beachten) und best\u00e4tige deine Investition.", cat: "investments", roles: ["all"], order: 1 },
  { q: "Wie sehe ich meine aktuelle Rendite?", a: "Deine aktuelle Rendite findest du unter **Investments**. Dort siehst du den aktuellen Wert, die Gesamtrendite und die Performance-Historie jeder Investition.", cat: "investments", roles: ["all"], order: 2 },
  { q: "Kann ich mein Investment vorzeitig beenden?", a: "Ja. Gehe zu **Investments > Investment ausw\u00e4hlen > Auszahlung anfordern**. Beachte: Je nach Pool-Bedingungen kann eine Mindestanlagedauer gelten und es k\u00f6nnen Geb\u00fchren anfallen.", cat: "investments", roles: ["all"], order: 3 },

  // Investor: Investments & Performance (investor only)
  { q: "Wie diversifiziere ich meine Investments?", a: "Wir empfehlen, in mehrere Trader mit unterschiedlichen Handelsstrategien zu investieren. Unter **Trader entdecken** kannst du nach Risikoprofil, Performance und Strategie filtern.", cat: "investor_portfolio", roles: ["investor"], order: 1 },
  { q: "Was bedeuten die verschiedenen Risikostufen?", a: "**Konservativ**: Niedrigere, stabilere Renditen. **Moderat**: Ausgewogenes Verh\u00e4ltnis. **Aggressiv**: H\u00f6heres Renditepotenzial bei h\u00f6herem Risiko. Dein Risikoprofil aus dem Onboarding hilft bei der Auswahl.", cat: "investor_portfolio", roles: ["investor"], order: 2 },

  // Trading (trader only) — Produkt: strukturierte Derivate (kein Kassamarkt-Aktien / Spot-Forex)
  { q: "Wie erstelle ich eine neue Order?", a: "Gehe zu **Trading > Neue Order**. Suche **Derivate** (z. B. Optionsscheine, Zertifikate) per WKN, ISIN oder Name, w\u00e4hle das Produkt, den Ordertyp (Market, Limit, Stop), die Menge und best\u00e4tige. **Kein** eigenst\u00e4ndiger Kassamarkthandel mit Aktien oder Spot-Devisen. Limit- und Stop-Orders erfordern die Angabe eines Preises.", cat: "trading", roles: ["trader"], order: 1 },
  { q: "Was sind die Handelszeiten?", a: "Der Handel mit Derivaten richtet sich nach den relevanten B\u00f6rsenzeiten (z. B. Mo\u2013Fr, Xetra \u00fcbliche Zeiten). Au\u00dferhalb dieser Zeiten werden Orders in die Warteschlange gestellt und bei Markt\u00f6ffnung ausgef\u00fchrt, sofern der Kurs erreicht wird.", cat: "trading", roles: ["trader"], order: 2 },
  { q: "Wie funktionieren Stop-Loss Orders?", a: "Eine Stop-Loss Order wird automatisch als Market-Order ausgef\u00fchrt, wenn der Kurs einen bestimmten Preis erreicht. So begrenzt du potenzielle Verluste. Setze unter **Order > Stop-Loss** deinen gew\u00fcnschten Ausl\u00f6sepreis.", cat: "trading", roles: ["trader"], order: 3 },

  // Trader Pools (trader only)
  { q: "Wie erstelle ich einen Investment-Pool?", a: "Gehe zu **Mein Pool > Pool erstellen**. Definiere Name, Beschreibung, Mindestinvestition, Geb\u00fchrenstruktur und Handelsstrategie. Nach der Freigabe k\u00f6nnen Investoren in deinen Pool investieren.", cat: "trader_pools", roles: ["trader"], order: 1 },
  { q: "Wie verwalte ich Investoren in meinem Pool?", a: "Unter **Mein Pool > Investoren** siehst du alle aktiven Investoren, deren Investitionsbetr\u00e4ge und Aktivit\u00e4ten. Du kannst Auszahlungsanfragen bearbeiten und Investoren-Kommunikation einsehen.", cat: "trader_pools", roles: ["trader"], order: 2 },

  // Invoices (all roles)
  { q: "Wo finde ich meine Rechnungen und Abrechnungen?", a: "Gehe zu **Profil > Rechnungen & Abrechnungen**. Dort kannst du alle Rechnungen als PDF herunterladen. Abrechnungen werden monatlich erstellt.", cat: "invoices", roles: ["all"], order: 1 },
  { q: "Wie exportiere ich Unterlagen f\u00fcr die Steuererkl\u00e4rung?", a: "Unter **Profil > Rechnungen > Steuerexport** kannst du eine Jahres\u00fcbersicht als PDF oder CSV exportieren. Diese enth\u00e4lt alle steuerrelevanten Transaktionen und Ertr\u00e4ge.", cat: "invoices", roles: ["all"], order: 2 },

  // Notifications (all roles)
  { q: "Wie \u00e4ndere ich meine Benachrichtigungseinstellungen?", a: "Gehe zu **Profil > Einstellungen > Benachrichtigungen**. Dort kannst du Push-Benachrichtigungen, E-Mail-Benachrichtigungen und SMS-Benachrichtigungen einzeln aktivieren oder deaktivieren.", cat: "notifications", roles: ["all"], order: 1 },
  { q: "Warum erhalte ich keine Push-Benachrichtigungen?", a: "Pr\u00fcfe: 1) **Ger\u00e4te-Einstellungen > {{APP_NAME}} > Mitteilungen** m\u00fcssen aktiviert sein. 2) In der App: **Profil > Einstellungen > Benachrichtigungen** pr\u00fcfen. 3) Bei weiterem Problem: App neu installieren.", cat: "notifications", roles: ["all"], order: 2 },

  // Technical (all roles)
  { q: "Die App l\u00e4sst sich nicht starten \u2014 was tun?", a: "Versuche: 1) App vollst\u00e4ndig schlie\u00dfen und neu starten. 2) Ger\u00e4t neu starten. 3) App l\u00f6schen und aus dem App Store neu installieren. 4) Pr\u00fcfe, ob genug Speicherplatz verf\u00fcgbar ist. Falls das Problem bestehen bleibt, kontaktiere den Support.", cat: "technical", roles: ["all"], order: 1 },
  { q: "Welche Ger\u00e4te und iOS-Versionen werden unterst\u00fctzt?", a: "{{APP_NAME}} unterst\u00fctzt iPhones ab iPhone 12 mit iOS 16 oder neuer. F\u00fcr die beste Erfahrung empfehlen wir die neueste iOS-Version.", cat: "technical", roles: ["all"], order: 2 },
  { q: "Meine Verbindung zum Server ist instabil", a: "Pr\u00fcfe deine Internetverbindung und versuche, zwischen WLAN und Mobilfunk zu wechseln. Falls das Problem bestehen bleibt, kann es an einer tempor\u00e4ren Server-Wartung liegen \u2014 versuche es in einigen Minuten erneut.", cat: "technical", roles: ["all"], order: 3 }
];

// This will be run via: docker exec parse-server node -e "..."
// Or we can call the Parse REST API directly from the host
module.exports = { helpCenterFAQs };
