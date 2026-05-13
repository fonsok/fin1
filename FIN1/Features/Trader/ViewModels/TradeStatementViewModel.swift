import Combine
import Foundation
import SwiftUI

// MARK: - Trade Statement View Model
/// Handles data and calculations for the collective billing statement

@MainActor
final class TradeStatementViewModel: ObservableObject {
    /// Snapshot for statement/PDF; includes a non-Sendable `onDetailsTapped` closure — not passed across actors.
    nonisolated(unsafe) let trade: TradeOverviewItem
    private var invoiceService: (any InvoiceServiceProtocol)?
    private var tradeService: (any TradeLifecycleServiceProtocol)?

    // Services
    nonisolated(unsafe) private let pdfService: TradeStatementPDFServiceProtocol
    private let displayDataBuilder: TradeStatementDisplayDataBuilderProtocol
    private let displayService: TradeStatementDisplayServiceProtocol

    // Full Trade object for accessing detailed information
    @Published var fullTrade: Trade?

    // Invoice data
    @Published var buyInvoice: Invoice?
    @Published var sellInvoices: [Invoice] = []

    // Display data
    @Published var displayData: TradeStatementDisplayData?

    // Computed display properties
    var displayProperties: TradeStatementDisplayProperties? {
        guard let displayData = displayData else { return nil }
        return self.displayService.getDisplayProperties(from: displayData, trade: self.trade)
    }

    // PDF generation state
    @Published var isGeneratingPDF = false
    @Published var pdfGenerationProgress: Double = 0.0
    @Published var pdfPreviewImage: UIImage?
    @Published var showError = false
    @Published var errorMessage: String?
    
    // MARK: - Document Number
    /// Eindeutige Belegnummer für dieses Collection Bill Dokument (gemäß GoB)
    @Published var documentNumber: String?

    // MARK: - Initialization

    init(
        trade: TradeOverviewItem,
        pdfService: any TradeStatementPDFServiceProtocol,
        displayDataBuilder: any TradeStatementDisplayDataBuilderProtocol,
        displayService: any TradeStatementDisplayServiceProtocol
    ) {
        self.trade = trade
        self.pdfService = pdfService
        self.displayDataBuilder = displayDataBuilder
        self.displayService = displayService
    }
    
    /// Convenience initializer with default services (for backward compatibility)
    /// ⚠️ Prefer using the full initializer with injected services
    convenience init(trade: TradeOverviewItem) {
        self.init(
            trade: trade,
            pdfService: TradeStatementPDFService(),
            displayDataBuilder: TradeStatementDisplayDataBuilder(),
            displayService: TradeStatementDisplayService()
        )
    }

    // MARK: - Service Attachment

    func attach(
        invoiceService: any InvoiceServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        prefetchedFullTrade: Trade? = nil
    ) {
        self.invoiceService = invoiceService
        self.tradeService = tradeService
        self.loadFullTrade(prefetched: prefetchedFullTrade)
        self.loadInvoices()
        self.updateDisplayData()
    }

    // MARK: - Public Methods

    /// Forces a refresh of all display data (useful when calculation logic changes)
    func refreshDisplayData() {
        self.updateDisplayData()
    }

    // MARK: - Private Methods

    private func loadFullTrade(prefetched: Trade? = nil) {
        guard let service = tradeService, let tradeId = trade.tradeId else {
            print("❌ TradeStatementViewModel: No trade service or trade ID")
            print("   - tradeService: \(self.tradeService != nil ? "✅" : "❌")")
            print("   - tradeId: \(self.trade.tradeId ?? "NIL")")
            return
        }

        if let prefetched, prefetched.id == tradeId {
            fullTrade = prefetched
        } else {
            let completedTrades = service.completedTrades
            fullTrade = completedTrades.first { $0.id == tradeId }
        }

        if let fullTrade = fullTrade {
            print("✅ TradeStatementViewModel: Loaded full trade with \(fullTrade.sellOrders.count) sell orders")
        } else {
            print("❌ TradeStatementViewModel: Could not find full trade for ID: \(tradeId)")
            let completedTrades = service.completedTrades
            let availableIds = completedTrades.map { $0.id }
            print("   Available trade IDs: \(availableIds)")
        }
    }

