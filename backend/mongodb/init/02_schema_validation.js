// ============================================================================
// MongoDB Initialization
// 02_schema_validation.js - Schema Validation Rules
// ============================================================================
//
// Diese Datei definiert Schema-Validierung für kritische Collections.
// MongoDB Schema Validation hilft, Datenintegrität zu gewährleisten.
//
// HINWEIS: Parse Server erstellt Collections automatisch. Diese Validierung
// wird auf bestehende Collections angewendet.
//
// ============================================================================

db = db.getSiblingDB('fin1');

print('=== MongoDB Schema Validation Setup ===');

// ============================================================================
// INVESTMENT VALIDATION
// ============================================================================

print('Setting up validation for Investment collection...');

db.runCommand({
  collMod: "Investment",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["investmentNumber", "investorId", "traderId", "amount", "status"],
      properties: {
        investmentNumber: {
          bsonType: "string",
          pattern: "^INV-[0-9]{4}-[0-9]{7}$",
          description: "Investment number must match pattern INV-YYYY-NNNNNNN"
        },
        investorId: {
          bsonType: "string",
          description: "Investor ID is required"
        },
        traderId: {
          bsonType: "string",
          description: "Trader ID is required"
        },
        amount: {
          bsonType: ["double", "decimal", "int", "long"],
          minimum: 100,
          description: "Amount must be at least 100"
        },
        status: {
          enum: ["reserved", "active", "executing", "paused", "closing", "completed", "cancelled"],
          description: "Status must be a valid investment status"
        },
        serviceChargeRate: {
          bsonType: ["double", "decimal"],
          minimum: 0,
          maximum: 1,
          description: "Service charge rate must be between 0 and 1"
        },
        businessCaseId: {
          bsonType: "string",
          description: "Korrelations-ID für Buchungen/Belege (optional auf Altbeständen)"
        }
      }
    }
  },
  validationLevel: "moderate",  // Nur bei Insert/Update prüfen
  validationAction: "warn"      // Warnen statt ablehnen (für Migration)
});

// ============================================================================
// TRADE VALIDATION
// ============================================================================

print('Setting up validation for Trade collection...');

