import Foundation

// MARK: - Price Alert Types
/// Types of price alerts that can be set
enum PriceAlertType: String, Codable {
    case above = "above" // Alert when price goes above threshold
    case below = "below" // Alert when price goes below threshold
    case change = "change" // Alert when price changes by percentage
}

// MARK: - Price Alert Status
/// Status of a price alert
enum PriceAlertStatus: String, Codable {
    case active = "active" // Alert is active and monitoring
    case triggered = "triggered" // Alert has been triggered
    case cancelled = "cancelled" // Alert was cancelled by user
    case expired = "expired" // Alert expired (if expiration date set)
}

// MARK: - Parse Price Alert Model
/// Represents a Price Alert as stored in Parse Server
struct ParsePriceAlert: Codable {
    let objectId: String? // Parse Server generated ID
    let userId: String // User who created the alert
    let symbol: String // Stock symbol, index name, or underlying asset identifier
    let alertType: PriceAlertType // Type of alert (above, below, change)
    let thresholdPrice: Double? // Price threshold (for above/below alerts)
    let thresholdChangePercent: Double? // Percentage change threshold (for change alerts)
    let status: PriceAlertStatus // Current status of the alert
    let createdAt: Date // When the alert was created
    let triggeredAt: Date? // When the alert was triggered (if triggered)
    let expiresAt: Date? // Optional expiration date
    let notificationSent: Bool // Whether notification was sent
    let isEnabled: Bool // Whether alert is currently enabled
    
    // Optional metadata
    let notes: String? // User notes about the alert
    let metadata: [String: Any]? // Additional metadata (not Codable, handled separately)
    
    // MARK: - Initialization
    
    init(
        objectId: String? = nil,
        userId: String,
        symbol: String,
        alertType: PriceAlertType,
        thresholdPrice: Double? = nil,
        thresholdChangePercent: Double? = nil,
        status: PriceAlertStatus = .active,
        createdAt: Date = Date(),
        triggeredAt: Date? = nil,
        expiresAt: Date? = nil,
        notificationSent: Bool = false,
        isEnabled: Bool = true,
        notes: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.objectId = objectId
        self.userId = userId
        self.symbol = symbol
        self.alertType = alertType
        self.thresholdPrice = thresholdPrice
        self.thresholdChangePercent = thresholdChangePercent
        self.status = status
        self.createdAt = createdAt
        self.triggeredAt = triggeredAt
        self.expiresAt = expiresAt
        self.notificationSent = notificationSent
        self.isEnabled = isEnabled
        self.notes = notes
        self.metadata = metadata
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case symbol
        case alertType
        case thresholdPrice
        case thresholdChangePercent
        case status
        case createdAt
        case triggeredAt
        case expiresAt
        case notificationSent
        case isEnabled
        case notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objectId = try container.decodeIfPresent(String.self, forKey: .objectId)
        userId = try container.decode(String.self, forKey: .userId)
        symbol = try container.decode(String.self, forKey: .symbol)
        alertType = try container.decode(PriceAlertType.self, forKey: .alertType)
        thresholdPrice = try container.decodeIfPresent(Double.self, forKey: .thresholdPrice)
        thresholdChangePercent = try container.decodeIfPresent(Double.self, forKey: .thresholdChangePercent)
        status = try container.decode(PriceAlertStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        triggeredAt = try container.decodeIfPresent(Date.self, forKey: .triggeredAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        notificationSent = try container.decode(Bool.self, forKey: .notificationSent)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        metadata = nil // Metadata is not decoded from JSON
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(objectId, forKey: .objectId)
        try container.encode(userId, forKey: .userId)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(alertType, forKey: .alertType)
        try container.encodeIfPresent(thresholdPrice, forKey: .thresholdPrice)
        try container.encodeIfPresent(thresholdChangePercent, forKey: .thresholdChangePercent)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(triggeredAt, forKey: .triggeredAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(notificationSent, forKey: .notificationSent)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(notes, forKey: .notes)
        // Metadata is not encoded to JSON
    }
}

// MARK: - Price Alert Model (App Model)
/// App-level model for Price Alerts
struct PriceAlert: Identifiable, Equatable {
    let id: String
    let userId: String
    let symbol: String
    let alertType: PriceAlertType
    let thresholdPrice: Double?
    let thresholdChangePercent: Double?
    let status: PriceAlertStatus
    let createdAt: Date
    let triggeredAt: Date?
    let expiresAt: Date?
    let notificationSent: Bool
    let isEnabled: Bool
    let notes: String?
    
    // MARK: - Conversion from ParsePriceAlert
    
    init(from parseAlert: ParsePriceAlert) {
        self.id = parseAlert.objectId ?? UUID().uuidString
        self.userId = parseAlert.userId
        self.symbol = parseAlert.symbol
        self.alertType = parseAlert.alertType
        self.thresholdPrice = parseAlert.thresholdPrice
        self.thresholdChangePercent = parseAlert.thresholdChangePercent
        self.status = parseAlert.status
        self.createdAt = parseAlert.createdAt
        self.triggeredAt = parseAlert.triggeredAt
        self.expiresAt = parseAlert.expiresAt
        self.notificationSent = parseAlert.notificationSent
        self.isEnabled = parseAlert.isEnabled
        self.notes = parseAlert.notes
    }
    
    // MARK: - Conversion to ParsePriceAlert
    
    func toParsePriceAlert() -> ParsePriceAlert {
        return ParsePriceAlert(
            objectId: id,
            userId: userId,
            symbol: symbol,
            alertType: alertType,
            thresholdPrice: thresholdPrice,
            thresholdChangePercent: thresholdChangePercent,
            status: status,
            createdAt: createdAt,
            triggeredAt: triggeredAt,
            expiresAt: expiresAt,
            notificationSent: notificationSent,
            isEnabled: isEnabled,
            notes: notes
        )
    }
}
