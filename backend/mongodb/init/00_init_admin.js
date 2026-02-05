// ============================================================================
// MongoDB Initialization
// 00_init_admin.js - Database and User Setup
// ============================================================================
//
// Diese Datei wird beim ersten Start des MongoDB-Containers ausgeführt.
// Sie erstellt die fin1 Datenbank und den Applikations-User.
//
// HINWEIS: Der Root-User wird über MONGO_INITDB_ROOT_USERNAME/PASSWORD
// in docker-compose.yml erstellt. Dieser Script erstellt den App-User.
//
// ============================================================================

print('=== MongoDB Initialization ===');
print('Setting up database and users...');

// ============================================================================
// CREATE DATABASE AND APP USER
// ============================================================================

// Wechsle zur admin Datenbank für User-Erstellung
db = db.getSiblingDB('admin');

// Authentifiziere als Root (falls nötig)
// Hinweis: Im Init-Script ist man bereits als Root authentifiziert

// Wechsle zur fin1 Datenbank
db = db.getSiblingDB('fin1');

// Erstelle Applikations-User (für Parse Server)
print('Creating application user for fin1 database...');

try {
  db.createUser({
    user: "fin1_app",
    pwd: "fin1-app-password",  // WICHTIG: In Production über ENV-Variable setzen!
    roles: [
      { role: "readWrite", db: "fin1" },
      { role: "dbAdmin", db: "fin1" }
    ]
  });
  print('Application user "fin1_app" created successfully.');
} catch (e) {
  if (e.codeName === 'DuplicateKey' || e.code === 11000) {
    print('Application user "fin1_app" already exists, skipping...');
  } else {
    print('Error creating application user: ' + e.message);
  }
}

// Erstelle Read-Only User für Analytics (optional)
print('Creating read-only user for analytics...');

try {
  db.createUser({
    user: "fin1_analytics",
    pwd: "fin1-analytics-password",  // WICHTIG: In Production über ENV-Variable setzen!
    roles: [
      { role: "read", db: "fin1" }
    ]
  });
  print('Analytics user "fin1_analytics" created successfully.');
} catch (e) {
  if (e.codeName === 'DuplicateKey' || e.code === 11000) {
    print('Analytics user "fin1_analytics" already exists, skipping...');
  } else {
    print('Note: Could not create analytics user: ' + e.message);
  }
}

// ============================================================================
// CREATE INITIAL COLLECTIONS
// ============================================================================
// Parse Server erstellt Collections automatisch, aber wir erstellen
// einige vorab für Schema-Validierung und Indexes

print('Creating initial collections...');

const collections = [
  // Parse System Collections (werden von Parse verwaltet)
  // "_User", "_Session", "_Role" - nicht manuell erstellen

  // Business Collections
  "Investment",
  "InvestmentBatch",
  "PoolTradeParticipation",
  "Commission",
  "InvestorWatchlist",

  "Security",
  "Order",
  "Trade",
  "Holding",
  "MarketData",
  "PriceAlert",
  "TraderWatchlist",
  "WatchlistItem",

  "Invoice",
  "InvoiceItem",
  "WalletTransaction",
  "Document",
  "AccountStatement",

  "Notification",
  "NotificationPreference",
  "NotificationTemplate",

  "FAQCategory",
  "FAQ",
  "FAQFeedback",

  "SupportTicket",
  "TicketResponse",
  "CSRAgent",
  "CSRRole",
  "FourEyesRequest",
  "SatisfactionSurvey",

  "ComplianceEvent",
  "GDPRRequest",
  "AuditLog",
  "DataAccessLog",

  "Config",
  "Announcement",
  "AppVersion",

  "AdminImpersonationLog",
  "UserProfile",
  "UserAddress",
  "UserKYCDocument",
  "UserRiskAssessment",
  "UserConsent",
  "UserDevice"
];

collections.forEach(function(collName) {
  try {
    db.createCollection(collName);
    print('  Created collection: ' + collName);
  } catch (e) {
    if (e.codeName === 'NamespaceExists') {
      print('  Collection exists: ' + collName);
    } else {
      print('  Note: ' + collName + ' - ' + e.message);
    }
  }
});

// ============================================================================
// INITIAL CONFIG DOCUMENT
// ============================================================================

print('Creating initial configuration...');

