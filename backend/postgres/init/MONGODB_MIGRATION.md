# MongoDB Migration Guide

## Übersicht

Dieses Dokument beschreibt die Migration des PostgreSQL-Schemas nach MongoDB.
MongoDB verwendet ein dokumentenbasiertes Modell, das für einige Anwendungsfälle
effizienter sein kann.

## Collection-Struktur

### Core Collections (Empfohlen)

```javascript
// 1. users - Benutzerdaten (embedded pattern)
{
  _id: ObjectId,
  customerId: "INV-2024-00001",
  email: "user@example.com",
  role: "investor",
  status: "active",

  // Embedded Profile (1:1)
  profile: {
    salutation: "mr",
    firstName: "Max",
    lastName: "Müller",
    dateOfBirth: ISODate("1985-06-15"),
    preferredLanguage: "de"
  },

  // Embedded Addresses (1:few)
  addresses: [{
    type: "primary",
    street: "Hauptstraße 1",
    postalCode: "60311",
    city: "Frankfurt",
    country: "DE",
    isPrimary: true,
    verified: true
  }],

  // Embedded Settings (1:1)
  securitySettings: {
    biometricEnabled: true,
    twoFactorEnabled: false
  },

  // KYC Summary (embedded)
  kyc: {
    status: "verified",
    verifiedAt: ISODate,
    documents: [{
      type: "id_card",
      status: "verified",
      expiryDate: ISODate
    }]
  },

  // Risk Assessment (embedded)
  riskAssessment: {
    riskClass: 4,
    calculatedAt: ISODate,
    isManualOverride: false
  },

  createdAt: ISODate,
  updatedAt: ISODate
}

// 2. investments - Investitionen
{
  _id: ObjectId,
  investmentNumber: "INV-2024-0000001",
  investorId: ObjectId, // Reference to users
  traderId: ObjectId,   // Reference to users

  amount: Decimal128("5000.00"),
  currentValue: Decimal128("5250.00"),
  profit: Decimal128("250.00"),

  serviceCharge: {
    rate: Decimal128("0.02"),
    amount: Decimal128("100.00"),
    vat: Decimal128("19.00")
  },

  status: "active",

  // Trader Snapshot (denormalized)
  traderSnapshot: {
    name: "Lisa T.",
    specialization: "Derivatives",
    riskClass: 6
  },

  // Pool Participations (embedded array)
  tradeParticipations: [{
    tradeId: ObjectId,
    allocatedAmount: Decimal128("500.00"),
    ownershipPct: Decimal128("2.5"),
    profitShare: Decimal128("25.00"),
    commissionAmount: Decimal128("1.25"),
    settledAt: ISODate
  }],

  createdAt: ISODate,
  activatedAt: ISODate,
  completedAt: null
}

// 3. trades - Trades
{
  _id: ObjectId,
  tradeNumber: 12345,
  traderId: ObjectId,

  // Security Info (denormalized)
  security: {
    symbol: "SAP",
    name: "SAP SE",
    wkn: "716460",
    type: "stock"
  },

  quantity: Decimal128("100"),
  buyPrice: Decimal128("125.50"),

  // Orders embedded
  buyOrder: {
    orderId: ObjectId,
    orderNumber: "ORD-2024-0000001",
    price: Decimal128("125.50"),
    fees: Decimal128("5.00"),
    executedAt: ISODate
  },

  sellOrders: [{
    orderId: ObjectId,
    quantity: Decimal128("50"),
    price: Decimal128("130.00"),
    executedAt: ISODate
  }],

  status: "active",
  grossProfit: Decimal128("225.00"),

  createdAt: ISODate,
  openedAt: ISODate,
  closedAt: null
}

// 4. orders - Orders (separate collection for audit)
{
  _id: ObjectId,
  orderNumber: "ORD-2024-0000001",
  traderId: ObjectId,
  tradeId: ObjectId,
  securityId: ObjectId,

  symbol: "SAP",
  side: "buy",
  orderType: "limit",

  quantity: Decimal128("100"),
  limitPrice: Decimal128("125.50"),
  executedPrice: Decimal128("125.50"),

  fees: [{
    type: "order_fee",
    amount: Decimal128("5.00")
  }],

  status: "executed",

  submittedAt: ISODate,
  executedAt: ISODate
}

// 5. walletTransactions - Konto-Transaktionen (Wallet-Feature deaktiviert)
{
  _id: ObjectId,
  transactionNumber: "TXN-2024-0000001",
  userId: ObjectId,

  type: "deposit",
  amount: Decimal128("1000.00"),
  balanceBefore: Decimal128("500.00"),
  balanceAfter: Decimal128("1500.00"),

  status: "completed",

  reference: {
    type: "investment",
    id: ObjectId
  },

  transactionDate: ISODate,
  completedAt: ISODate
}

// 6. supportTickets - Support Tickets
{
  _id: ObjectId,
  ticketNumber: "TKT-2024-00001",
  customerId: ObjectId,

  subject: "Frage zur Einzahlung",
  description: "...",
  category: "billing",
  priority: "medium",
  status: "open",

  assignedTo: ObjectId, // CSR Agent

  // Responses embedded
  responses: [{
    agentId: ObjectId,
    message: "...",
    type: "message",
    isInternal: false,
    createdAt: ISODate
  }],

  // SLA embedded
  sla: {
    firstResponseTarget: ISODate,
    firstResponseActual: ISODate,
    resolutionTarget: ISODate,
    status: "on_track"
  },

  createdAt: ISODate,
  resolvedAt: null
}

// 7. notifications - Benachrichtigungen
{
  _id: ObjectId,
  userId: ObjectId,

  type: "investment_profit",
  category: "investment",
  priority: "normal",

  content: {
    title: "Gewinn erzielt",
    message: "Ihr Investment hat...",
    titleDe: "...",
    titleEn: "..."
  },

  reference: {
    type: "investment",
    id: ObjectId
  },

  channels: ["in_app", "push"],

  isRead: false,
  readAt: null,

  createdAt: ISODate
}

// 8. config - Configuration (Single Document Pattern)
{
  _id: "production", // environment name as _id

  server: {
    parseServerPath: "/parse",
    websocketEnabled: true
  },

  financial: {
    orderFeeRate: 0.005,
    orderFeeMin: 5.0,
    orderFeeMax: 50.0,
    traderCommissionRate: 0.05
  },

  features: {
    priceAlertsEnabled: true,
    darkModeEnabled: false
  },

  limits: {
    minDeposit: 10,
    maxDeposit: 100000,
    dailyTransactionLimit: 10000
  },

  company: {
    name: "Company Investing GmbH",
    email: "info@fin1-investing.com"
  },

  updatedAt: ISODate
}

// 9. faqs - FAQs
{
  _id: ObjectId,
  categorySlug: "investments",

  question: "Wie investiere ich?",
  questionDe: "...",
  questionEn: "...",

  answer: "...",
  answerDe: "...",

  visibility: {
    isPublic: true,
    isUserVisible: true,
    isCsrVisible: true
  },

  tags: ["investment", "start"],

  stats: {
    viewCount: 150,
    helpfulCount: 45,
    notHelpfulCount: 3
  },

  sortOrder: 1,
  isPublished: true
}

// 10. complianceEvents - Compliance Audit Trail
{
  _id: ObjectId,
  userId: ObjectId,

  eventType: "large_transaction",
  severity: "medium",
  description: "Transaction over €10,000",

  metadata: {
    transactionId: ObjectId,
    amount: Decimal128("15000.00")
  },

  regulatoryFlags: ["gwg", "aml"],

  review: {
    required: true,
    completed: false,
    reviewedBy: null,
    reviewedAt: null
  },

  occurredAt: ISODate,
  retentionUntil: ISODate("2034-01-01")
}
```

