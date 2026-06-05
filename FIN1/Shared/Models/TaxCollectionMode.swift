import Foundation

/// How Abgeltungsteuer is handled platform-wide (`Configuration.tax.taxCollectionMode`).
enum TaxCollectionMode: String, Codable, Sendable {
    case customerSelfReports = "customer_self_reports"
    case platformWithholds = "platform_withholds"

    init(rawConfigValue: String?) {
        self = rawConfigValue == Self.platformWithholds.rawValue
            ? .platformWithholds
            : .customerSelfReports
    }

    var isCustomerSelfReports: Bool {
        self == .customerSelfReports
    }
}
