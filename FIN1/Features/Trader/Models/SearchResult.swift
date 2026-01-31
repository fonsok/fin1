import Foundation

struct SearchResult: Identifiable, Equatable {
    let id: String
    let valuationDate: String
    var wkn: String
    var strike: String
    var askPrice: String
    var direction: String?
    var category: String?
    var underlyingType: String?
    var isin: String
    var underlyingAsset: String?

    // Security trading metadata
    /// Denomination constraint (e.g., 1, 10, 100). Securities must be traded in multiples of this value.
    /// If nil, no denomination restriction (can trade any quantity).
    var denomination: Int?

    /// Subscription ratio (e.g., 1.0, 0.1, 0.01, 10.0, 100.0). Represents units per share (1:1, 1:10, 1:100).
    /// Example: subscriptionRatio = 10.0 means 10 units = 1 share.
    /// Example: subscriptionRatio = 0.01 means 100 units = 1 share (for Warrants).
    /// Default is 1.0 (1:1 ratio).
    var subscriptionRatio: Double

    /// Minimum order amount in EUR. If specified, total order must meet or exceed this amount.
    var minimumOrderAmount: Double?

    // Initialize with WKN as ID for consistent identification
    init(valuationDate: String, wkn: String, strike: String, askPrice: String, direction: String? = nil, category: String? = nil, underlyingType: String? = nil, isin: String, underlyingAsset: String? = nil, denomination: Int? = nil, subscriptionRatio: Double = 1.0, minimumOrderAmount: Double? = nil) {
        self.id = wkn
        self.valuationDate = valuationDate
        self.wkn = wkn
        self.strike = strike
        self.askPrice = askPrice
        self.direction = direction
        self.category = category
        self.underlyingType = underlyingType
        self.isin = isin
        self.denomination = denomination
        self.subscriptionRatio = subscriptionRatio
        self.minimumOrderAmount = minimumOrderAmount

        // Debug logging
        print("🔍 DEBUG: SearchResult.init - provided underlyingAsset: \(underlyingAsset ?? "nil")")
        print("🔍 DEBUG: SearchResult.init - WKN: \(wkn)")

        // CRITICAL: Use provided underlyingAsset if not empty, otherwise fallback to WKN mapping for stocks only
        // This logic was previously broken and caused wrong underlying assets to be displayed
        // DO NOT change this without thorough testing - it's the core of the underlying asset filter functionality
        if let underlyingAsset = underlyingAsset, !underlyingAsset.isEmpty {
            self.underlyingAsset = underlyingAsset
        } else {
            self.underlyingAsset = Self.getUnderlyingAssetFromWKN(wkn)
        }
    }

    // MARK: - WKN to Underlying Asset Mapping

    /// Determines the underlying asset from WKN (for stocks only)
    static func getUnderlyingAssetFromWKN(_ wkn: String) -> String {
        // Map WKN to underlying asset for stocks only
        switch wkn {
        // Stock WKNs
        case "865985": return "Apple"      // Apple Inc.
        case "519000": return "BMW"        // BMW AG
        case "A1CX3T": return "Tesla"      // Tesla Inc.
        case "870747": return "Microsoft"  // Microsoft Corp.
        case "A0B7X2": return "Google"     // Alphabet Inc.

        // Index WKNs
        case "846900": return "DAX"        // DAX Index

        // For options and other derivatives, the underlyingAsset should be provided explicitly
        // by the MockDataGenerator based on the selected filter
        default:
            return "Unknown"
        }
    }

    /// Determines the asset type from WKN
    static func getAssetTypeFromWKN(_ wkn: String) -> String {
        switch wkn {
        case "865985", "519000", "A1CX3T", "870747", "A0B7X2":
            return "Stock"
        case "846900":
            return "Index"
        default:
            // For options, determine based on WKN pattern
            if wkn.hasPrefix("SG") || wkn.hasPrefix("DB") || wkn.hasPrefix("VT") {
                return "Warrant"
            }
            return "Unknown"
        }
    }

    // Custom equality for watchlist deduplication
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.wkn == rhs.wkn
    }

    // MARK: - Security Metadata Helpers

    /// Gets the effective denomination for this security
    /// Returns the denomination if set, otherwise returns 1 (no restriction)
    var effectiveDenomination: Int {
        return denomination ?? 1
    }

    /// Converts units to shares based on subscription ratio
    /// - Parameter units: Number of units
    /// - Returns: Number of shares (rounded down)
    func unitsToShares(_ units: Int) -> Int {
        guard subscriptionRatio > 0 else { return units }
        return Int(Double(units) / subscriptionRatio)
    }

    /// Converts shares to units based on subscription ratio
    /// - Parameter shares: Number of shares
    /// - Returns: Number of units
    func sharesToUnits(_ shares: Int) -> Int {
        return Int(Double(shares) * subscriptionRatio)
    }
}
