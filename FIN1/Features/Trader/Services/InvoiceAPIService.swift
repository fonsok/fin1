import Foundation

// MARK: - Invoice API Service Protocol

/// Protocol for syncing invoices to Parse Server backend
protocol InvoiceAPIServiceProtocol {
    /// Saves an invoice to the Parse Server
    func saveInvoice(_ invoice: Invoice) async throws -> Invoice

    /// Updates an existing invoice on the Parse Server
    func updateInvoice(_ invoice: Invoice) async throws -> Invoice

    /// Fetches all invoices for a user via Cloud Function (session-based, uses stableId).
    func fetchInvoices(for userId: String) async throws -> [Invoice]

    /// Deletes an invoice from the Parse Server
    func deleteInvoice(_ invoiceId: String) async throws
}

// MARK: - BackendInvoice → Invoice Converter

extension BackendInvoice {
    /// Builds Net + VAT InvoiceItems from the canonical `subtotal`/`taxAmount`/`taxRate` fields
    /// the backend populates on `service_charge` Invoice rows. Falls back to embedding the
    /// breakdown text from `investmentIds` (see `bookAppServiceCharge`) so the line description
    /// reflects the per-investment basis instead of an empty "Rechnung" placeholder.
    fileprivate func buildServiceChargeItems() -> [InvoiceItem] {
        let net = subtotal ?? netAmount ?? max(0, (totalAmount ?? 0) - (taxAmount ?? 0))
        let vat = taxAmount ?? 0
        let rate = taxRate ?? (net > 0 && vat > 0 ? (vat / net) * 100 : 0)

        let breakdownLines = (investmentIds ?? []).filter { !$0.isEmpty }
        let header: String
        if let invNumber = metadata?.investmentNumber, !invNumber.isEmpty {
            header = "App-Servicegebühr \(invNumber)"
        } else {
            header = "App-Servicegebühr"
        }
        let description: String = breakdownLines.isEmpty
            ? header
            : ([header] + breakdownLines).joined(separator: "\n")

        var items: [InvoiceItem] = [
            InvoiceItem(
                description: description,
                quantity: 1,
                unitPrice: net,
                itemType: .serviceCharge
            )
        ]
        if vat > 0 {
            let vatLabel: String
            if rate > 0 {
                vatLabel = String(format: "Umsatzsteuer (%.0f%%)", rate)
            } else {
                vatLabel = "Umsatzsteuer"
            }
            items.append(
                InvoiceItem(
                    description: vatLabel,
                    quantity: 1,
                    unitPrice: vat,
                    itemType: .vat
                )
            )
        }
        return items
    }

    func toLocalInvoice() -> Invoice? {
        let invoiceNum = invoiceNumber ?? "INV-\(objectId.prefix(8))"

        let appType: InvoiceType
        let txType: TransactionType?
        switch invoiceType {
        case "buy_invoice":
            appType = .securitiesSettlement; txType = .buy
        case "sell_invoice":
            appType = .securitiesSettlement; txType = .sell
        case "service_charge", "app_service_charge", "platform_service_charge": // legacy: platform_service_charge
            appType = .appServiceCharge; txType = nil
        case "credit_note":
            appType = .creditNote; txType = nil
        case "commission_invoice":
            appType = .commissionInvoice; txType = nil
        default:
            appType = .securitiesSettlement; txType = nil
        }

        let appStatus: InvoiceStatus
        switch status {
        case "paid": appStatus = .paid
        case "sent": appStatus = .sent
        case "cancelled": appStatus = .cancelled
        case "generated": appStatus = .generated
        default: appStatus = .generated
        }

        let items: [InvoiceItem]
        if let backendItems = lineItems, !backendItems.isEmpty {
            items = backendItems.compactMap { li in
                let liType: InvoiceItemType
                switch li.itemType {
                case "securities": liType = .securities
                case "orderFee": liType = .orderFee
                case "exchangeFee": liType = .exchangeFee
                case "foreignCosts": liType = .foreignCosts
                case "serviceCharge": liType = .serviceCharge
                case "commission": liType = .commission
                case "vat": liType = .vat
                default: liType = .other
                }
                return InvoiceItem(
                    description: li.description ?? "",
                    quantity: li.quantity ?? 1,
                    unitPrice: li.unitPrice ?? 0,
                    itemType: liType
                )
            }
        } else if appType == .appServiceCharge {
            // Backend stores subtotal (net), taxAmount, taxRate, totalAmount on the Invoice
            // row directly (see bookAppServiceCharge). Build a minimal Net + USt line set so
            // the display view can render description and 19%-aufteilung correctly.
            items = buildServiceChargeItems()
        } else {
            let desc = txType == .buy ? "Kauf" : txType == .sell ? "Verkauf" : "Rechnung"
            items = [InvoiceItem(description: desc, quantity: 1, unitPrice: totalAmount ?? 0, itemType: .securities)]
        }

        let customerInfo = CustomerInfo(
            name: customerName ?? userId ?? "",
            address: customerAddress ?? "",
            city: customerCity ?? "",
            postalCode: customerPostalCode ?? "",
            taxNumber: "",
            depotNumber: "",
            bank: "",
            customerNumber: customerId ?? userId ?? "",
            userId: userId ?? ""
        )

        return Invoice(
            id: objectId,
            invoiceNumber: invoiceNum,
            type: appType,
            status: appStatus,
            customerInfo: customerInfo,
            items: items,
            tradeId: tradeId,
            orderId: orderId,
            transactionType: txType,
            traderCommissionRateSnapshot: traderCommissionRateSnapshot
        )
    }
}

