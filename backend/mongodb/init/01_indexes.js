// ============================================================================
// MongoDB Initialization
// 01_indexes.js - Index Definitions
// ============================================================================
//
// Diese Datei wird beim ersten Start des MongoDB-Containers ausgeführt.
// Sie erstellt alle notwendigen Indexes für optimale Performance.
//
// ============================================================================

// Wechsle zur App-Datenbank (Parse / FIN1)
db = db.getSiblingDB('fin1');

print('=== MongoDB Index Setup ===');
print('Creating indexes for optimal performance...');

// ============================================================================
// USER COLLECTIONS
// ============================================================================

// _User (Parse Standard Collection)
print('Creating indexes for _User...');
db._User.createIndex({ "email": 1 }, { unique: true, sparse: true });
db._User.createIndex({ "username": 1 }, { unique: true, sparse: true });
db._User.createIndex({ "customerNumber": 1 }, { unique: true, sparse: true });
db._User.createIndex({ "role": 1, "status": 1 });
db._User.createIndex({ "kycStatus": 1 });
db._User.createIndex({ "createdAt": -1 });

// UserProfile (Extended user data)
print('Creating indexes for UserProfile...');
db.UserProfile.createIndex({ "userId": 1 }, { unique: true });
db.UserProfile.createIndex({ "lastName": 1, "firstName": 1 });

// UserAddress
print('Creating indexes for UserAddress...');
db.UserAddress.createIndex({ "userId": 1 });
db.UserAddress.createIndex({ "userId": 1, "addressType": 1 });

// UserKYCDocument
print('Creating indexes for UserKYCDocument...');
db.UserKYCDocument.createIndex({ "userId": 1 });
db.UserKYCDocument.createIndex({ "userId": 1, "documentType": 1 });
db.UserKYCDocument.createIndex({ "verificationStatus": 1 });
db.UserKYCDocument.createIndex({ "expiryDate": 1 });

// UserRiskAssessment
print('Creating indexes for UserRiskAssessment...');
db.UserRiskAssessment.createIndex({ "userId": 1, "validFrom": -1 });
db.UserRiskAssessment.createIndex({ "userId": 1, "validUntil": 1 });

// UserConsent
print('Creating indexes for UserConsent...');
db.UserConsent.createIndex({ "userId": 1, "consentType": 1 });

// UserDevice
print('Creating indexes for UserDevice...');
db.UserDevice.createIndex({ "userId": 1 });
db.UserDevice.createIndex({ "userId": 1, "deviceId": 1 }, { unique: true });

// UserSession (Parse _Session)
print('Creating indexes for _Session...');
db._Session.createIndex({ "user": 1 });
db._Session.createIndex({ "expiresAt": 1 }, { expireAfterSeconds: 0 });

// ============================================================================
// INVESTMENT COLLECTIONS
// ============================================================================

print('Creating indexes for Investment...');
db.Investment.createIndex({ "investmentNumber": 1 }, { unique: true });
db.Investment.createIndex({ "investorId": 1, "status": 1 });
db.Investment.createIndex({ "traderId": 1, "status": 1 });
db.Investment.createIndex({ "status": 1 });
db.Investment.createIndex({ "createdAt": -1 });
db.Investment.createIndex({ "activatedAt": -1 });

// InvestmentBatch
print('Creating indexes for InvestmentBatch...');
db.InvestmentBatch.createIndex({ "batchNumber": 1 }, { unique: true });
db.InvestmentBatch.createIndex({ "investorId": 1 });

// PoolTradeParticipation
print('Creating indexes for PoolTradeParticipation...');
db.PoolTradeParticipation.createIndex({ "investmentId": 1 });
db.PoolTradeParticipation.createIndex({ "tradeId": 1 });
db.PoolTradeParticipation.createIndex({ "investmentId": 1, "tradeId": 1 }, { unique: true });
db.PoolTradeParticipation.createIndex({ "isSettled": 1 });

// Commission
print('Creating indexes for Commission...');
db.Commission.createIndex({ "commissionNumber": 1 }, { unique: true });
db.Commission.createIndex({ "traderId": 1 });
db.Commission.createIndex({ "investorId": 1 });
db.Commission.createIndex({ "investmentId": 1 });
db.Commission.createIndex({ "status": 1 });

// InvestorWatchlist
print('Creating indexes for InvestorWatchlist...');
db.InvestorWatchlist.createIndex({ "investorId": 1, "traderId": 1 }, { unique: true });

// ============================================================================
// TRADING COLLECTIONS
// ============================================================================

