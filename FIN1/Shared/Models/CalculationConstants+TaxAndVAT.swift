import Foundation

extension CalculationConstants {
    struct TaxRates {
        static let capitalGainsTax: Double = 0.25
        static let capitalGainsTaxPercentage: String = "25%"
        static let capitalGainsTaxWithSoli: String = "\(capitalGainsTaxPercentage) + Soli"
        static let solidaritySurcharge: Double = 0.055
        static let churchTax: Double = 0.08
        static let vatRate: Double = 0.19
    }

    struct VATRates {
        static let standardVAT: Double = 0.19
        static let standardVATPercentage: String = "19%"
    }
}
