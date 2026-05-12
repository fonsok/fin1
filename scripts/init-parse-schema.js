#!/usr/bin/env node
/**
 * FIN1 Parse Schema Initialization Script
 * 
 * Creates missing classes and sets CLPs for security.
 * Run this on the server inside the parse-server container or with direct MongoDB access.
 * 
 * Usage: node init-parse-schema.js
 */

const { MongoClient } = require('mongodb');

// Configuration - uses same defaults as parse-server
const MONGODB_URI = process.env.PARSE_SERVER_DATABASE_URI || 'mongodb://mongodb:27017/fin1';
const DB_NAME = 'fin1';

// Schema definitions
const SCHEMAS = {
  FAQItem: {
    className: 'FAQItem',
    fields: {
      objectId: { type: 'String' },
      createdAt: { type: 'Date' },
      updatedAt: { type: 'Date' },
      ACL: { type: 'ACL' },
      categoryId: { type: 'String' },
      question: { type: 'String' },
      answer: { type: 'String' },
      sortOrder: { type: 'Number' },
      isActive: { type: 'Boolean' },
      isPublished: { type: 'Boolean' },
      isPublic: { type: 'Boolean' },
      showOnLanding: { type: 'Boolean' },
      language: { type: 'String' },
      tags: { type: 'Array' },
    },
    classLevelPermissions: {
      find: { '*': true },
      count: { '*': true },
      get: { '*': true },
      create: { requiresAuthentication: true },
      update: { requiresAuthentication: true },
      delete: { requiresAuthentication: true },
      addField: {},
      protectedFields: {},
    },
  },
};

// CLP updates for existing classes (security hardening)
const CLP_UPDATES = {
  // LegalConsent - SENSITIVE! Only Master Key should read/write
  LegalConsent: {
    find: {},  // No public access
    count: {},
    get: {},
    create: {},  // Only via Cloud Code with Master Key
    update: {},
    delete: {},
    addField: {},
    protectedFields: {
      '*': ['userId', 'deviceId', 'ipAddress'],  // Protect sensitive fields
    },
  },
  // LegalDocumentDeliveryLog - Audit log, read-only via Master Key
  LegalDocumentDeliveryLog: {
    find: {},
    count: {},
    get: {},
    create: {},  // Only via Cloud Code
    update: {},
    delete: {},
    addField: {},
    protectedFields: {},
  },
  // TermsContent - Public read (app needs it), no public write
  TermsContent: {
    find: { '*': true },
    count: { '*': true },
    get: { '*': true },
    create: {},  // Admin only
    update: {},
    delete: {},
    addField: {},
    protectedFields: {},
  },
  // FAQCategory - Public read for landing page
  FAQCategory: {
    find: { '*': true },
    count: { '*': true },
    get: { '*': true },
    create: {},
    update: {},
    delete: {},
    addField: {},
    protectedFields: {},
  },
  // ComplianceEvent - No public access
  ComplianceEvent: {
    find: {},
    count: {},
    get: {},
    create: {},  // Only via Cloud Code triggers
    update: {},
    delete: {},
    addField: {},
    protectedFields: {},
  },
};

async function main() {
  console.log('🚀 FIN1 Parse Schema Initialization');
  console.log('=====================================\n');
  
  let client;
  try {
    console.log(`📡 Connecting to MongoDB: ${MONGODB_URI.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')}`);
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    console.log('✅ Connected to MongoDB\n');
    
    const db = client.db(DB_NAME);
    const schemaCollection = db.collection('_SCHEMA');
    
    // 1. Create missing schemas
    console.log('📋 Creating missing schemas...');
    for (const [className, schema] of Object.entries(SCHEMAS)) {
      const existing = await schemaCollection.findOne({ _id: className });
      if (existing) {
        console.log(`  ⏭️  ${className} already exists`);
      } else {
        await schemaCollection.insertOne({
          _id: className,
          objectId: 'string',
          createdAt: 'date',
          updatedAt: 'date',
          ACL: 'object',
          ...Object.fromEntries(
            Object.entries(schema.fields)
              .filter(([k]) => !['objectId', 'createdAt', 'updatedAt', 'ACL'].includes(k))
              .map(([k, v]) => [k, v.type.toLowerCase()])
          ),
          _metadata: {
            class_permissions: schema.classLevelPermissions,
          },
        });
        console.log(`  ✅ Created ${className}`);
        
        // Also create the collection
        try {
          await db.createCollection(className);
          console.log(`  ✅ Created collection ${className}`);
        } catch (e) {
          if (e.code !== 48) throw e; // 48 = collection already exists
        }
      }
    }
    
    // 2. Update CLPs for existing classes
    console.log('\n🔒 Updating Class-Level Permissions (Security)...');
    for (const [className, clp] of Object.entries(CLP_UPDATES)) {
      const existing = await schemaCollection.findOne({ _id: className });
      if (!existing) {
        console.log(`  ⚠️  ${className} does not exist, skipping CLP update`);
        continue;
      }
      
      await schemaCollection.updateOne(
        { _id: className },
        { 
          $set: { 
            '_metadata.class_permissions': clp 
          } 
        }
      );
      console.log(`  ✅ Updated CLPs for ${className}`);
    }
    
    // 3. Create sample FAQ item if FAQItem is empty
    console.log('\n📝 Checking for sample data...');
    const faqItemCollection = db.collection('FAQItem');
    const faqCount = await faqItemCollection.countDocuments();
    if (faqCount === 0) {
      const now = new Date();
      await faqItemCollection.insertMany([
        {
          _id: 'sample_faq_1',
          categoryId: '5XLncFhYLE', // getting_started category
          question: 'Was ist FIN1?',
          answer: 'FIN1 ist eine innovative Investment-App, die es Ihnen ermöglicht, in erfahrene Trader zu investieren und von deren Expertise zu profitieren.',
          sortOrder: 1,
          isActive: true,
          isPublished: true,
          isPublic: true,
          showOnLanding: true,
          language: 'de',
          tags: ['general', 'intro'],
          _created_at: now,
          _updated_at: now,
        },
        {
          _id: 'sample_faq_2',
          categoryId: '5XLncFhYLE',
          question: 'Wie funktioniert die Registrierung?',
          answer: 'Die Registrierung erfolgt in wenigen Schritten: 1. Persönliche Daten eingeben, 2. Identität verifizieren (KYC), 3. Risikoprofil erstellen, 4. Konto aktivieren.',
          sortOrder: 2,
          isActive: true,
          isPublished: true,
          isPublic: true,
          showOnLanding: true,
          language: 'de',
          tags: ['registration', 'getting-started'],
          _created_at: now,
          _updated_at: now,
        },
      ]);
      console.log('  ✅ Created sample FAQ items');
    } else {
      console.log(`  ⏭️  FAQItem has ${faqCount} items, skipping sample data`);
    }
    
    console.log('\n=====================================');
    console.log('✅ Schema initialization complete!');
    console.log('\n⚠️  IMPORTANT: Restart Parse Server to reload schema cache:');
    console.log('   docker compose -f docker-compose.production.yml restart parse-server');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    if (client) {
      await client.close();
      console.log('\n📡 Disconnected from MongoDB');
    }
  }
}

main();
