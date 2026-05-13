import Foundation

// MARK: - Invoice Tax Calculations
struct InvoiceTaxCalculator {

    /// Calculates capital gains tax (Kapitalertragsteuer) at 25%
    /// - Parameter profit: The profit amount (positive for gains, negative for losses)
    /// - Returns: Capital gains tax amount (0 if loss)
    static func calculateCapitalGainsTax(for profit: Double) -> Double {
        return profit > CalculationConstants.Limits.minimumTaxableProfit ? profit * CalculationConstants.TaxRates.capitalGainsTax : 0.0
    }

    /// Calculates solidarity surcharge at 5.5% of capital gains tax
    /// - Parameter capitalGainsTax: The capital gains tax amount
    /// - Returns: Solidarity surcharge amount
    static func calculateSolidaritySurcharge(for capitalGainsTax: Double) -> Double {
        return capitalGainsTax * CalculationConstants.TaxRates.solidaritySurcharge
    }

    /// Calculates church tax (Kirchensteuer) at 8% of capital gains tax
    /// - Parameter capitalGainsTax: The capital gains tax amount
    /// - Returns: Church tax amount
    static func calculateChurchTax(for capitalGainsTax: Double) -> Double {
        return capitalGainsTax * CalculationConstants.TaxRates.churchTax
    }

    /// Calculates total tax amount (capital gains tax + solidarity surcharge + church tax)
    /// - Parameter profit: The profit amount
    /// - Returns: Total tax amount
    static func calculateTotalTax(for profit: Double) -> Double {
        let capitalGainsTax = self.calculateCapitalGainsTax(for: profit)
        let solidaritySurcharge = self.calculateSolidaritySurcharge(for: capitalGainsTax)
        let churchTax = self.calculateChurchTax(for: capitalGainsTax)
        return capitalGainsTax + solidaritySurcharge + churchTax
    }

    /// Creates capital gains tax invoice item
    /// - Parameter profit: The profit amount
    /// - Returns: InvoiceItem for capital gains tax
    static func createCapitalGainsTaxItem(for profit: Double) -> InvoiceItem {
        let amount = self.calculateCapitalGainsTax(for: profit)
        return InvoiceItem(
            description: "Kapitalertragsteuer (25%)",
            quantity: 1,
            unitPrice: amount,
            itemType: .tax
        )
    }

    /// Creates solidarity surcharge invoice item
    /// - Parameter profit: The profit amount
    /// - Returns: InvoiceItem for solidarity surcharge
    static func createSolidaritySurchargeItem(for profit: Double) -> InvoiceItem {
        let capitalGainsTax = self.calculateCapitalGainsTax(for: profit)
        let amount = self.calculateSolidaritySurcharge(for: capitalGainsTax)
        return InvoiceItem(
            description: "Solidaritätszuschlag (5,5%)",
            quantity: 1,
            unitPrice: amount,
            itemType: .tax
        )
    }

    /// Creates church tax invoice item
    /// - Parameter profit: The profit amount
    /// - Returns: InvoiceItem for church tax
    static func createChurchTaxItem(for profit: Double) -> InvoiceItem {
        let capitalGainsTax = self.calculateCapitalGainsTax(for: profit)
        let amount = self.calculateChurchTax(for: capitalGainsTax)
        return InvoiceItem(
            description: "Kirchensteuer (8%)",
            quantity: 1,
            unitPrice: amount,
            itemType: .tax
        )
    }

    /// Creates all tax items for a given profit
    /// - Parameter profit: The profit amount
    /// - Returns: Array of tax invoice items
    static func createAllTaxItems(for profit: Double) -> [InvoiceItem] {
        var items: [InvoiceItem] = []

        // Only create tax items if there's a profit
        if profit > 0 {
            items.append(self.createCapitalGainsTaxItem(for: profit))
            items.append(self.createSolidaritySurchargeItem(for: profit))
            items.append(self.createChurchTaxItem(for: profit))
        }

        return items
    }

    /// Calculates net amount after taxes (profit - total taxes)
    /// - Parameter profit: The profit amount
    /// - Returns: Net amount after taxes
    static func calculateNetAmountAfterTaxes(for profit: Double) -> Double {
        return profit - self.calculateTotalTax(for: profit)
    }
}

// MARK: - Tax Calculation Results
struct TaxCalculationResult {
    let profit: Double
    let capitalGainsTax: Double
    let solidaritySurcharge: Double
    let churchTax: Double
    let totalTax: Double
    let netAmountAfterTaxes: Double

    init(profit: Double) {
        self.profit = profit
        self.capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)
        self.solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: self.capitalGainsTax)
        self.churchTax = InvoiceTaxCalculator.calculateChurchTax(for: self.capitalGainsTax)
        self.totalTax = self.capitalGainsTax + self.solidaritySurcharge + self.churchTax
        self.netAmountAfterTaxes = profit - self.totalTax
    }
}