db.runCommand({
  collMod: "Trade",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["tradeNumber", "traderId", "symbol", "quantity", "buyPrice", "status"],
      properties: {
        tradeNumber: {
          bsonType: ["int", "long"],
          description: "Trade number is required"
        },
        traderId: {
          bsonType: "string",
          description: "Trader ID is required"
        },
        symbol: {
          bsonType: "string",
          minLength: 1,
          maxLength: 50,
          description: "Symbol is required"
        },
        quantity: {
          bsonType: ["double", "decimal", "int", "long"],
          minimum: 0,
          exclusiveMinimum: true,
          description: "Quantity must be positive"
        },
        buyPrice: {
          bsonType: ["double", "decimal"],
          minimum: 0,
          description: "Buy price must be non-negative"
        },
        status: {
          enum: ["pending", "active", "partial", "completed", "cancelled"],
          description: "Status must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// ORDER VALIDATION
// ============================================================================

print('Setting up validation for Order collection...');

db.runCommand({
  collMod: "Order",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["orderNumber", "traderId", "symbol", "side", "orderType", "quantity", "status"],
      properties: {
        orderNumber: {
          bsonType: "string",
          pattern: "^ORD-[0-9]{4}-[0-9]{7}$",
          description: "Order number must match pattern"
        },
        side: {
          enum: ["buy", "sell"],
          description: "Side must be buy or sell"
        },
        orderType: {
          enum: ["market", "limit", "stop", "stop_limit"],
          description: "Order type must be valid"
        },
        quantity: {
          bsonType: ["double", "decimal", "int", "long"],
          minimum: 0,
          exclusiveMinimum: true,
          description: "Quantity must be positive"
        },
        status: {
          enum: ["pending", "submitted", "partial", "executed", "cancelled", "rejected", "expired"],
          description: "Status must be valid"
        },
        timeInForce: {
          enum: ["day", "gtc", "ioc", "fok"],
          description: "Time in force must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// WALLET TRANSACTION VALIDATION
// ============================================================================

print('Setting up validation for WalletTransaction collection...');

db.runCommand({
  collMod: "WalletTransaction",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["transactionNumber", "userId", "transactionType", "amount", "status"],
      properties: {
        transactionNumber: {
          bsonType: "string",
          pattern: "^TXN-[0-9]{4}-[0-9]{7}$",
          description: "Transaction number must match pattern"
        },
        transactionType: {
          enum: [
            "deposit", "withdrawal", "trade_buy", "trade_sell",
            "investment", "investment_return", "profit_distribution",
            "commission_credit", "commission_debit", "service_charge",
            "fee", "adjustment", "transfer_in", "transfer_out", "refund"
          ],
          description: "Transaction type must be valid"
        },
        amount: {
          bsonType: ["double", "decimal", "int", "long"],
          description: "Amount is required"
        },
        status: {
          enum: ["pending", "processing", "completed", "failed", "cancelled", "reversed"],
          description: "Status must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// SUPPORT TICKET VALIDATION
// ============================================================================

print('Setting up validation for SupportTicket collection...');

db.runCommand({
  collMod: "SupportTicket",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ticketNumber", "userId", "subject", "description", "category", "priority", "status"],
      properties: {
        ticketNumber: {
          bsonType: "string",
          pattern: "^TKT-[0-9]{4}-[0-9]{5}$",
          description: "Ticket number must match pattern"
        },
        userId: {
          bsonType: "string",
          description: "Parse _User.objectId of the end customer"
        },
        category: {
          enum: [
            "general", "account_issue", "technical_issue", "billing",
            "investment", "trading_question", "security", "feedback",
            "complaint", "kyc", "fraud_report"
          ],
          description: "Category must be valid"
        },
        priority: {
          enum: ["low", "medium", "high", "urgent"],
          description: "Priority must be valid"
        },
        status: {
          enum: [
            "open", "in_progress", "waiting_for_customer",
            "escalated", "resolved", "closed", "archived"
          ],
          description: "Status must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// COMPLIANCE EVENT VALIDATION
// ============================================================================

print('Setting up validation for ComplianceEvent collection...');

db.runCommand({
  collMod: "ComplianceEvent",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["userId", "eventType", "severity", "description"],
      properties: {
        eventType: {
          enum: [
            "kyc_initiated", "kyc_document_uploaded", "kyc_verified", "kyc_rejected", "kyc_expired",
            "aml_check_passed", "aml_check_failed", "pep_check_positive", "sanction_check_positive",
            "order_placed", "order_executed", "order_cancelled", "trade_completed",
            "appropriateness_check", "risk_warning_shown", "risk_warning_acknowledged",
            "large_transaction", "suspicious_activity", "sar_filed",
            "deposit_received", "withdrawal_requested", "withdrawal_completed",
            "account_created", "account_suspended", "account_reactivated", "account_closed",
            "login_from_new_device", "failed_login_attempt", "password_changed", "two_factor_enabled",
            "data_exported", "data_deleted", "consent_given", "consent_revoked"
          ],
          description: "Event type must be valid"
        },
        severity: {
          enum: ["info", "low", "medium", "high", "critical"],
          description: "Severity must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// FOUR EYES REQUEST VALIDATION
// ============================================================================

print('Setting up validation for FourEyesRequest collection...');

db.runCommand({
  collMod: "FourEyesRequest",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["requestNumber", "requestType", "riskLevel", "requesterId", "requesterJustification", "status"],
      properties: {
        requestNumber: {
          bsonType: "string",
          pattern: "^4E-[0-9]{4}-[0-9]{5}$",
          description: "Request number must match pattern"
        },
        requestType: {
          enum: [
            "account_suspension_extended", "account_suspension_permanent", "account_reactivation",
            "chargeback_over_50", "chargeback_over_500", "refund_over_100",
            "sar_submission", "kyc_manual_approval", "kyc_rejection",
            "gdpr_data_deletion", "gdpr_data_export", "address_change", "name_change"
          ],
          description: "Request type must be valid"
        },
        riskLevel: {
          enum: ["low", "medium", "high", "critical"],
          description: "Risk level must be valid"
        },
        status: {
          enum: ["pending", "approved", "rejected", "expired", "cancelled"],
          description: "Status must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// NOTIFICATION VALIDATION
// ============================================================================

print('Setting up validation for Notification collection...');

db.runCommand({
  collMod: "Notification",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["userId", "type", "category", "title", "message"],
      properties: {
        type: {
          bsonType: "string",
          description: "Notification type is required"
        },
        category: {
          enum: ["investment", "trading", "document", "account", "wallet", "support", "system", "marketing"],
          description: "Category must be valid"
        },
        priority: {
          enum: ["low", "normal", "high", "urgent"],
          description: "Priority must be valid"
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ============================================================================
// FINISH
// ============================================================================

print('');
print('=== MongoDB Schema Validation Setup Complete ===');
print('Validation rules applied to critical collections');
print('Mode: moderate (validates on insert/update)');
print('Action: warn (logs warnings, does not reject)');
print('');
print('To switch to strict mode in production:');
print('  db.runCommand({ collMod: "CollectionName", validationAction: "error" })');
print('');
