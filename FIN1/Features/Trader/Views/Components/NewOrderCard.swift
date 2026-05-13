import SwiftUI

// MARK: - Simplified Order Card
struct NewOrderCard: View {
    let order: NewOrder
    let position: Int
    @State private var showStatusInfo = false
    @State private var showOrderInstructionInfo = false
    @Environment(\.appServices) private var services

    var body: some View {
        CardContainer(
            position: self.position,
            onPapersheetTapped: {
                self.openIssuerProductInfo(for: self.order)
            }
        ) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Order tiles with Strike Price included
                TileGrid(tiles: self.orderTiles, columns: 2)

                // STORNO button (full width)
                Button(action: {
                    if self.order.statusCode < 3 {
                        Task {
                            try? await self.services.unifiedOrderService.cancelOrder(self.order.id)
                        }
                    }
                }, label: {
                    HStack {
                        Text("\(self.order.type.displayName.uppercased())")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.thin)
                            .foregroundColor(AppTheme.fontColor.opacity(self.order.statusCode < 3 ? 0.75 : 0.2))

                        Spacer()

                        Text("STORNO")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.regular)
                            .foregroundColor(AppTheme.fontColor.opacity(self.order.statusCode < 3 ? 0.85 : 0.2))
                    }
                    .padding(ResponsiveDesign.spacing(8))
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .background(self.order.statusCode < 3 ? AppTheme.accentRed.opacity(0.6) : AppTheme.accentRed.opacity(0.2))
                    .cornerRadius(ResponsiveDesign.spacing(4))
                })
                .buttonStyle(PlainButtonStyle())
                .disabled(self.order.statusCode >= 3)
            }
        }
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
                title: self.order.type == .sell ? "Geld-Kurs (Bid)" : "Kauf-Kurs",
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
                value: "\(self.order.statusCode)",
                showInfoIcon: true,
                onInfoTapped: { self.showStatusInfo = true }
            )
        ]
    }

    // MARK: - Helper Methods
    private func openIssuerProductInfo(for order: NewOrder) {
        if let url = URL(string: "https://www.sg-zertifikate.de/produktfinder") {
            UIApplication.shared.open(url)
        }
    }

    private func formatStrikePrice(_ strike: Double?, _ underlyingAsset: String?) -> String {
        return DepotUtils.formatStrikePrice(strike ?? 0.0, underlyingAsset)
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

    private var statusInfoMessage: String {
        switch self.order.status {
        case .submitted:
            return "Status 1: übermittelt\nIhre Order wurde erfolgreich übermittelt und wird bearbeitet."
        case .suspended:
            return "Status 2: Handel ausgesetzt\nDer Handel wurde vorübergehend ausgesetzt."
        case .executed:
            return "Status 3: ausgeführt\nIhre Order wurde erfolgreich ausgeführt."
        case .confirmed:
            return "Status 4: bestätigt\nIhre Order wurde bestätigt und wird abgeschlossen."
        case .completed:
            return "Status 5: abgeschlossen\nIhre Order ist abgeschlossen. Die Position wird in den Bestand übertragen."
        case .cancelled:
            return "Status 0: storniert\nIhre Order wurde storniert."
        }
    }

    private var orderInstructionInfoMessage: String {
        return """
        Orderzusatz erklärt:
        
        • Market: Die Order wird zum bestmöglichen Preis ausgeführt, der am Markt verfügbar ist.
        
        • limit: Die Order wird nur zu einem bestimmten Preis oder besser ausgeführt. Der angegebene Preis ist der maximale Preis, den Sie zu zahlen bereit sind.
        """
    }
}