db.Config.updateOne(
  { _id: "production" },
  {
    $setOnInsert: {
      _id: "production",
      environment: "production",

      server: {
        parseServerPath: "/parse",
        websocketEnabled: true
      },

      financial: {
        orderFeeRate: 0.005,
        orderFeeMin: 5.0,
        orderFeeMax: 50.0,
        exchangeFeeRate: 0.001,
        traderCommissionRate: 0.05,
        platformServiceCharge: 0.015,
        minimumCashReserve: 12.0,
        initialTraderBalance: 50000.0,
        initialInvestorBalance: 25000.0
      },

      features: {
        priceAlertsEnabled: true,
        darkModeEnabled: false,
        biometricAuthEnabled: true,
        pushNotificationsEnabled: true
      },

      limits: {
        minDeposit: 10.0,
        maxDeposit: 100000.0,
        minWithdrawal: 10.0,
        maxWithdrawal: 50000.0,
        dailyTransactionLimit: 10000.0,
        minInvestment: 100.0
      },

      company: {
        name: "Company Investing GmbH",
        address: "Hauptstraße 100",
        city: "60311 Frankfurt am Main",
        email: "info@fin1-investing.com",
        phone: "+49 (0) 69 12345678",
        vatId: "DE123456789",
        registerNumber: "HRB 123456",
        bankIban: "DE89 3704 0044 0532 0130 00",
        bankBic: "COBADEFFXXX"
      },

      security: {
        sessionTimeoutMinutes: 30,
        maxLoginAttempts: 5,
        lockoutDurationMinutes: 15,
        require2FA: false
      },

      maintenance: {
        maintenanceMode: false,
        maintenanceMessage: "Das System wird gewartet."
      },

      createdAt: new Date(),
      updatedAt: new Date()
    }
  },
  { upsert: true }
);

print('Initial configuration created.');

// ============================================================================
// INITIAL FAQ CATEGORIES
// ============================================================================

print('Creating FAQ categories...');

const faqCategories = [
  { slug: "platform_overview", name: "Platform Overview", nameDe: "Plattform-Übersicht", icon: "info.circle", showOnLanding: true, showInHelpCenter: false, sortOrder: 1 },
  { slug: "getting_started", name: "Getting Started", nameDe: "Erste Schritte", icon: "play.circle", showOnLanding: true, showInHelpCenter: false, sortOrder: 2 },
  { slug: "investments", name: "Investments", nameDe: "Investitionen", icon: "chart.line.uptrend.xyaxis", showOnLanding: true, showInHelpCenter: true, sortOrder: 3 },
  { slug: "trading", name: "Trading", nameDe: "Trading", icon: "arrow.left.arrow.right", showOnLanding: false, showInHelpCenter: true, sortOrder: 4 },
  { slug: "portfolio", name: "Portfolio & Performance", nameDe: "Portfolio & Performance", icon: "chart.pie", showOnLanding: false, showInHelpCenter: true, sortOrder: 5 },
  { slug: "invoices", name: "Invoices & Statements", nameDe: "Rechnungen & Auszüge", icon: "doc.text", showOnLanding: false, showInHelpCenter: true, sortOrder: 6 },
  { slug: "security", name: "Security & Authentication", nameDe: "Sicherheit & Authentifizierung", icon: "lock.shield", showOnLanding: false, showInHelpCenter: true, sortOrder: 7 },
  { slug: "notifications", name: "Notifications", nameDe: "Benachrichtigungen", icon: "bell", showOnLanding: false, showInHelpCenter: true, sortOrder: 8 },
  { slug: "technical", name: "Technical Support", nameDe: "Technischer Support", icon: "wrench.and.screwdriver", showOnLanding: false, showInHelpCenter: true, sortOrder: 9 }
];

faqCategories.forEach(function(cat) {
  db.FAQCategory.updateOne(
    { slug: cat.slug },
    {
      $setOnInsert: {
        slug: cat.slug,
        name: cat.name,
        nameDe: cat.nameDe,
        icon: cat.icon,
        showOnLanding: cat.showOnLanding,
        showInHelpCenter: cat.showInHelpCenter,
        showForCsr: true,
        sortOrder: cat.sortOrder,
        isActive: true,
        createdAt: new Date()
      }
    },
    { upsert: true }
  );
});

print('FAQ categories created.');

// ============================================================================
// CSR ROLES
// ============================================================================

print('Creating CSR roles...');

const csrRoles = [
  { name: "level_1", displayName: "Level 1 Support", level: 1 },
  { name: "level_2", displayName: "Level 2 Support", level: 2 },
  { name: "fraud_analyst", displayName: "Fraud Analyst", level: 3 },
  { name: "compliance_officer", displayName: "Compliance Officer", level: 3 },
  { name: "tech_support", displayName: "Technical Support", level: 2 },
  { name: "teamlead", displayName: "Team Lead", level: 4 }
];

csrRoles.forEach(function(role) {
  db.CSRRole.updateOne(
    { name: role.name },
    {
      $setOnInsert: {
        name: role.name,
        displayName: role.displayName,
        level: role.level,
        isActive: true,
        createdAt: new Date()
      }
    },
    { upsert: true }
  );
});

print('CSR roles created.');

// ============================================================================
// FINISH
// ============================================================================

print('');
print('=== MongoDB Initialization Complete ===');
print('');
print('Database: fin1');
print('Users created: fin1_app, fin1_analytics');
print('Collections created: ' + collections.length);
print('');
print('Next steps:');
print('1. Run 01_indexes.js to create indexes');
print('2. Run 02_schema_validation.js to add validation rules');
print('');