## Migration Script Template

```javascript
// migrate_users.js
const { MongoClient } = require('mongodb');
const { Pool } = require('pg');

async function migrateUsers() {
  const pg = new Pool({ connectionString: process.env.POSTGRES_URL });
  const mongo = await MongoClient.connect(process.env.MONGO_URL);
  const db = mongo.db('fin1');

  // Fetch users with all related data
  const result = await pg.query(`
    SELECT
      u.*,
      up.*,
      json_agg(DISTINCT ua.*) as addresses,
      ct.*,
      ra.*
    FROM users u
    LEFT JOIN user_profiles up ON u.id = up.user_id
    LEFT JOIN user_addresses ua ON u.id = ua.user_id
    LEFT JOIN user_citizenship_tax ct ON u.id = ct.user_id
    LEFT JOIN v_current_risk_assessment ra ON u.id = ra.user_id
    GROUP BY u.id, up.id, ct.id, ra.user_id, ra.risk_class
  `);

  for (const row of result.rows) {
    const doc = {
      _id: row.id,  // Keep UUID as _id
      customerId: row.customer_id,
      email: row.email,
      role: row.role,
      status: row.status,

      profile: {
        firstName: row.first_name,
        lastName: row.last_name,
        dateOfBirth: row.date_of_birth
      },

      addresses: row.addresses.filter(a => a).map(a => ({
        type: a.address_type,
        street: a.street,
        city: a.city,
        postalCode: a.postal_code
      })),

      riskAssessment: row.risk_class ? {
        riskClass: row.risk_class,
        isManualOverride: row.is_manual_override
      } : null,

      createdAt: row.created_at,
      updatedAt: row.updated_at
    };

    await db.collection('users').insertOne(doc);
  }

  console.log(`Migrated ${result.rows.length} users`);
}
```

## Index Recommendations

```javascript
// MongoDB Indexes
db.users.createIndex({ customerId: 1 }, { unique: true });
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ role: 1, status: 1 });

db.investments.createIndex({ investorId: 1, status: 1 });
db.investments.createIndex({ traderId: 1, status: 1 });
db.investments.createIndex({ investmentNumber: 1 }, { unique: true });

db.trades.createIndex({ traderId: 1, status: 1 });
db.trades.createIndex({ "security.symbol": 1 });

db.walletTransactions.createIndex({ userId: 1, completedAt: -1 });
db.walletTransactions.createIndex({ transactionNumber: 1 }, { unique: true });

db.supportTickets.createIndex({ customerId: 1 });
db.supportTickets.createIndex({ assignedTo: 1, status: 1 });
db.supportTickets.createIndex({ status: 1, priority: 1 });

db.notifications.createIndex({ userId: 1, isRead: 1, createdAt: -1 });

db.complianceEvents.createIndex({ userId: 1, occurredAt: -1 });
db.complianceEvents.createIndex({ "review.required": 1, "review.completed": 1 });
```

## Parse Server Integration

Parse Server verwendet MongoDB nativ. Die Collections werden automatisch erstellt.
Für Custom Classes in Parse können die obigen Strukturen verwendet werden.

```javascript
// Parse Cloud Code Example
Parse.Cloud.define('getInvestmentDetails', async (request) => {
  const Investment = Parse.Object.extend('Investment');
  const query = new Parse.Query(Investment);
  query.equalTo('investorId', request.user.id);
  query.include('tradeParticipations');
  return await query.find();
});
```

## Backup & Restore

```bash
# MongoDB Backup
mongodump --uri="mongodb://localhost:27017/fin1" --out=/backup/fin1

# Restore
mongorestore --uri="mongodb://localhost:27017/fin1" /backup/fin1
```