// MARK: - Parse Invoice Models

/// Parse Server representation of an Invoice
private struct ParseInvoice: Codable {
    let objectId: String
    let invoiceNumber: String
    let invoiceType: String
    let userId: String
    let orderId: String?
    let tradeId: String?
    let subtotal: Double
    let totalFees: Double
    let totalAmount: Double
    let invoiceDate: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let traderCommissionRateSnapshot: Double?

    // Customer info (stored as nested object or flattened)
    let customerName: String?
    let customerAddress: String?
    let customerEmail: String?
    let customerId: String?

    func toInvoice() -> Invoice? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard dateFormatter.date(from: createdAt) != nil,
              dateFormatter.date(from: invoiceDate) != nil,
              let invoiceStatus = InvoiceStatus(rawValue: status) else {
            return nil
        }

        // Map Parse Server invoiceType to app InvoiceType
        let appInvoiceType: InvoiceType
        switch invoiceType {
        case "buy_invoice", "buy":
            appInvoiceType = .securitiesSettlement // Will be mapped via transactionType
        case "sell_invoice", "sell":
            appInvoiceType = .securitiesSettlement // Will be mapped via transactionType
        case "service_charge", "app_service_charge", "platform_service_charge": // legacy: platform_service_charge
            appInvoiceType = .appServiceCharge
        case "credit_note":
            appInvoiceType = .creditNote
        case "commission_invoice":
            appInvoiceType = .commissionInvoice
        default:
            appInvoiceType = .securitiesSettlement
        }

        // Determine transaction type from invoiceType
        let transactionType: TransactionType?
        if invoiceType == "buy_invoice" || invoiceType == "buy" {
            transactionType = .buy
        } else if invoiceType == "sell_invoice" || invoiceType == "sell" {
            transactionType = .sell
        } else {
            transactionType = nil
        }

        // Build customer info
        let customerInfo = CustomerInfo(
            name: customerName ?? "",
            address: customerAddress ?? "",
            city: "",
            postalCode: "",
            taxNumber: "",
            depotNumber: "",
            bank: "",
            customerNumber: customerId ?? userId,
            userId: userId
        )

        // Build invoice items from totals
        // Note: Parse Server stores totals, not individual items
        // We'll create a single item representing the total
        let itemDescription: String
        let itemType: InvoiceItemType
        if invoiceType == "buy_invoice" {
            itemDescription = "Kauf"
            itemType = .securities
        } else if invoiceType == "sell_invoice" {
            itemDescription = "Verkauf"
            itemType = .securities
        } else if invoiceType == "service_charge" {
            itemDescription = "Service Charge"
            itemType = .serviceCharge
        } else {
            itemDescription = "Rechnung"
            itemType = .other
        }

        let items: [InvoiceItem] = [
            InvoiceItem(
                description: itemDescription,
                quantity: 1.0,
                unitPrice: subtotal,
                itemType: itemType
            )
        ]

        return Invoice(
            id: objectId,
            invoiceNumber: invoiceNumber,
            type: appInvoiceType,
            status: invoiceStatus,
            customerInfo: customerInfo,
            items: items,
            tradeId: tradeId,
            orderId: orderId,
            transactionType: transactionType,
            dueDate: nil,
            traderCommissionRateSnapshot: traderCommissionRateSnapshot
        )
    }
}

/// Input struct for creating/updating invoices on Parse Server
private struct ParseInvoiceInput: Codable {
    let invoiceNumber: String
    let invoiceType: String
    let userId: String
    let orderId: String?
    let tradeId: String?
    let subtotal: Double
    let totalFees: Double
    let totalAmount: Double
    let invoiceDate: String
    let status: String
    let customerName: String
    let customerAddress: String
    let customerEmail: String?
    let customerId: String
    let traderCommissionRateSnapshot: Double?

    static func from(invoice: Invoice) -> ParseInvoiceInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let invoiceTypeString: String
        if let transactionType = invoice.transactionType {
            switch transactionType {
            case .buy:
                invoiceTypeString = "buy_invoice"
            case .sell:
                invoiceTypeString = "sell_invoice"
            }
        } else {
            switch invoice.type {
            case .securitiesSettlement:
                invoiceTypeString = "buy_invoice"
            case .appServiceCharge:
                invoiceTypeString = "service_charge"
            case .creditNote:
                invoiceTypeString = "credit_note"
            case .commissionInvoice:
                invoiceTypeString = "commission_invoice"
            case .tradingFee:
                invoiceTypeString = "trading_fee"
            case .accountStatement:
                invoiceTypeString = "account_statement"
            }
        }

