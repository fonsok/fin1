import Foundation

// MARK: - Calculation Constants

/// Centralized constants for all financial calculations.
///
/// **Fee responsibility (product model)**
/// - **Investors** pay the app service charge on investments. They do **not** pay
///   order fees, exchange fees, or other trading fees grouped under ``FeeRates``.
/// - **Traders** pay order fees, exchange fees, and related trading fees. They do **not** pay
///   the app service charge.
struct CalculationConstants {

    // MARK: - Tax Rates

    /// German tax rates for capital gains
    struct TaxRates {
        /// Capital gains tax rate (Abgeltungssteuer) - 25%
        static let capitalGainsTax: Double = 0.25

        /// Capital gains tax percentage for display (e.g., "25%")
        static let capitalGainsTaxPercentage: String = "25%"

        /// Tax rate description for documents (e.g., "25% + Soli")
        static let capitalGainsTaxWithSoli: String = "\(capitalGainsTaxPercentage) + Soli"

        /// Solidarity surcharge rate (Solidaritätszuschlag) - 5.5% of capital gains tax
        static let solidaritySurcharge: Double = 0.055

        /// Church tax rate (Kirchensteuer) - 8% of capital gains tax
        static let churchTax: Double = 0.08

        /// Value Added Tax (VAT) rate - 19%
        /// Used for service charges and other taxable services
        static let vatRate: Double = 0.19
    }

    // MARK: - VAT Rates

    /// Value Added Tax (Umsatzsteuer) rates
    struct VATRates {
        /// Standard VAT rate in Germany - 19%
        static let standardVAT: Double = 0.19

        /// Standard VAT percentage for display (e.g., "19%")
        static let standardVATPercentage: String = "19%"
    }

    // MARK: - Fee Rates

    /// Trading fee rates and limits (trader order / execution flows).
    /// - Note: These fees are **not** applied to investors for investments; see ``ServiceCharges``.
    struct FeeRates {
        /// Order fee rate - 0.5% of order amount
        static let orderFeeRate: Double = 0.005

        /// Order fee minimum amount in EUR
        static let orderFeeMinimum: Double = 5.0

        /// Order fee maximum amount in EUR
        static let orderFeeMaximum: Double = 50.0

        /// Exchange fee rate - 0.1% of order amount
        static let exchangeFeeRate: Double = 0.001

        /// Exchange fee minimum amount in EUR
        static let exchangeFeeMinimum: Double = 1.0

        /// Exchange fee maximum amount in EUR
        static let exchangeFeeMaximum: Double = 20.0

        /// Foreign costs fixed amount in EUR
        static let foreignCosts: Double = 1.50

        // MARK: Admin-Configurable Rate Defaults
        // ⚠️ CRITICAL: These are LAST-RESORT FALLBACKS only, matching the backend
        // DEFAULT_CONFIG in backend utils/configHelper. The actual production value is set by
        // an admin via the Configuration class and served through ConfigurationService.
        //
        // RULE: All financial code paths MUST obtain the commission rate from
        //   ConfigurationServiceProtocol.effectiveCommissionRate
        // Direct use of these constants in business logic is FORBIDDEN.
        // They exist solely as the documented baseline when ConfigurationService
        // has not yet loaded (app cold-start) or is unavailable (unit tests).

        /// Trader commission rate on profit - LAST-RESORT FALLBACK.
        /// Production value comes from `ConfigurationService.traderCommissionRate`.
        static let traderCommissionRate: Double = 0.10

        /// Trader commission percentage for display - LAST-RESORT FALLBACK.
        /// Production value comes from `ConfigurationService.traderCommissionPercentage`.
        static let traderCommissionPercentage: String = "10%"
    }

    // MARK: - Service Charges

    /// App service charge on investments (investor-only).
    /// - Note: Not the same as ``FeeRates`` (trader trading fees). Traders do not pay this charge.
    struct ServiceCharges {
        /// App service charge rate - 2% of investment amount (GROSS amount, includes VAT)
        /// - Note: This charge applies ONLY to investors when creating investments
        /// - The 2% is the gross amount that gets debited from the account
        /// - For invoicing, this gross amount is split into net service charge and VAT (19%)
        static let appServiceChargeRate: Double = 0.02

        /// App service charge percentage for display (e.g., "2%")
        /// - Note: This charge applies ONLY to investors when creating investments
        /// - The 2% represents the gross amount (includes VAT)
        static let appServiceChargePercentage: String = "2%"
    }

    // MARK: - Account Configuration

    /// Account and balance configuration
    struct Account {
        /// Fallback when no `ConfigurationService` — real default is 0 € from backend / admin only
        static let initialBalance: Double = 0.0

        /// Fallback when no `ConfigurationService` — real default is 0 € from backend / admin only
        static let initialInvestorBalance: Double = 0.0

        /// Minimum cash balance reserve in EUR (for buy order and investment validation)
        static let minimumCashReserve: Double = 20.0
    }

    // MARK: - Investment Defaults

    /// Baseline values for investor workflows
    struct Investment {
        /// Default investment amount shown in Investment Amount section (EUR)
        static let defaultAmount: Double = 3_000.0

        /// Last-resort minimum per investment slot (EUR) when `getConfig` has no `limits.minInvestment`
        static let fallbackMinimumInvestmentAmount: Double = 20.0

        /// Last-resort maximum per investment slot (EUR) when `getConfig` has no `limits.maxInvestment`
        static let fallbackMaximumInvestmentAmount: Double = 100_000.0
    }

    // MARK: - Calculation Limits

    /// Limits and thresholds for calculations
    struct Limits {
        /// Minimum profit threshold for tax calculation (0 = no threshold)
        static let minimumTaxableProfit: Double = 0.0