    private func loadInvoices() {
        guard let service = invoiceService, let tradeId = trade.tradeId else {
            print("❌ TradeStatementViewModel: No invoice service or trade ID")
            print("   - invoiceService: \(self.invoiceService != nil ? "✅" : "❌")")
            print("   - tradeId: \(self.trade.tradeId ?? "NIL")")
            return
        }

        let allInvoices = service.invoices.filter { $0.tradeId == tradeId }
        self.buyInvoice = allInvoices.first { $0.transactionType == .buy }
        self.sellInvoices = allInvoices.filter { $0.transactionType == .sell }

        print(
            "📄 TradeStatementViewModel: Loaded \(allInvoices.count) invoices: \(self.buyInvoice != nil ? "1 buy" : "0 buy"), \(self.sellInvoices.count) sell"
        )

        // Update display data when invoices are loaded
        self.updateDisplayData()
    }

    private func updateDisplayData() {
        self.displayData = self.displayDataBuilder.buildDisplayData(
            trade: self.trade,
            fullTrade: self.fullTrade,
            buyInvoice: self.buyInvoice,
            sellInvoices: self.sellInvoices
        )
    }

    // MARK: - PDF Generation Methods

    /// Generates a PDF for the trade statement
    func generatePDF() {
        guard let displayData = displayData else {
            self.errorMessage = "No display data available for PDF generation"
            self.showError = true
            return
        }

        Task { @MainActor in
            self.isGeneratingPDF = true
            self.pdfGenerationProgress = 0.0

            do {
                print("🔧 TradeStatementViewModel: Starting PDF generation for Trade #\(self.trade.tradeNumber)")

                // Simulate progress updates
                for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                    self.pdfGenerationProgress = progress
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }

                let pdfData = try await pdfService.generatePDF(for: displayData, trade: self.trade)
                print("🔧 TradeStatementViewModel: PDF generated successfully, size: \(pdfData.count) bytes")

                // Save PDF to Documents folder for sharing
                let fileName = "Collection_Bill_Trade_\(String(format: "%03d", trade.tradeNumber))_\(Date().timeIntervalSince1970)"
                let fileURL = try await pdfService.savePDFToDocuments(pdfData, fileName: fileName)

                self.isGeneratingPDF = false
                self.pdfGenerationProgress = 1.0

                print("📁 Collection Bill PDF saved to Documents folder: \(fileURL.path)")

            } catch {
                print("❌ TradeStatementViewModel: PDF generation failed: \(error.localizedDescription)")
                self.isGeneratingPDF = false
                self.pdfGenerationProgress = 0.0
                let appError = error.toAppError()
                self.errorMessage = "PDF-Generierung fehlgeschlagen: \(appError.errorDescription ?? "An error occurred")"
                self.showError = true
            }
        }
    }

    /// Generates a PDF preview for the trade statement
    func generatePDFPreview() {
        guard let displayData = displayData else {
            self.errorMessage = "No display data available for PDF preview"
            self.showError = true
            return
        }

        Task { @MainActor in
            do {
                print("🔧 TradeStatementViewModel: Generating PDF preview for Trade #\(self.trade.tradeNumber)")
                let image = try await pdfService.generatePreview(for: displayData, trade: self.trade)

                self.pdfPreviewImage = image
                print("🔧 TradeStatementViewModel: PDF preview generated successfully")
            } catch {
                print("❌ TradeStatementViewModel: PDF preview generation failed: \(error.localizedDescription)")
                let appError = error.toAppError()
                self.errorMessage = "PDF-Vorschau fehlgeschlagen: \(appError.errorDescription ?? "An error occurred")"
                self.showError = true
            }
        }
    }

    /// Shares the generated PDF
    func sharePDF() {
        // This would integrate with the system share sheet
        print("🔧 TradeStatementViewModel: Sharing PDF for Trade #\(self.trade.tradeNumber)")
    }

    /// Downloads PDF via browser
    func downloadPDFViaBrowser() {
        // This would open the PDF in a browser for download
        print("🔧 TradeStatementViewModel: Downloading PDF via browser for Trade #\(self.trade.tradeNumber)")
    }

    /// Clears any error state
    func clearError() {
        self.showError = false
        self.errorMessage = nil
    }
}
