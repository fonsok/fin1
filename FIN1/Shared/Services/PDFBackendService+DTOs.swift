import Foundation

// MARK: - DTO Types

struct CustomerInfoDTO: Encodable {
    let name: String
    let address: String
    let city: String
    let postalCode: String
    let taxNumber: String
    let customerNumber: String
    let depotNumber: String
    let bank: String

    init(from info: CustomerInfo) {
        self.name = info.name
        self.address = info.address
        self.city = info.city
        self.postalCode = info.postalCode
        self.taxNumber = info.taxNumber
        self.customerNumber = info.customerNumber
        self.depotNumber = info.depotNumber
        self.bank = info.bank
    }
}

struct InvoiceItemDTO: Encodable {
    let description: String
    let quantity: Double
    let unitPrice: Double
    let totalAmount: Double
    let itemType: String

    init(from item: InvoiceItem) {
        self.description = item.description
        self.quantity = item.quantity
        self.unitPrice = item.unitPrice
        self.totalAmount = item.totalAmount
        self.itemType = item.itemType.rawValue
    }
}

struct BuyTransactionDTO: Encodable {
    let transactionNumber: String
    let orderVolume: String
    let executedVolume: String
    let price: String
    let marketValue: String
    let commission: String
    let ownExpenses: String
    let externalExpenses: String
    let finalAmount: String

    init(from data: BuyTransactionData) {
        self.transactionNumber = data.transactionNumber
        self.orderVolume = data.orderVolume
        self.executedVolume = data.executedVolume
        self.price = data.price
        self.marketValue = data.marketValue
        self.commission = data.commission
        self.ownExpenses = data.ownExpenses
        self.externalExpenses = data.externalExpenses
        self.finalAmount = data.finalAmount
    }
}

struct SellTransactionDTO: Encodable {
    let transactionNumber: String
    let orderVolume: String
    let price: String
    let marketValue: String
    let commission: String
    let finalAmount: String

    init(from data: SellTransactionData) {
        self.transactionNumber = data.transactionNumber
        self.orderVolume = data.orderVolume
        self.price = data.price
        self.marketValue = data.marketValue
        self.commission = data.commission
        self.finalAmount = data.finalAmount
    }
}

struct CalculationBreakdownDTO: Encodable {
    let totalSellAmount: String
    let buyAmount: String
    let resultBeforeTaxes: String

    init(from data: CalculationBreakdownData) {
        self.totalSellAmount = data.totalSellAmount
        self.buyAmount = data.buyAmount
        self.resultBeforeTaxes = data.resultBeforeTaxes
    }
}

struct TaxSummaryDTO: Encodable {
    let assessmentBasis: String
    let totalTax: String
    let netResult: String

    init(from data: TaxSummaryData) {
        self.assessmentBasis = data.assessmentBasis
        self.totalTax = data.totalTax
        self.netResult = data.netResult
    }
}

struct AccountStatementEntryDTO: Encodable {
    let date: String
    let description: String
    let category: String
    let amount: Double
    let direction: String
    let balanceAfter: Double?

    init(from entry: AccountStatementEntry) {
        self.date = ISO8601DateFormatter().string(from: entry.occurredAt)
        self.description = entry.title
        self.category = entry.category.rawValue
        self.amount = entry.amount
        self.direction = entry.direction.rawValue
        self.balanceAfter = entry.balanceAfter
    }
}