print('Creating indexes for Security...');
db.Security.createIndex({ "symbol": 1, "exchange": 1 }, { unique: true });
db.Security.createIndex({ "isin": 1 }, { sparse: true });
db.Security.createIndex({ "wkn": 1 }, { sparse: true });
db.Security.createIndex({ "securityType": 1 });
db.Security.createIndex({ "name": "text", "symbol": "text" }); // Full-text search

print('Creating indexes for Order...');
db.Order.createIndex({ "orderNumber": 1 }, { unique: true });
db.Order.createIndex({ "traderId": 1 });
db.Order.createIndex({ "tradeId": 1 }, { sparse: true });
db.Order.createIndex({ "status": 1 });
db.Order.createIndex({ "traderId": 1, "status": 1 });
db.Order.createIndex({ "symbol": 1 });
db.Order.createIndex({ "createdAt": -1 });
db.Order.createIndex({ "executedAt": -1 }, { sparse: true });

print('Creating indexes for Trade...');
db.Trade.createIndex({ "tradeNumber": 1 }, { unique: true });
db.Trade.createIndex({ "traderId": 1 });
db.Trade.createIndex({ "traderId": 1, "status": 1 });
db.Trade.createIndex({ "status": 1 });
db.Trade.createIndex({ "symbol": 1 });
db.Trade.createIndex({ "createdAt": -1 });
db.Trade.createIndex({ "openedAt": -1 }, { sparse: true });
db.Trade.createIndex({ "closedAt": -1 }, { sparse: true });

print('Creating indexes for Holding...');
db.Holding.createIndex({ "positionNumber": 1 }, { unique: true });
db.Holding.createIndex({ "traderId": 1 });
db.Holding.createIndex({ "traderId": 1, "status": 1 });
db.Holding.createIndex({ "symbol": 1 });

print('Creating indexes for MarketData...');
db.MarketData.createIndex({ "symbol": 1, "timestamp": -1 });
db.MarketData.createIndex({ "symbol": 1, "exchange": 1, "timestamp": -1 });
// TTL Index: Lösche Marktdaten älter als 90 Tage
db.MarketData.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 7776000 });

print('Creating indexes for PriceAlert...');
db.PriceAlert.createIndex({ "userId": 1 });
db.PriceAlert.createIndex({ "symbol": 1, "status": 1 });
db.PriceAlert.createIndex({ "status": 1 });

print('Creating indexes for TraderWatchlist...');
db.TraderWatchlist.createIndex({ "userId": 1 });

print('Creating indexes for WatchlistItem...');
db.WatchlistItem.createIndex({ "watchlistId": 1 });
db.WatchlistItem.createIndex({ "watchlistId": 1, "symbol": 1 }, { unique: true });

// ============================================================================
// FINANCE COLLECTIONS
// ============================================================================

print('Creating indexes for Invoice...');
db.Invoice.createIndex({ "invoiceNumber": 1 }, { unique: true });
db.Invoice.createIndex({ "userId": 1 });
db.Invoice.createIndex({ "userId": 1, "invoiceType": 1 });
db.Invoice.createIndex({ "orderId": 1 }, { sparse: true });
db.Invoice.createIndex({ "tradeId": 1 }, { sparse: true });
db.Invoice.createIndex({ "invoiceDate": -1 });
db.Invoice.createIndex({ "status": 1 });

print('Creating indexes for WalletTransaction...');
db.WalletTransaction.createIndex({ "transactionNumber": 1 }, { unique: true });
db.WalletTransaction.createIndex({ "userId": 1 });
db.WalletTransaction.createIndex({ "userId": 1, "transactionType": 1 });
db.WalletTransaction.createIndex({ "userId": 1, "status": 1 });
db.WalletTransaction.createIndex({ "userId": 1, "completedAt": -1 });
db.WalletTransaction.createIndex({ "status": 1 });
db.WalletTransaction.createIndex({ "transactionDate": -1 });
db.WalletTransaction.createIndex({ "referenceType": 1, "referenceId": 1 }, { sparse: true });

print('Creating indexes for AppLedgerEntry...');
// getAppLedger: account / userId / transactionType + createdAt range + sort (see getAppLedgerHandler, appLedgerLoadEntries).
db.AppLedgerEntry.createIndex({ "account": 1, "createdAt": -1 });
db.AppLedgerEntry.createIndex({ "userId": 1, "createdAt": -1 }, { sparse: true });
db.AppLedgerEntry.createIndex({ "account": 1, "userId": 1, "createdAt": -1 }, { sparse: true });
db.AppLedgerEntry.createIndex({ "transactionType": 1, "createdAt": -1 });