        /// Maximum number of decimal places for currency formatting
        static let currencyDecimalPlaces: Int = 2

        /// Maximum number of decimal places for percentage formatting
        static let percentageDecimalPlaces: Int = 1
    }

    // MARK: - Payment Limits

    /// Payment limits for deposits and withdrawals
    struct PaymentLimits {
        /// Minimum deposit amount (EUR)
        static let minimumDeposit: Double = 10.0

        /// Maximum deposit amount per transaction (EUR)
        static let maximumDeposit: Double = 100_000.0

        /// Minimum withdrawal amount (EUR)
        static let minimumWithdrawal: Double = 10.0

        /// Maximum withdrawal amount per transaction (EUR)
        static let maximumWithdrawal: Double = 50_000.0
    }

    // MARK: - Transaction Limits

    /// Transaction limits based on risk class (MiFID II / BaFin compliance)
    struct TransactionLimits {
        /// Base daily limit for all users (EUR).
        /// Used only as LAST-RESORT fallback; admin configuration is authoritative.
        static let baseDailyLimit: Double = 10_000.0

        /// Base weekly limit for all users (EUR)
        static let baseWeeklyLimit: Double = 50_000.0

        /// Base monthly limit for all users (EUR)
        static let baseMonthlyLimit: Double = 200_000.0

        // NOTE: Risk-class based multipliers have been removed.
        // Transaction limits are now configured exclusively via admin configuration
        // and are independent of the user's risk class.
    }

    // MARK: - Security Trading Constraints

    /// Valid denominations for securities trading
    /// Some securities can only be traded in specific lot sizes
    struct SecurityDenominations {
        /// Valid denomination values (tens, twenties, fifties, hundreds, thousands)
        static let validDenominations: [Int] = [10, 20, 50, 100, 1_000]

        /// Default denomination (no restriction) - set to nil or 1
        static let noDenomination: Int? = nil

        /// Default minimum order amount (no restriction) - set to nil or 0
        static let noMinimumOrderAmount: Double? = nil

        /// Validates if an order amount meets the minimum order requirement
        /// - Parameters:
        ///   - orderAmount: The total order amount (quantity × price) in EUR
        ///   - minimumOrderAmount: Optional minimum order amount in EUR
        /// - Returns: True if order amount meets or exceeds minimum, or if no minimum is specified
        static func meetsMinimumOrderAmount(_ orderAmount: Double, minimumOrderAmount: Double?) -> Bool {
            guard let minimum = minimumOrderAmount, minimum > 0 else {
                return true // No minimum requirement
            }
            return orderAmount >= minimum
        }

        /// Calculates the minimum quantity required to meet minimum order amount
        /// - Parameters:
        ///   - pricePerSecurity: Price per security in EUR
        ///   - minimumOrderAmount: Minimum order amount in EUR
        /// - Returns: Minimum quantity required, or 0 if price is invalid
        static func calculateMinimumQuantity(pricePerSecurity: Double, minimumOrderAmount: Double?) -> Int {
            guard let minimum = minimumOrderAmount, minimum > 0, pricePerSecurity > 0 else {
                return 0 // No minimum requirement
            }
            // Round up to ensure we meet the minimum
            return Int(ceil(minimum / pricePerSecurity))
        }

        /// Rounds down a quantity to the nearest valid denomination
        /// - Parameters:
        ///   - quantity: The quantity to round
        ///   - denominations: Array of valid denominations (default: validDenominations)
        /// - Returns: Rounded down quantity, or 0 if quantity is too small
        static func roundDownToDenomination(_ quantity: Int, denominations: [Int] = validDenominations) -> Int {
            guard quantity > 0 else { return 0 }

            // If quantity is less than smallest denomination, return 0
            guard let smallestDenomination = denominations.min(), quantity >= smallestDenomination else {
                return 0
            }

            // Find the largest denomination that fits into the quantity
            for denomination in denominations.sorted(by: >) {
                let rounded = (quantity / denomination) * denomination
                if rounded > 0 {
                    return rounded
                }
            }

            return 0
        }

        /// Checks if a quantity is a valid denomination
        /// - Parameters:
        ///   - quantity: The quantity to check
        ///   - denominations: Array of valid denominations (default: validDenominations)
        /// - Returns: True if quantity is a valid denomination or multiple thereof
        static func isValidDenomination(_ quantity: Int, denominations: [Int] = validDenominations) -> Bool {
            guard quantity > 0 else { return false }
            return denominations.contains { quantity % $0 == 0 }
        }

        /// Derives a sensible default denomination based on subscription ratio
        /// - Parameter subscriptionRatio: Units-per-share style ratio (e.g., 1.0, 0.1, 0.01, 10.0)
        /// - Returns: Preferred denomination in units (e.g., 10, 100) or nil if no restriction
        ///
        /// Rationale:
        /// - Warrants with high units-per-share effectively trade in blocks (tens or hundreds)
        /// - For stocks (ratio ≈ 1.0) we default to no denomination constraint
        static func defaultDenomination(forSubscriptionRatio subscriptionRatio: Double) -> Int? {
            guard subscriptionRatio > 0 else {
                return self.noDenomination
            }

            // Interpret ratios both < 1 and > 1 as "units per share" style
            // Example:
            // - 0.01 or 100.0 → ~100 units per share → trade in hundreds
            // - 0.1 or 10.0  → ~10 units per share  → trade in tens
            let unitsPerShare: Double
            if subscriptionRatio >= 1 {
                unitsPerShare = subscriptionRatio
            } else {
                unitsPerShare = 1.0 / subscriptionRatio
            }

            if unitsPerShare >= 100 {
                return 100
            } else if unitsPerShare >= 10 {
                return 10
            } else {
                return self.noDenomination
            }
        }
    }
}