        let resolvedUserId = invoice.customerInfo.userId.isEmpty
            ? invoice.customerInfo.customerNumber
            : invoice.customerInfo.userId

        return ParseInvoiceInput(
            invoiceNumber: invoice.invoiceNumber,
            invoiceType: invoiceTypeString,
            userId: resolvedUserId,
            orderId: invoice.orderId,
            tradeId: invoice.tradeId,
            subtotal: invoice.subtotal,
            totalFees: invoice.totalTax,
            totalAmount: invoice.totalAmount,
            invoiceDate: dateFormatter.string(from: invoice.createdAt),
            status: invoice.status.rawValue,
            customerName: invoice.customerInfo.name,
            customerAddress: invoice.customerInfo.fullAddress,
            customerEmail: nil,
            customerId: invoice.customerInfo.customerNumber,
            traderCommissionRateSnapshot: invoice.traderCommissionRateSnapshot
        )
    }
}

// MARK: - Invoice API Service Implementation

final class InvoiceAPIService: InvoiceAPIServiceProtocol {

    private let apiClient: ParseAPIClientProtocol
    private let invoiceClassName = "Invoice"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func saveInvoice(_ invoice: Invoice) async throws -> Invoice {
        print("📡 InvoiceAPIService: Saving invoice to Parse Server")
        print("   📋 Invoice Number: \(invoice.invoiceNumber)")
        print("   📝 Type: \(invoice.type.rawValue)")

        let parseInput = ParseInvoiceInput.from(invoice: invoice)

        let response = try await apiClient.createObject(
            className: invoiceClassName,
            object: parseInput
        )

        print("✅ InvoiceAPIService: Invoice saved with objectId: \(response.objectId)")

        // Return invoice with Parse objectId
        return Invoice(
            id: response.objectId,
            invoiceNumber: invoice.invoiceNumber,
            type: invoice.type,
            status: invoice.status,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: invoice.tradeId,
            tradeNumber: invoice.tradeNumber,
            orderId: invoice.orderId,
            transactionType: invoice.transactionType,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: invoice.dueDate,
            traderCommissionRateSnapshot: invoice.traderCommissionRateSnapshot
        )
    }

    func updateInvoice(_ invoice: Invoice) async throws -> Invoice {
        print("📡 InvoiceAPIService: Updating invoice on Parse Server")
        print("   📋 Invoice ID: \(invoice.id)")

        // Only update if invoice has Parse objectId (not local-only)
        guard !invoice.id.starts(with: "local-") && invoice.id.contains("-") else {
            // Local-only invoice - save as new instead
            return try await saveInvoice(invoice)
        }

        let parseInput = ParseInvoiceInput.from(invoice: invoice)

        let response = try await apiClient.updateObject(
            className: invoiceClassName,
            objectId: invoice.id,
            object: parseInput
        )

        print("✅ InvoiceAPIService: Invoice updated")

        // Return updated invoice
        return Invoice(
            id: response.objectId,
            invoiceNumber: invoice.invoiceNumber,
            type: invoice.type,
            status: invoice.status,
            customerInfo: invoice.customerInfo,
            items: invoice.items,
            tradeId: invoice.tradeId,
            tradeNumber: invoice.tradeNumber,
            orderId: invoice.orderId,
            transactionType: invoice.transactionType,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote,
            dueDate: invoice.dueDate,
            traderCommissionRateSnapshot: invoice.traderCommissionRateSnapshot
        )
    }

    func fetchInvoices(for userId: String) async throws -> [Invoice] {
        print("📡 InvoiceAPIService: Fetching invoices for user: \(userId)")

        // Prefer getUserInvoices cloud function (session-based, resolves stableId)
        do {
            let response: BackendInvoiceListResponse = try await apiClient.callFunction(
                "getUserInvoices",
                parameters: ["limit": 100, "skip": 0] as [String: Any]
            )
            let invoices = response.invoices.compactMap { $0.toLocalInvoice() }
            print("✅ InvoiceAPIService: Fetched \(invoices.count) invoices via cloud function")
            return invoices
        } catch {
            print("⚠️ InvoiceAPIService: Cloud function failed, falling back to direct query: \(error.localizedDescription)")
        }

        // Fallback: direct Parse query
        let query: [String: Any] = ["userId": userId]
        let parseInvoices: [ParseInvoice] = try await apiClient.fetchObjects(
            className: invoiceClassName,
            query: query,
            include: nil,
            orderBy: "-invoiceDate",
            limit: 100
        )
        print("✅ InvoiceAPIService: Fetched \(parseInvoices.count) invoices via direct query")
        return parseInvoices.compactMap { $0.toInvoice() }
    }

    func deleteInvoice(_ invoiceId: String) async throws {
        print("📡 InvoiceAPIService: Deleting invoice: \(invoiceId)")

        try await apiClient.deleteObject(
            className: invoiceClassName,
            objectId: invoiceId
        )

        print("✅ InvoiceAPIService: Invoice deleted")
    }
}