print('Creating indexes for BankContraPosting...');
// BANK-PS-* ledger path: investorId + createdAt (appLedgerLoadEntries).
db.BankContraPosting.createIndex({ "investorId": 1, "createdAt": -1 }, { sparse: true });

print('Creating indexes for Document...');
// searchDocuments / admin: Parse field is `type` (not documentType). Compounds follow equality → sort/range on uploadedAt.
db.Document.createIndex({ "userId": 1, "type": 1, "uploadedAt": -1 });
db.Document.createIndex({ "type": 1, "uploadedAt": -1 });
db.Document.createIndex({ "investmentId": 1, "uploadedAt": -1 }, { sparse: true });
db.Document.createIndex({ "tradeId": 1, "uploadedAt": -1 }, { sparse: true });
db.Document.createIndex({ "uploadedAt": -1 });
db.Document.createIndex({ "referenceType": 1, "referenceId": 1 }, { sparse: true });
db.Document.createIndex({ "periodYear": 1, "periodMonth": 1 }, { sparse: true });
db.Document.createIndex({ "createdAt": -1 });
// Legacy field name (kept harmless if older rows still carry documentType).
db.Document.createIndex({ "userId": 1, "documentType": 1 });

print('Creating indexes for AccountStatement...');
db.AccountStatement.createIndex({ "statementNumber": 1 }, { unique: true });
db.AccountStatement.createIndex({ "userId": 1 });
db.AccountStatement.createIndex({ "userId": 1, "periodType": 1, "periodYear": 1, "periodMonth": 1 });

// ============================================================================
// NOTIFICATION COLLECTIONS
// ============================================================================

print('Creating indexes for Notification...');
db.Notification.createIndex({ "userId": 1 });
db.Notification.createIndex({ "userId": 1, "isRead": 1 });
db.Notification.createIndex({ "userId": 1, "isRead": 1, "createdAt": -1 });
db.Notification.createIndex({ "userId": 1, "category": 1 });
db.Notification.createIndex({ "type": 1 });
db.Notification.createIndex({ "createdAt": -1 });
db.Notification.createIndex({ "referenceType": 1, "referenceId": 1 }, { sparse: true });
// TTL Index: Lösche gelesene Notifications nach 90 Tagen
db.Notification.createIndex(
  { "readAt": 1 },
  { expireAfterSeconds: 7776000, partialFilterExpression: { isRead: true } }
);

print('Creating indexes for NotificationPreference...');
db.NotificationPreference.createIndex({ "userId": 1 }, { unique: true });

// ============================================================================
// FAQ COLLECTIONS
// ============================================================================

print('Creating indexes for FAQCategory...');
db.FAQCategory.createIndex({ "slug": 1 }, { unique: true });
db.FAQCategory.createIndex({ "isActive": 1, "sortOrder": 1 });

print('Creating indexes for FAQ...');
db.FAQ.createIndex({ "categoryId": 1 });
db.FAQ.createIndex({ "isPublic": 1, "isPublished": 1 });
db.FAQ.createIndex({ "isUserVisible": 1, "isPublished": 1 });
db.FAQ.createIndex({ "isCsrVisible": 1, "isPublished": 1 });
db.FAQ.createIndex({ "tags": 1 });
db.FAQ.createIndex({ "question": "text", "answer": "text" }); // Full-text search

print('Creating indexes for FAQFeedback...');
db.FAQFeedback.createIndex({ "faqId": 1 });
db.FAQFeedback.createIndex({ "userId": 1 }, { sparse: true });
db.FAQFeedback.createIndex({ "faqId": 1, "userId": 1 }, { sparse: true });

// ============================================================================
// SUPPORT COLLECTIONS
// ============================================================================

print('Creating indexes for SupportTicket...');
db.SupportTicket.createIndex({ "ticketNumber": 1 }, { unique: true });
db.SupportTicket.createIndex({ "userId": 1 });
db.SupportTicket.createIndex({ "assignedTo": 1 }, { sparse: true });
db.SupportTicket.createIndex({ "status": 1 });
db.SupportTicket.createIndex({ "status": 1, "priority": 1 });
db.SupportTicket.createIndex({ "createdAt": -1 });
db.SupportTicket.createIndex({ "category": 1 });

