import Foundation

// MARK: - Company Info DTO (from LegalIdentity)

/// Company information sent to backend for PDF header.
/// Uses values from LegalIdentity and CompanyContactInfo.
struct CompanyInfoDTO: Encodable {
    let name: String
    let address: String
    let city: String
    let email: String
    let phone: String
    let website: String
    let businessHours: String
    let registerNumber: String
    let vatId: String
    let management: String
    let bankName: String
    let bankIban: String
    let bankBic: String
    let documentPrefix: String

    static func fromLegalIdentity() -> CompanyInfoDTO {
        CompanyInfoDTO(
            name: CompanyContactInfo.companyName,
            address: CompanyContactInfo.address,
            city: CompanyContactInfo.city,
            email: CompanyContactInfo.email,
            phone: CompanyContactInfo.phone,
            website: CompanyContactInfo.website,
            businessHours: CompanyContactInfo.businessHours,
            registerNumber: CompanyContactInfo.registerNumber,
            vatId: CompanyContactInfo.vatId,
            management: "Geschäftsführung: \(CompanyContactInfo.management)",
            bankName: CompanyContactInfo.bankName,
            bankIban: CompanyContactInfo.bankIBAN,
            bankBic: CompanyContactInfo.bic,
            documentPrefix: LegalIdentity.documentPrefix
        )
    }
}

// MARK: - Request DTOs

struct InvoicePDFRequest: Encodable {
    let invoiceNumber: String
    let invoiceType: String
    let customerInfo: CustomerInfoDTO
    let items: [InvoiceItemDTO]
    let subtotal: Double
    let totalTax: Double
    let totalAmount: Double
    let createdAt: String?
    let tradeId: String?
    let tradeNumber: Int?
    let orderId: String?
    let transactionType: String?
    let taxNote: String?
    let legalNote: String?
    let qrData: String?
    let companyInfo: CompanyInfoDTO

    init(from invoice: Invoice) {
        self.invoiceNumber = invoice.invoiceNumber
        self.invoiceType = invoice.type.rawValue
        self.customerInfo = CustomerInfoDTO(from: invoice.customerInfo)
        self.items = invoice.items.map { InvoiceItemDTO(from: $0) }
        self.subtotal = invoice.subtotal
        self.totalTax = invoice.totalTax
        self.totalAmount = invoice.totalAmount
        self.createdAt = ISO8601DateFormatter().string(from: invoice.createdAt)
        self.tradeId = invoice.tradeId
        self.tradeNumber = invoice.tradeNumber
        self.orderId = invoice.orderId
        self.transactionType = invoice.transactionType?.rawValue
        self.taxNote = invoice.taxNote
        self.legalNote = invoice.legalNote
        self.qrData = QRCodeGenerator.generateInvoiceQRData(for: invoice)
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

struct TradeStatementPDFRequest: Encodable {
    let tradeNumber: Int
    let depotNumber: String
    let depotHolder: String
    let securityIdentifier: String
    let accountNumber: String
    let buyTransaction: BuyTransactionDTO?
    let sellTransactions: [SellTransactionDTO]
    let calculationBreakdown: CalculationBreakdownDTO
    let taxSummary: TaxSummaryDTO
    let legalDisclaimer: String
    let companyInfo: CompanyInfoDTO

    init(from displayData: TradeStatementDisplayData, tradeNumber: Int) {
        self.tradeNumber = tradeNumber
        self.depotNumber = displayData.depotNumber
        self.depotHolder = displayData.depotHolder
        self.securityIdentifier = displayData.securityIdentifier
        self.accountNumber = displayData.accountNumber
        self.buyTransaction = displayData.buyTransaction.map { BuyTransactionDTO(from: $0) }
        self.sellTransactions = displayData.sellTransactions.map { SellTransactionDTO(from: $0) }
        self.calculationBreakdown = CalculationBreakdownDTO(from: displayData.calculationBreakdown)
        self.taxSummary = TaxSummaryDTO(from: displayData.taxSummary)
        self.legalDisclaimer = displayData.legalDisclaimer
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

struct CreditNotePDFRequest: Encodable {
    let creditNoteNumber: String
    let customerInfo: CustomerInfoDTO
    let items: [InvoiceItemDTO]
    let totalAmount: Double
    let reason: String
    let originalInvoiceNumber: String?
    let createdAt: String?
    let qrData: String?
    let companyInfo: CompanyInfoDTO

    init(from invoice: Invoice) {
        self.creditNoteNumber = invoice.invoiceNumber
        self.customerInfo = CustomerInfoDTO(from: invoice.customerInfo)
        self.items = invoice.items.map { InvoiceItemDTO(from: $0) }
        self.totalAmount = invoice.totalAmount
        self.reason = invoice.legalNote ?? ""
        self.originalInvoiceNumber = nil
        self.createdAt = ISO8601DateFormatter().string(from: invoice.createdAt)
        self.qrData = QRCodeGenerator.generateInvoiceQRData(for: invoice)
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

struct AccountStatementPDFRequest: Encodable {
    let statementNumber: String
    let customerInfo: CustomerInfoDTO
    let statementPeriod: String
    let entries: [AccountStatementEntryDTO]
    let openingBalance: Double
    let closingBalance: Double
    let createdAt: String?
    let companyInfo: CompanyInfoDTO

    init(
        statementNumber: String,
        customerInfo: CustomerInfo,
        period: String,
        entries: [AccountStatementEntry],
        openingBalance: Double,
        closingBalance: Double
    ) {
        self.statementNumber = statementNumber
        self.customerInfo = CustomerInfoDTO(from: customerInfo)
        self.statementPeriod = period
        self.entries = entries.map { AccountStatementEntryDTO(from: $0) }
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}
