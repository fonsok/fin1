import Foundation
import Combine
import os.log

// MARK: - Audit Logging Service Implementation
/// Handles all audit logging for customer support actions
/// Compliant with AML, GDPR, and regulatory requirements

final class AuditLoggingService: AuditLoggingServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.fin.app", category: "AuditLogging")
    private let queue = DispatchQueue(label: "audit.logging.queue", qos: .utility)
    private var auditLogs: [AuditLogEntry] = []
    private var dataAccessLogs: [DataAccessLog] = []
    private var complianceEvents: [ComplianceEvent] = []
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    
    private var useParseServer: Bool {
        parseAPIClient != nil
    }

    // MARK: - Retention Configuration (GDPR/AML compliant)

    /// Audit log retention: 10 years (German financial regulations)
    private let auditRetentionYears: Int = 10

    /// Compliance event retention: 10 years (GwG/AML)
    private let complianceRetentionYears: Int = 10

    // MARK: - Initialization

    init(parseAPIClient: (any ParseAPIClientProtocol)? = nil) {
        self.parseAPIClient = parseAPIClient
    }

    // MARK: - ServiceLifecycle

    func start() async {
        logger.info("AuditLoggingService started")
        // Load recent compliance events from Parse Server if available
        if useParseServer {
            await loadRecentComplianceEventsFromParseServer()
        }
    }

    func stop() async {
        logger.info("AuditLoggingService stopped")
        // Save pending compliance events to Parse Server if available
        if useParseServer {
            await savePendingComplianceEventsToParseServer()
        }
    }

    func reset() {
        queue.sync {
            auditLogs.removeAll()
            dataAccessLogs.removeAll()
            complianceEvents.removeAll()
        }
        logger.info("AuditLoggingService reset")
    }

    // MARK: - AuditLoggingServiceProtocol

    func logAction(_ action: AuditAction) async {
        let entry = AuditLogEntry(
            id: action.id,
            entryType: .action,
            agentId: action.agentId,
            agentName: nil,
            customerId: action.customerId,
            customerName: nil,
            action: action.actionType.rawValue,
            description: action.description,
            timestamp: action.timestamp,
            metadata: buildActionMetadata(action)
        )

        await storeLogEntry(entry)

        #if DEBUG
        logger.debug("📝 Audit Action: \(action.actionType.displayName) by \(action.agentId)")
        #endif
    }

    func logDataAccess(_ access: DataAccessLog) async {
        queue.sync {
            dataAccessLogs.append(access)
        }

        let entry = AuditLogEntry(
            id: access.id,
            entryType: .dataAccess,
            agentId: access.agentId,
            agentName: nil,
            customerId: access.customerId,
            customerName: nil,
            action: "data_access",
            description: "Zugriff auf \(access.dataCategory.displayName)",
            timestamp: access.timestamp,
            metadata: [
                "data_category": access.dataCategory.rawValue,
                "access_type": access.accessType.rawValue,
                "fields": access.fields.joined(separator: ", "),
                "purpose": access.purpose,
                "legal_basis": access.legalBasis.rawValue
            ]
        )

        await storeLogEntry(entry)

        #if DEBUG
        logger.debug("👁️ Data Access: \(access.dataCategory.displayName) for customer \(access.customerId)")
        #endif
    }

    func logComplianceEvent(_ event: ComplianceEvent) async {
        queue.sync {
            complianceEvents.append(event)
        }

        // Save to Parse Server if available (async, don't wait)
        if useParseServer, let parseClient = parseAPIClient {
            let client: any ParseAPIClientProtocol = parseClient
            let parseEvent = ParseComplianceEvent(
                userId: event.customerId,
                eventType: event.eventType.rawValue,
                description: event.description,
                metadata: event.notes != nil ? ["notes": event.notes!] : [:],
                timestamp: event.timestamp,
                regulatoryFlags: [] // Can be extended later
            )
            Task.detached(priority: .utility) {
                do {
                    _ = try await client.createObject(
                        className: "ComplianceEvent",
                        object: parseEvent
                    )
                } catch {
                    print("⚠️ Failed to save compliance event to Parse Server: \(error.localizedDescription)")
                }
            }
        }

        let entry = AuditLogEntry(
            id: event.id,
            entryType: .compliance,
            agentId: event.agentId,
            agentName: nil,
            customerId: event.customerId,
            customerName: nil,
            action: event.eventType.rawValue,
            description: event.description,
            timestamp: event.timestamp,
            metadata: [
                "event_type": event.eventType.rawValue,
                "severity": event.severity.rawValue,
                "requires_review": String(event.requiresReview)
            ]
        )

        await storeLogEntry(entry)

        // Log high severity events prominently
        if event.severity == .high || event.severity == .critical {
            logger.warning("⚠️ Compliance Event [\(event.severity.displayName)]: \(event.description)")
        } else {
            #if DEBUG
            logger.debug("🔒 Compliance Event: \(event.eventType.displayName)")
            #endif
        }
    }

    func getAuditLogs(for customerId: String, dateRange: DateInterval?) async throws -> [AuditLogEntry] {
        var logs = queue.sync {
            auditLogs.filter { $0.customerId == customerId }
        }
        
        // Load from Parse Server if available
        if useParseServer, let parseClient = parseAPIClient {
            do {
                var query: [String: Any] = ["userId": customerId]
                if let range = dateRange {
                    query["timestamp"] = [
                        "$gte": ["__type": "Date", "iso": range.start.iso8601String],
                        "$lte": ["__type": "Date", "iso": range.end.iso8601String]
                    ]
                }
                
                let parseEvents: [ParseComplianceEvent] = try await parseClient.fetchObjects(
                    className: "ComplianceEvent",
                    query: query,
                    include: nil,
                    orderBy: "-timestamp",
                    limit: 1000
                )
                
                // Convert to AuditLogEntry
                let parseEntries = parseEvents.map { event in
                    AuditLogEntry(
                        id: event.objectId ?? UUID().uuidString,
                        entryType: .compliance,
                        agentId: event.userId,
                        agentName: nil,
                        customerId: event.userId,
                        customerName: nil,
                        action: event.eventType,
                        description: event.description,
                        timestamp: event.timestamp,
                        metadata: event.metadata
                    )
                }
                logs.append(contentsOf: parseEntries)
            } catch {
                logger.error("⚠️ Failed to load audit logs from Parse Server: \(error.localizedDescription)")
            }
        }
        
        // Apply date range filter if needed
        if let range = dateRange {
            logs = logs.filter { range.contains($0.timestamp) }
        }
        
        return logs.sorted { $0.timestamp > $1.timestamp }
    }

    func getAgentActions(agentId: String, dateRange: DateInterval?) async throws -> [AuditLogEntry] {
        var logs = queue.sync {
            auditLogs.filter { $0.agentId == agentId }
        }
        
        // Load from Parse Server if available (compliance events where agentId = userId)
        if useParseServer, let parseClient = parseAPIClient {
            do {
                var query: [String: Any] = ["userId": agentId]
                if let range = dateRange {
                    query["timestamp"] = [
                        "$gte": ["__type": "Date", "iso": range.start.iso8601String],
                        "$lte": ["__type": "Date", "iso": range.end.iso8601String]
                    ]
                }
                
                let parseEvents: [ParseComplianceEvent] = try await parseClient.fetchObjects(
                    className: "ComplianceEvent",
                    query: query,
                    include: nil,
                    orderBy: "-timestamp",
                    limit: 1000
                )
                
                // Convert to AuditLogEntry
                let parseEntries = parseEvents.map { event in
                    AuditLogEntry(
                        id: event.objectId ?? UUID().uuidString,
                        entryType: .compliance,
                        agentId: event.userId,
                        agentName: nil,
                        customerId: event.userId,
                        customerName: nil,
                        action: event.eventType,
                        description: event.description,
                        timestamp: event.timestamp,
                        metadata: event.metadata
                    )
                }
                logs.append(contentsOf: parseEntries)
            } catch {
                logger.error("⚠️ Failed to load agent actions from Parse Server: \(error.localizedDescription)")
            }
        }
        
        // Apply date range filter if needed
        if let range = dateRange {
            logs = logs.filter { range.contains($0.timestamp) }
        }
        
        return logs.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Private Methods

    private func storeLogEntry(_ entry: AuditLogEntry) async {
        queue.sync {
            auditLogs.append(entry)
        }

        // Persist to Parse Server if available (for compliance events)
        // Other audit logs are kept in-memory for performance
    }
    
    // MARK: - Parse Server Integration
    
    private func loadRecentComplianceEventsFromParseServer() async {
        guard let parseClient = parseAPIClient else {
            return
        }
        
        do {
            // Load last 100 compliance events from last 30 days
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let parseEvents: [ParseComplianceEvent] = try await parseClient.fetchObjects(
                className: "ComplianceEvent",
                query: [
                    "timestamp": ["$gte": ["__type": "Date", "iso": thirtyDaysAgo.iso8601String]]
                ],
                include: nil,
                orderBy: "-timestamp",
                limit: 100
            )
            
            // Convert to ComplianceEvent and add to in-memory cache
            queue.sync {
                for parseEvent in parseEvents {
                    let event = parseEvent.toComplianceEvent()
                    if !complianceEvents.contains(where: { $0.id == event.id }) {
                        complianceEvents.append(event)
                    }
                }
            }
        } catch {
            logger.error("⚠️ Failed to load compliance events from Parse Server: \(error.localizedDescription)")
        }
    }
    
    private func savePendingComplianceEventsToParseServer() async {
        guard let parseClient = parseAPIClient else {
            return
        }
        
        let pendingEvents = queue.sync {
            Array(complianceEvents)
        }
        
        for event in pendingEvents {
            do {
                // Check if already saved (by checking if we have objectId in metadata)
                // For now, we'll try to save all - Parse Server will handle duplicates
                let parseEvent = ParseComplianceEvent(
                    userId: event.customerId,
                    eventType: event.eventType.rawValue,
                    description: event.description,
                    metadata: event.notes != nil ? ["notes": event.notes!] : [:],
                    timestamp: event.timestamp,
                    regulatoryFlags: []
                )
                _ = try await parseClient.createObject(
                    className: "ComplianceEvent",
                    object: parseEvent
                )
            } catch {
                logger.error("⚠️ Failed to save compliance event to Parse Server: \(error.localizedDescription)")
            }
        }
    }

    private func buildActionMetadata(_ action: AuditAction) -> [String: String] {
        var metadata: [String: String] = [
            "permission": action.permission,
            "agent_role": action.agentRole
        ]

        if let previous = action.previousValue {
            metadata["previous_value"] = previous
        }
        if let newValue = action.newValue {
            metadata["new_value"] = newValue
        }
        if let ip = action.ipAddress {
            metadata["ip_address"] = ip
        }
        if let device = action.deviceInfo {
            metadata["device_info"] = device
        }
        if let session = action.sessionId {
            metadata["session_id"] = session
        }
        if let approvedBy = action.approvedBy {
            metadata["approved_by"] = approvedBy
            if let approvalTime = action.approvalTimestamp {
                metadata["approval_timestamp"] = ISO8601DateFormatter().string(from: approvalTime)
            }
        }

        return metadata
    }
}

