import Foundation

// MARK: - Privacy Settings Models
/// Models for privacy settings functionality

// MARK: - Privacy Settings (Persistence)

struct PrivacySettings: Codable {
    let analyticsEnabled: Bool
    let crashReportingEnabled: Bool
    let usageDataSharingEnabled: Bool
    let personalizedAdsEnabled: Bool
    let profileVisibleToTraders: Bool
    let investmentHistoryVisible: Bool
    let performanceMetricsVisible: Bool
    let marketingEmailsEnabled: Bool
    let thirdPartyDataSharingEnabled: Bool
    let newsletterSubscribed: Bool
}





