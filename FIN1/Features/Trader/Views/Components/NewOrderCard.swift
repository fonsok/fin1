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
            position: position,
            onPapersheetTapped: {
                openIssuerProductInfo(for: order)
            }
        ) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Order tiles with Strike Price included
                TileGrid(tiles: orderTiles, columns: 2)

                // STORNO button (full width)
                Button(action: {
                    if order.statusCode < 3 {
                        Task {
                            try? await services.unifiedOrderService.cancelOrder(order.id)
                        }
                    }
                }, label: {
                    HStack {
                        Text("\(order.type.displayName.uppercased())")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.thin)
                            .foregroundColor(AppTheme.fontColor.opacity(order.statusCode < 3 ? 0.75 : 0.2))

                        Spacer()

                        Text("STORNO")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.regular)
                            .foregroundColor(AppTheme.fontColor.opacity(order.statusCode < 3 ? 0.85 : 0.2))
                    }
                    .padding(ResponsiveDesign.spacing(8))
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .background(order.statusCode < 3 ? AppTheme.accentRed.opacity(0.6) : AppTheme.accentRed.opacity(0.2))
                    .cornerRadius(ResponsiveDesign.spacing(4))
                })
                .buttonStyle(PlainButtonStyle())
                .disabled(order.statusCode >= 3)
            }
        }
        .alert("Order Status Info", isPresented: $showStatusInfo) {
            Button("OK") { }
        } message: {
            Text(statusInfoMessage)
        }
        .alert("Orderzusatz Info", isPresented: $showOrderInstructionInfo) {
            Button("OK") { }
        } message: {
            Text(orderInstructionInfoMessage)
        }
    }

    private var orderTiles: [TileData] {
        [
            // Row 1: Orderart and WKN
            TileData(title: "Orderart", value: order.type.displayName.uppercased()),
            TileData(title: "WKN", value: order.wkn ?? order.symbol),

            // Row 2: Basiswert and Richtung
            TileData(title: "Basiswert", value: order.underlyingAsset ?? "N/A"),
            TileData(title: "Richtung", value: order.optionDirection ?? "N/A"),

            // Row 3: Strike Price and Quantity
            TileData(title: "Strike Price", value: formatStrikePrice(order.strike, order.underlyingAsset)),
            TileData(title: "Stückzahl", value: order.quantity.formattedAsLocalizedNumber()),

            // Row 4: Purchase Price/Current Price and Orderzusatz
            TileData(title: order.type == .sell ? "Geld-Kurs (Bid)" : "Kauf-Kurs", value: order.price.formattedAsLocalizedCurrency()),
            TileData(
                title: "Orderzusatz",
                value: getOrderInstruction(),
                showInfoIcon: true,
                onInfoTapped: { showOrderInstructionInfo = true }
            ),

            // Row 5: Order-Status (centered)
            TileData(
                title: "Status",
                value: "\(order.statusCode)",
                showInfoIcon: true,
                onInfoTapped: { showStatusInfo = true }
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
        switch order.status {
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