// MARK: - Convenience Extensions

extension AuditLoggingService {
    /// Log a simple view action
    func logViewAction(
        agentId: String,
        agentRole: UserRole,
        customerId: String,
        viewedData: String
    ) async {
        let action = AuditAction(
            agentId: agentId,
            agentRole: agentRole.rawValue,
            customerId: customerId,
            actionType: .view,
            permission: .viewCustomerProfile,
            description: "Ansicht: \(viewedData)"
        )
        await logAction(action)
    }

    /// Log a customer data modification with compliance check
    func logModificationWithCompliance(
        agentId: String,
        agentRole: UserRole,
        customerId: String,
        permission: CustomerSupportPermission,
        fieldName: String,
        previousValue: String,
        newValue: String,
        complianceEventType: ComplianceEventType? = nil
    ) async {
        // Log the action
        let action = AuditAction(
            agentId: agentId,
            agentRole: agentRole.rawValue,
            customerId: customerId,
            actionType: .update,
            permission: permission,
            description: "Aktualisierung: \(fieldName)",
            previousValue: previousValue,
            newValue: newValue
        )
        await logAction(action)

        // If compliance check is required, log compliance event
        if permission.triggersComplianceCheck, let eventType = complianceEventType {
            let event = ComplianceEvent(
                eventType: eventType,
                agentId: agentId,
                customerId: customerId,
                description: "Änderung von \(fieldName) erfordert Compliance-Prüfung",
                severity: eventType.defaultSeverity,
                requiresReview: true
            )
            await logComplianceEvent(event)
        }
    }
}