print('Creating indexes for TicketResponse...');
db.TicketResponse.createIndex({ "ticketId": 1 });
db.TicketResponse.createIndex({ "agentId": 1 }, { sparse: true });
db.TicketResponse.createIndex({ "createdAt": -1 });

print('Creating indexes for CSRAgent...');
db.CSRAgent.createIndex({ "userId": 1 }, { unique: true });
db.CSRAgent.createIndex({ "agentNumber": 1 }, { unique: true, sparse: true });
db.CSRAgent.createIndex({ "roleId": 1 });
db.CSRAgent.createIndex({ "isAvailable": 1, "isOnline": 1 });

print('Creating indexes for FourEyesRequest...');
db.FourEyesRequest.createIndex({ "requestNumber": 1 }, { unique: true });
db.FourEyesRequest.createIndex({ "requesterId": 1 });
db.FourEyesRequest.createIndex({ "status": 1 });
db.FourEyesRequest.createIndex({ "customerId": 1 }, { sparse: true });

print('Creating indexes for SatisfactionSurvey...');
db.SatisfactionSurvey.createIndex({ "ticketId": 1 });
db.SatisfactionSurvey.createIndex({ "userId": 1 }, { sparse: true });
db.SatisfactionSurvey.createIndex({ "agentId": 1 }, { sparse: true });
db.SatisfactionSurvey.createIndex({ "status": 1 });

// ============================================================================
// COMPLIANCE COLLECTIONS
// ============================================================================

print('Creating indexes for ComplianceEvent...');
db.ComplianceEvent.createIndex({ "userId": 1 });
db.ComplianceEvent.createIndex({ "userId": 1, "occurredAt": -1 });
db.ComplianceEvent.createIndex({ "eventType": 1 });
db.ComplianceEvent.createIndex({ "severity": 1 });
db.ComplianceEvent.createIndex({ "requiresReview": 1, "reviewed": 1 });
db.ComplianceEvent.createIndex({ "occurredAt": -1 });
db.ComplianceEvent.createIndex({ "regulatoryFlags": 1 });

print('Creating indexes for GDPRRequest...');
db.GDPRRequest.createIndex({ "requestNumber": 1 }, { unique: true });
db.GDPRRequest.createIndex({ "userId": 1 });
db.GDPRRequest.createIndex({ "status": 1 });
db.GDPRRequest.createIndex({ "deadline": 1 });

print('Creating indexes for AuditLog...');
db.AuditLog.createIndex({ "userId": 1 }, { sparse: true });
db.AuditLog.createIndex({ "resourceType": 1, "resourceId": 1 });
db.AuditLog.createIndex({ "action": 1 });
db.AuditLog.createIndex({ "createdAt": -1 });
// Compliance: 10 Jahre aufbewahren, dann automatisch löschen
// Hinweis: In Production evtl. manuelles Archivieren statt TTL
// db.AuditLog.createIndex({ "createdAt": 1 }, { expireAfterSeconds: 315360000 });

print('Creating indexes for DataAccessLog...');
db.DataAccessLog.createIndex({ "accessorId": 1 });
db.DataAccessLog.createIndex({ "subjectId": 1 });
db.DataAccessLog.createIndex({ "dataCategory": 1 });
db.DataAccessLog.createIndex({ "accessedAt": -1 });

// ============================================================================
// CONFIGURATION COLLECTIONS
// ============================================================================

print('Creating indexes for Config...');
db.Config.createIndex({ "environment": 1 }, { unique: true });

print('Creating indexes for Announcement...');
db.Announcement.createIndex({ "slug": 1 }, { unique: true, sparse: true });
db.Announcement.createIndex({ "isActive": 1, "startsAt": 1, "expiresAt": 1 });
db.Announcement.createIndex({ "type": 1 });

print('Creating indexes for AppVersion...');
db.AppVersion.createIndex({ "platform": 1, "version": 1, "buildNumber": 1 }, { unique: true });
db.AppVersion.createIndex({ "platform": 1, "status": 1 });

// ============================================================================
// ADMIN COLLECTIONS
// ============================================================================

print('Creating indexes for AdminImpersonationLog...');
db.AdminImpersonationLog.createIndex({ "adminId": 1 });
db.AdminImpersonationLog.createIndex({ "targetUserId": 1 });
db.AdminImpersonationLog.createIndex({ "isActive": 1 });
db.AdminImpersonationLog.createIndex({ "startedAt": -1 });

// ============================================================================
// FINISH
// ============================================================================

print('');
print('=== MongoDB Index Setup Complete ===');
print('Total collections with indexes: 40+');
print('');
