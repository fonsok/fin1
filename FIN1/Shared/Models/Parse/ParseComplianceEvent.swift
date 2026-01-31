import Foundation

// MARK: - Parse Compliance Event Model
/// Parse Server model for persisting compliance events (MiFID II, BaFin)
struct ParseComplianceEvent: Codable {
    let objectId: String?
    let userId: String
    let eventType: String // ComplianceEventType rawValue
    let description: String
    let metadata: [String: String]
    let timestamp: Date
    let regulatoryFlags: [String] // e.g., ["mifidII", "preTradeCheck"]
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case eventType
        case description
        case metadata
        case timestamp
        case regulatoryFlags
        case createdAt
    }
    
    init(
        objectId: String? = nil,
        userId: String,
        eventType: String,
        description: String,
        metadata: [String: String] = [:],
        timestamp: Date = Date(),
        regulatoryFlags: [String] = [],
        createdAt: Date? = nil
    ) {
        self.objectId = objectId
        self.userId = userId
        self.eventType = eventType
        self.description = description
        self.metadata = metadata
        self.timestamp = timestamp
        self.regulatoryFlags = regulatoryFlags
        self.createdAt = createdAt
    }
    
    func toComplianceEvent() -> ComplianceEvent {
        let eventTypeEnum = ComplianceEventType(rawValue: eventType) ?? .riskCheck
        return ComplianceEvent(
            eventType: eventTypeEnum,
            agentId: userId,
            customerId: userId,
            description: description,
            severity: eventTypeEnum.defaultSeverity,
            requiresReview: false,
            notes: metadata.isEmpty ? nil : metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        )
    }
}
