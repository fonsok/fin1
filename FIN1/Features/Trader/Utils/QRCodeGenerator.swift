import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI
import UIKit

// MARK: - QR Code Generator
/// Generates QR codes for invoice information
final class QRCodeGenerator {

    // MARK: - Shared Resources

    /// Shared CIContext for efficient QR code generation
    private static let sharedContext: CIContext = {
        guard let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            fatalError("Failed to create sRGB color space")
        }
        let options: [CIContextOption: Any] = [
            .workingColorSpace: sRGBColorSpace,
            .outputColorSpace: sRGBColorSpace
        ]
        return CIContext(options: options)
    }()

    // MARK: - Public Methods

    /// Generates a QR code image from a string
    /// - Parameters:
    ///   - string: The string to encode in the QR code
    ///   - size: The size of the QR code image (default: 200x200, max: 512x512 for memory efficiency)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard !string.isEmpty else {
            print("❌ DEBUG: Cannot generate QR code from empty string")
            return nil
        }

        print("🔧 DEBUG: Generating QR code for string length: \(string.count)")

        // Check if data is too large for QR code (QR codes have practical limits)
        let maxQRDataLength = 2_953 // Maximum for version 40 with M error correction
        let processedString: String
        if string.count > maxQRDataLength {
            print("⚠️ DEBUG: QR data too large (\(string.count) chars), truncating to \(maxQRDataLength)")
            processedString = String(string.prefix(maxQRDataLength))
        } else {
            processedString = string
        }

        // Limit size for memory efficiency (max 512x512)
        let maxSize: CGFloat = 512
        let clampedSize = CGSize(
            width: min(size.width, maxSize),
            height: min(size.height, maxSize)
        )

        // Create QR code filter
        let filter = CIFilter.qrCodeGenerator()

        // Set the input data
        guard let data = processedString.data(using: String.Encoding.utf8) else {
            print("❌ DEBUG: Failed to convert string to UTF-8 data")
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")

        // Set error correction level (higher = more robust)
        filter.setValue("M", forKey: "inputCorrectionLevel")

        // Generate the QR code
        guard let outputImage = filter.outputImage else {
            print("❌ DEBUG: Failed to generate QR code output image - data may be too large or invalid")
            return nil
        }

        // Scale the image to the desired size
        let scaleX = clampedSize.width / outputImage.extent.size.width
        let scaleY = clampedSize.height / outputImage.extent.size.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let scaledImage = outputImage.transformed(by: transform)

        // Create UIImage from CIImage using shared context
        guard let cgImage = sharedContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            print("❌ DEBUG: Failed to create CGImage from QR code")
            return nil
        }

        let qrCodeImage = UIImage(cgImage: cgImage)
        print("🔧 DEBUG: QR code generated successfully, size: \(qrCodeImage.size)")

        return qrCodeImage
    }

    /// Generates QR code data for an invoice
    /// - Parameter invoice: The invoice to generate QR code data for
    /// - Returns: A structured string containing invoice information
    static func generateInvoiceQRData(for invoice: Invoice) -> String {
        var qrData: [String: String] = [:]

        // Basic invoice information
        qrData["type"] = "\(LegalIdentity.documentPrefix)_INVOICE"
        qrData["version"] = "1.0"
        qrData["invoice_number"] = invoice.invoiceNumber
        qrData["invoice_id"] = invoice.id
        qrData["status"] = invoice.status.rawValue
        qrData["created_at"] = ISO8601DateFormatter().string(from: invoice.createdAt)

        // Customer information
        qrData["customer_name"] = invoice.customerInfo.name
        qrData["customer_number"] = invoice.customerInfo.customerNumber
        qrData["customer_tax_number"] = invoice.customerInfo.taxNumber

        // Financial information
        qrData["total_amount"] = String(invoice.totalAmount)
        qrData["subtotal"] = String(invoice.subtotal)
        qrData["tax_amount"] = String(invoice.totalTax)
        qrData["currency"] = "EUR"

        // Transaction information
        if let tradeId = invoice.tradeId {
            qrData["trade_id"] = tradeId
        }
        if let tradeNumber = invoice.tradeNumber {
            qrData["trade_number"] = String(tradeNumber)
        }
        if let orderId = invoice.orderId {
            qrData["order_id"] = orderId
        }
        if let transactionType = invoice.transactionType {
            qrData["transaction_type"] = transactionType.rawValue
        }

        // Due date
        if let dueDate = invoice.dueDate {
            qrData["due_date"] = ISO8601DateFormatter().string(from: dueDate)
        }

        // Convert to JSON string
        do {
            // Use compact JSON (no pretty printing) to reduce size
            let jsonData = try JSONSerialization.data(withJSONObject: qrData, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            print("🔧 DEBUG: Generated QR data length: \(jsonString.count) characters")
            return jsonString
        } catch {
            print("❌ DEBUG: Failed to serialize QR data to JSON: \(error.localizedDescription)")
            // Fallback to simple string format
            return "\(LegalIdentity.documentPrefix)_INVOICE|\(invoice.invoiceNumber)|\(invoice.id)|\(invoice.totalAmount)|\(invoice.customerInfo.name)"
        }
    }

    /// Generates a QR code image for an invoice
    /// - Parameters:
    ///   - invoice: The invoice to generate QR code for
    ///   - size: The size of the QR code image (default: 200x200)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    static func generateInvoiceQRCode(for invoice: Invoice, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let qrData = self.generateInvoiceQRData(for: invoice)
        return self.generateQRCode(from: qrData, size: size)
    }

    /// Generates QR code data for a collection bill (trade statement)
    /// - Parameters:
    ///   - trade: The trade to generate QR code data for
    ///   - displayProperties: The display properties containing all trade statement information
    /// - Returns: A structured string containing comprehensive trade information
    static func generateCollectionBillQRData(for trade: TradeOverviewItem, displayProperties: TradeStatementDisplayProperties) -> String {
        var qrData: [String: String] = [:]

        self.addBasicTradeInfo(to: &qrData, trade: trade)
        self.addDepotInfo(to: &qrData, displayProperties: displayProperties)
        self.addTransactionFlags(to: &qrData, displayProperties: displayProperties)
        self.addBuyTransactionInfo(to: &qrData, displayProperties: displayProperties)
        self.addSellTransactionInfo(to: &qrData, displayProperties: displayProperties)
        self.addSummaryInfo(to: &qrData, displayProperties: displayProperties)
        self.addFinancialInfo(to: &qrData, trade: trade)
        self.addLegalInfo(to: &qrData, displayProperties: displayProperties)

        return self.serializeQRData(qrData, trade: trade, displayProperties: displayProperties)
    }

    // MARK: - Private Helper Methods

    /// Adds basic trade information to QR data
    private static func addBasicTradeInfo(to qrData: inout [String: String], trade: TradeOverviewItem) {
        qrData["type"] = "\(LegalIdentity.documentPrefix)_COLLECTION_BILL"
        qrData["version"] = "1.0"
        qrData["trade_number"] = String(trade.tradeNumber)
        qrData["trade_id"] = trade.tradeId ?? ""
        qrData["status"] = trade.statusText
        qrData["created_at"] = ISO8601DateFormatter().string(from: trade.startDate)
        qrData["completed_at"] = ISO8601DateFormatter().string(from: trade.endDate)
    }

    /// Adds depot information to QR data
    private static func addDepotInfo(to qrData: inout [String: String], displayProperties: TradeStatementDisplayProperties) {
        qrData["depot_number"] = displayProperties.depotNumber
        qrData["depot_holder"] = displayProperties.depotHolder
        qrData["account_number"] = displayProperties.accountNumber
        qrData["security_identifier"] = displayProperties.securityIdentifier
        qrData["tax_report_transaction_number"] = displayProperties.taxReportTransactionNumber
    }

    /// Adds transaction flags to QR data
    private static func addTransactionFlags(to qrData: inout [String: String], displayProperties: TradeStatementDisplayProperties) {
        qrData["has_buy_transaction"] = String(displayProperties.hasBuyTransaction)
        qrData["has_sell_transaction"] = String(displayProperties.hasSellTransaction)
    }

    /// Adds buy transaction information to QR data
    private static func addBuyTransactionInfo(to qrData: inout [String: String], displayProperties: TradeStatementDisplayProperties) {
        guard displayProperties.hasBuyTransaction else { return }

        qrData["buy_transaction_number"] = displayProperties.buyTransactionNumber
        qrData["buy_order_volume"] = displayProperties.buyOrderVolume
        qrData["buy_executed_volume"] = displayProperties.buyExecutedVolume
        qrData["buy_price"] = displayProperties.buyPrice
        qrData["buy_exchange_rate"] = displayProperties.buyExchangeRate
        qrData["buy_conversion_factor"] = displayProperties.buyConversionFactor
        qrData["buy_custody_type"] = displayProperties.buyCustodyType
        qrData["buy_depository"] = displayProperties.buyDepository
        qrData["buy_depository_country"] = displayProperties.buyDepositoryCountry
        qrData["buy_profit_loss"] = displayProperties.buyProfitLoss
        qrData["buy_value_date"] = displayProperties.buyValueDate
        qrData["buy_trading_venue"] = displayProperties.buyTradingVenue
        qrData["buy_closing_date"] = displayProperties.buyClosingDate
        qrData["buy_market_value"] = displayProperties.buyMarketValue
        qrData["buy_commission"] = displayProperties.buyCommission
        qrData["buy_own_expenses"] = displayProperties.buyOwnExpenses
        qrData["buy_external_expenses"] = displayProperties.buyExternalExpenses
        qrData["buy_assessment_basis"] = displayProperties.buyAssessmentBasis
        qrData["buy_withheld_tax"] = displayProperties.buyWithheldTax
        qrData["buy_final_amount"] = displayProperties.buyFinalAmount
    }

    /// Adds sell transaction information to QR data
    private static func addSellTransactionInfo(to qrData: inout [String: String], displayProperties: TradeStatementDisplayProperties) {
        guard displayProperties.hasSellTransaction else { return }

        qrData["sell_transaction_number"] = displayProperties.sellTransactionNumber
        qrData["sell_order_volume"] = displayProperties.sellOrderVolume
        qrData["sell_executed_volume"] = displayProperties.sellExecutedVolume
        qrData["sell_price"] = displayProperties.sellPrice
        qrData["sell_exchange_rate"] = displayProperties.sellExchangeRate
        qrData["sell_conversion_factor"] = displayProperties.sellConversionFactor
        qrData["sell_custody_type"] = displayProperties.sellCustodyType
        qrData["sell_depository"] = displayProperties.sellDepository
        qrData["sell_depository_country"] = displayProperties.sellDepositoryCountry
        qrData["sell_profit_loss"] = displayProperties.sellProfitLoss
        qrData["sell_value_date"] = displayProperties.sellValueDate
        qrData["sell_trading_venue"] = displayProperties.sellTradingVenue
        qrData["sell_closing_date"] = displayProperties.sellClosingDate
        qrData["sell_market_value"] = displayProperties.sellMarketValue
        qrData["sell_commission"] = displayProperties.sellCommission
        qrData["sell_own_expenses"] = displayProperties.sellOwnExpenses
        qrData["sell_external_expenses"] = displayProperties.sellExternalExpenses
        qrData["sell_assessment_basis"] = displayProperties.sellAssessmentBasis
        qrData["sell_withheld_tax"] = displayProperties.sellWithheldTax
        qrData["sell_final_amount"] = displayProperties.sellFinalAmount
    }

    /// Adds summary information to QR data
    private static func addSummaryInfo(to qrData: inout [String: String], displayProperties: TradeStatementDisplayProperties) {
        qrData["total_assessment_basis"] = displayProperties.totalAssessmentBasis
        qrData["total_tax_amount"] = displayProperties.totalTaxAmount
        qrData["net_result"] = displayProperties.netResult
    }

    /// Adds financial information from trade to QR data
    private static func addFinancialInfo(to qrData: inout [String: String], trade: TradeOverviewItem) {
        qrData["profit_loss"] = String(trade.profitLoss)
        qrData["gross_profit"] = String(trade.grossProfit)
        qrData["total_fees"] = String(trade.totalFees)
        qrData["commission"] = String(trade.commission)
        qrData["currency"] = "EUR"
        qrData["is_active"] = String(trade.isActive)
        qrData["return_percentage"] = String(trade.returnPercentage)
    }

    /// Adds legal information to QR data
    private static func addLegalInfo(to qrData: inout [String: String], displayProperties: TradeStatementDisplayProperties) {
        qrData["legal_disclaimer"] = displayProperties.legalDisclaimer
    }

    /// Serializes QR data to JSON string with fallback
    private static func serializeQRData(
        _ qrData: [String: String],
        trade: TradeOverviewItem,
        displayProperties: TradeStatementDisplayProperties
    ) -> String {
        do {
            // Use compact JSON (no pretty printing) to reduce size
            let jsonData = try JSONSerialization.data(withJSONObject: qrData, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            print("🔧 DEBUG: Generated Collection Bill QR data length: \(jsonString.count) characters")

            // If still too large, use compact fallback
            if jsonString.count > 2_000 {
                print("⚠️ DEBUG: JSON still too large, using compact fallback")
                return self.createCompactFallback(trade: trade, displayProperties: displayProperties)
            }

            return jsonString
        } catch {
            print("❌ DEBUG: Failed to serialize Collection Bill QR data to JSON: \(error.localizedDescription)")
            // Fallback to simple string format
            return self.createCompactFallback(trade: trade, displayProperties: displayProperties)
        }
    }

    /// Creates a compact fallback string for QR codes
    private static func createCompactFallback(trade: TradeOverviewItem, displayProperties: TradeStatementDisplayProperties) -> String {
        return "\(LegalIdentity.documentPrefix)_CB|\(trade.tradeNumber)|\(trade.tradeId ?? "")|\(displayProperties.depotNumber)|\(trade.profitLoss)|\(trade.grossProfit)|\(trade.totalFees)"
    }

    /// Generates a QR code image for a collection bill
    /// - Parameters:
    ///   - trade: The trade to generate QR code for
    ///   - displayProperties: The display properties containing all trade statement information
    ///   - size: The size of the QR code image (default: 200x200)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    static func generateCollectionBillQRCode(
        for trade: TradeOverviewItem,
        displayProperties: TradeStatementDisplayProperties,
        size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage? {
        let qrData = self.generateCollectionBillQRData(for: trade, displayProperties: displayProperties)
        return self.generateQRCode(from: qrData, size: size)
    }

    /// Generates QR code data for a credit note (Document)
    /// - Parameter document: The document to generate QR code data for
    /// - Returns: A structured string containing document information
    static func generateCreditNoteQRData(for document: Document) -> String {
        var qrData: [String: String] = [:]

        qrData["type"] = "\(LegalIdentity.documentPrefix)_CREDIT_NOTE"
        qrData["version"] = "1.0"
        qrData["document_id"] = document.id
        qrData["document_number"] = document.accountingDocumentNumber ?? document.documentNumber ?? ""
        qrData["document_type"] = document.type.rawValue
        qrData["status"] = document.status.rawValue
        qrData["created_at"] = ISO8601DateFormatter().string(from: document.uploadedAt)

        if let tradeId = document.tradeId {
            qrData["trade_id"] = tradeId
        }

        if let invoiceData = document.invoiceData {
            qrData["invoice_number"] = invoiceData.invoiceNumber
            qrData["total_amount"] = String(invoiceData.totalAmount)
            // customerInfo is not optional in Invoice
            qrData["customer_name"] = invoiceData.customerInfo.name
            qrData["customer_number"] = invoiceData.customerInfo.customerNumber
        }

        // Convert to JSON string
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: qrData, options: [])
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return "\(LegalIdentity.documentPrefix)_CREDIT_NOTE|\(document.id)|\(document.accountingDocumentNumber ?? "")"
        }
    }

    /// Generates a QR code image for a credit note
    static func generateCreditNoteQRCode(for document: Document, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let qrData = self.generateCreditNoteQRData(for: document)
        return self.generateQRCode(from: qrData, size: size)
    }

    /// Generates QR code data for an investor collection bill
    /// - Parameters:
    ///   - investment: The investment to generate QR code data for
    ///   - documentNumber: The document number
    /// - Returns: A structured string containing investment information
    static func generateInvestorCollectionBillQRData(for investment: Investment, documentNumber: String) -> String {
        var qrData: [String: String] = [:]

        qrData["type"] = "\(LegalIdentity.documentPrefix)_INVESTOR_COLLECTION_BILL"
        qrData["version"] = "1.0"
        qrData["investment_id"] = investment.id
        qrData["document_number"] = documentNumber
        qrData["investor_id"] = investment.investorId
        qrData["trader_name"] = investment.traderName
        qrData["amount"] = String(investment.amount)
        qrData["created_at"] = ISO8601DateFormatter().string(from: investment.createdAt)

        if let completedAt = investment.completedAt {
            qrData["completed_at"] = ISO8601DateFormatter().string(from: completedAt)
        }

        // Convert to JSON string
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: qrData, options: [])
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return "\(LegalIdentity.documentPrefix)_INVESTOR_COLLECTION_BILL|\(investment.id)|\(documentNumber)"
        }
    }

    /// Generates a QR code image for an investor collection bill
    static func generateInvestorCollectionBillQRCode(
        for investment: Investment,
        documentNumber: String,
        size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage? {
        let qrData = self.generateInvestorCollectionBillQRData(for: investment, documentNumber: documentNumber)
        return self.generateQRCode(from: qrData, size: size)
    }
}

// MARK: - QR Code Views
// QR Code SwiftUI views have been moved to QRCodeViews.swift to reduce file size
// Import QRCodeViews.swift to use: InvoiceQRCodeView, CollectionBillQRCodeView, CreditNoteQRCodeView, InvestorCollectionBillQRCodeView
