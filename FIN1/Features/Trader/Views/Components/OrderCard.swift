import SwiftUI

// MARK: - Order Card
struct OrderCard: View {
    let order: Order
    let position: Int
    @State private var showStatusInfo = false
    @State private var showOrderInstructionInfo = false
    @State private var showInvoiceSheet = false
    @State private var buyInvoice: Invoice?
    @Environment(\.appServices) private var services
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        CardContainer(
            position: self.position,
            showInvoiceIcon: self.isCompletedBuyOrder,
            onPapersheetTapped: {
                self.openIssuerProductInfo(for: self.order)
            },
            onInvoiceTapped: {
                self.loadAndShowBuyInvoice()
            },
            content: {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    // 8 Tiles in 4 Rows using TileGrid
                    TileGrid(tiles: self.orderTiles, columns: 2)

                    // STORNO button (full width)
                    Button(action: {
                        if self.statusValue < 3 {
                            Task {
                                try? await self.services.traderService.cancelOrder(self.order.id)
                            }
                        }
                    }, label: {
                        HStack {
                            Text("\(self.order.type.displayName.uppercased())")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.thin)
                                .foregroundColor(AppTheme.fontColor.opacity(self.statusValue < 3 ? 0.75 : 0.2))

                            Spacer()

                            Text("STORNO")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.regular)
                                .foregroundColor(AppTheme.fontColor.opacity(self.statusValue < 3 ? 0.85 : 0.2))
                        }
                        .padding(ResponsiveDesign.spacing(8))
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .background(self.statusValue < 3 ? AppTheme.accentRed.opacity(0.6) : AppTheme.accentRed.opacity(0.2))
                        .cornerRadius(ResponsiveDesign.spacing(4))
                    })
                    .buttonStyle(PlainButtonStyle())
                    .disabled(self.statusValue >= 3)
                }
            }
        )
        .alert("Order Status Info", isPresented: self.$showStatusInfo) {
            Button("OK") { }
        } message: {
            Text(self.statusInfoMessage)
        }
        .alert("Orderzusatz Info", isPresented: self.$showOrderInstructionInfo) {
            Button("OK") { }
        } message: {
            Text(self.orderInstructionInfoMessage)
        }
        .sheet(isPresented: self.$showInvoiceSheet) {
            if let invoice = buyInvoice {
                NavigationStack {
                    InvoiceDetailView(
                        invoice: invoice,
                        invoiceService: self.services.invoiceService,
                        notificationService: self.services.notificationService
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Determines if this is a completed buy order that should show the invoice icon
    private var isCompletedBuyOrder: Bool {
        // Show invoice icon for buy orders that are completed (status 5)
        return self.order.type == .buy && self.statusValue >= 5
    }

    // MARK: - Private Methods

    /// Loads the buy invoice for this order and shows the sheet
    private func loadAndShowBuyInvoice() {
        print("🔧 DEBUG: Loading buy invoice for order ID: \(self.order.id)")

        // Find the buy invoice for this order
        let invoices = self.services.invoiceService.getInvoices(for: "current_trader")
        let buyInvoice = invoices.first { invoice in
            invoice.orderId == self.order.id && invoice.transactionType == .buy
        }

        if let invoice = buyInvoice {
            print("🔧 DEBUG: Found buy invoice: \(invoice.formattedInvoiceNumber)")
            self.buyInvoice = invoice
            self.showInvoiceSheet = true
        } else {
            print("❌ DEBUG: No buy invoice found for order ID: \(self.order.id)")
            // Could show an alert here if needed
        }
    }

    private var orderTiles: [TileData] {
        [
            // Row 1: Orderart and WKN
            TileData(title: "Orderart", value: self.order.type.displayName.uppercased()),
            TileData(title: "WKN", value: self.order.wkn ?? self.order.symbol),

            // Row 2: Basiswert and Richtung
            TileData(title: "Basiswert", value: self.order.underlyingAsset ?? "N/A"),
            TileData(title: "Richtung", value: self.order.optionDirection ?? "N/A"),

            // Row 3: Strike Price and Quantity
            TileData(title: "Strike Price", value: self.formatStrikePrice(self.order.strike, self.order.underlyingAsset)),
            TileData(title: "Stückzahl", value: self.order.quantity.formattedAsLocalizedNumber()),

            // Row 4: Purchase Price/Current Price and Orderzusatz
            TileData(
                title: self.order.type == .sell ? "Geld-Kurs (Bid)" : "Brief-Kurs (Ask)",
                value: self.order.price.formattedAsLocalizedCurrency()
            ),
            TileData(
                title: "Orderzusatz",
                value: self.getOrderInstruction(),
                showInfoIcon: true,
                onInfoTapped: { self.showOrderInstructionInfo = true }
            ),

            // Row 5: Order-Status (centered)
            TileData(
                title: "Status",
                value: "\(self.statusValue)",
                showInfoIcon: true,
                onInfoTapped: { self.showStatusInfo = true }
            )
        ]
    }

    private var titleText: String {
        let orderType = self.order.type.displayName.uppercased()

        // For Optionsscheine: "BUY/SELL - Basiswert - Richtung"
        if let optionDirection = order.optionDirection, let underlyingAsset = order.underlyingAsset {
            return "\(orderType) - \(underlyingAsset) - \(optionDirection)"
        }

        // For regular stocks: "BUY/SELL - Symbol"
        return "\(orderType) - \(self.order.symbol)"
    }

    // Helper function to open issuer product info
    private func openIssuerProductInfo(for order: Order) {
        // Open issuer product info - similar to search results
        if let url = URL(string: "https://www.sg-zertifikate.de/produktfinder") {
            UIApplication.shared.open(url)
        }
    }

    private var statusValue: Int {
        switch self.order.status {
        case "submitted":
            return 1
        case "suspended":
            return 2
        case "executed":
            return 3
        case "confirmed":
            return 4
        case "completed":
            return 5
        case "cancelled":
            return 0
        default:
            return 0
        }
    }

    private var statusInfoMessage: String {
        switch self.order.status {
        case "submitted":
            return "Status 1: übermittelt\nIhre Order wurde erfolgreich übermittelt und wird bearbeitet."
        case "suspended":
            return "Status 2: Handel ausgesetzt\nDer Handel wurde vorübergehend ausgesetzt."
        case "executed":
            return "Status 3: ausgeführt\nIhre Order wurde erfolgreich ausgeführt."
        case "confirmed":
            return "Status 4: bestätigt\nIhre Order wurde bestätigt und wird abgeschlossen."
        case "completed":
            return "Status 5: abgeschlossen\nIhre Order ist abgeschlossen. Die Position wird in den Bestand übertragen."
        case "cancelled":
            return "Status 0: storniert\nIhre Order wurde storniert."
        default:
            return "Unbekannter Status"
        }
    }

    private var orderInstructionInfoMessage: String {
        return """
        Orderzusatz erklärt:
        
        • Market: Die Order wird zum bestmöglichen Preis ausgeführt, der am Markt verfügbar ist.
        
        • limit: Die Order wird nur zu einem bestimmten Preis oder besser ausgeführt. Der angegebene Preis ist der maximale Preis, den Sie zu zahlen bereit sind.
        """
    }

    private var orderStatusColor: Color {
        switch self.order.status {
        case "submitted":
            return AppTheme.accentOrange
        case "suspended":
            return AppTheme.accentOrange
        case "executed":
            return AppTheme.accentLightBlue
        case "confirmed":
            return AppTheme.accentLightBlue
        case "completed":
            return AppTheme.accentGreen
        case "cancelled":
            return AppTheme.accentRed
        default:
            return .gray
        }
    }

    private func getOrderInstruction() -> String {
        if let orderInstruction = order.orderInstruction {
            let normalized = orderInstruction.lowercased()
            if normalized == "limit" {
                if let limitPrice = order.limitPrice {
                    return "Limit \(limitPrice.formattedAsLocalizedCurrency())"
                } else {
                    return "Limit"
                }
            } else if normalized == "market" {
                return "Market"
            } else {
                return orderInstruction
            }
        }
        return "Market"
    }

    // Helper function to format Strike Price based on asset type
    private func formatStrikePrice(_ strike: Double?, _ underlyingAsset: String?) -> String {
        return DepotUtils.formatStrikePrice(strike ?? 0.0, underlyingAsset)
    }
}
