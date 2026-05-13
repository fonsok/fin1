import SwiftUI

// MARK: - Securities Details Section Component
/// Shared component for displaying securities details in order views
struct SecuritiesDetailsSection: View {
    let title: String
    let direction: String?
    let basiswert: String?
    let strike: String
    let valuationDate: String
    let wkn: String
    let currentPrice: String
    let priceLabel: String
    let priceValidityProgress: Double
    let onReloadPrice: () -> Void
    let additionalRows: [OrderInfoRowData]

    // Limit order support
    let isLimitOrder: Bool
    let limitPrice: Double?
    let currentPriceValue: Double
    let isMonitoringLimitOrder: Bool
    let orderType: String // "buy" or "sell"

    init(
        title: String = "Wertpapierdetails",
        direction: String? = nil,
        basiswert: String? = nil,
        strike: String,
        valuationDate: String,
        wkn: String,
        currentPrice: String,
        priceLabel: String,
        priceValidityProgress: Double,
        onReloadPrice: @escaping () -> Void,
        additionalRows: [OrderInfoRowData] = [],
        isLimitOrder: Bool = false,
        limitPrice: Double? = nil,
        currentPriceValue: Double = 0.0,
        isMonitoringLimitOrder: Bool = false,
        orderType: String = "buy"
    ) {
        self.title = title
        self.direction = direction
        self.basiswert = basiswert
        self.strike = strike
        self.valuationDate = valuationDate
        self.wkn = wkn
        self.currentPrice = currentPrice
        self.priceLabel = priceLabel
        self.priceValidityProgress = priceValidityProgress
        self.onReloadPrice = onReloadPrice
        self.additionalRows = additionalRows
        self.isLimitOrder = isLimitOrder
        self.limitPrice = limitPrice
        self.currentPriceValue = currentPriceValue
        self.isMonitoringLimitOrder = isMonitoringLimitOrder
        self.orderType = orderType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Show Richtung and Basiswert for Optionsscheine
            if let direction = direction, let basiswert = basiswert {
                OrderInfoRow(label: "Richtung", value: direction)
                OrderInfoRow(label: "Basiswert", value: basiswert)
            }

            // Common rows
            OrderInfoRow(label: "Strike Price", value: self.strike)
            OrderInfoRow(label: "Bewertungstag", value: self.valuationDate)
            OrderInfoRow(label: "WKN", value: self.wkn)

            // Additional rows (for sell order specific data)
            ForEach(self.additionalRows, id: \.label) { row in
                OrderInfoRow(label: row.label, value: row.value)
            }

            // Current price section
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                HStack {
                    Text(self.priceLabel)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    Spacer()
                    Text(self.currentPrice)
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))

                    // Show monitoring status or refresh button
                    if self.isLimitOrder && self.limitPrice != nil {
                        if self.isMonitoringLimitOrder {
                            HStack(spacing: ResponsiveDesign.spacing(4)) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text("Monitoring...")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Button(action: self.onReloadPrice, label: {
                                Image(systemName: "arrow.clockwise")
                            })
                            .accessibilityLabel("Reload current price")
                            .accessibilityHint("Tap to refresh the current market price")
                        }
                    } else {
                        Button(action: self.onReloadPrice, label: {
                            Image(systemName: "arrow.clockwise")
                        })
                        .accessibilityLabel("Reload current price")
                        .accessibilityHint("Tap to refresh the current market price")
                    }
                }
                .padding(.vertical, ResponsiveDesign.spacing(4))

                // Limit order info text
                if self.isLimitOrder && self.limitPrice != nil {
                    self.limitOrderInfoText
                }

                // Price validity indicator
                PriceValidityIndicator(priceValidityProgress: self.priceValidityProgress)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    // MARK: - Limit Order Logic

    private func shouldExecuteLimitOrder() -> Bool {
        guard let limitPrice = limitPrice else { return false }

        if self.orderType == "buy" {
            // For buy orders: execute when current price is below or equal to limit
            return self.currentPriceValue <= limitPrice
        } else {
            // For sell orders: execute when current price is above or equal to limit
            return self.currentPriceValue >= limitPrice
        }
    }

    private var limitOrderInfoText: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            if self.isMonitoringLimitOrder {
                let limitText = NumberFormatter.localizedDecimalFormatter.string(for: self.limitPrice ?? 0) ?? "0,00"
                if self.orderType == "buy" {
                    Text("🔄 Automatische Überwachung: Briefkurs ≤ \(limitText) €")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                } else {
                    Text("🔄 Automatische Überwachung: Geld-Kurs (Bid) ≥ \(limitText) €")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                }
            } else {
                let limitText = NumberFormatter.localizedDecimalFormatter.string(for: self.limitPrice ?? 0) ?? "0,00"
                if self.orderType == "buy" {
                    Text("⏳ Warten auf Briefkurs ≤ \(limitText) €")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                } else {
                    Text("⏳ Warten auf Geld-Kurs (Bid) ≥ \(limitText) €")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.spacing(4))
    }
}

// MARK: - Supporting Data Structure
struct OrderInfoRowData {
    let label: String
    let value: String
}

struct OrderInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            Spacer()

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(24)) {
        SecuritiesDetailsSection(
            direction: "Call",
            basiswert: "DAX",
            strike: "15.000,00 €",
            valuationDate: "31.12.2024",
            wkn: "123456",
            currentPrice: "1,25 €",
            priceLabel: "Briefkurs",
            priceValidityProgress: 0.8,
            onReloadPrice: {},
            isLimitOrder: true,
            limitPrice: 1.20,
            currentPriceValue: 1.15,
            isMonitoringLimitOrder: true,
            orderType: "buy"
        )

        SecuritiesDetailsSection(
            direction: "Call",
            basiswert: "DAX",
            strike: "15.000,00 €",
            valuationDate: "31.12.2024",
            wkn: "123456",
            currentPrice: "1,20 €",
            priceLabel: "Geld-Kurs (Bid)",
            priceValidityProgress: 0.6,
            onReloadPrice: {},
            additionalRows: [
                OrderInfoRowData(label: "Verfügbar", value: "1.000 Stück"),
                OrderInfoRowData(label: "Bereits verkauft", value: "200 Stück")
            ],
            isLimitOrder: true,
            limitPrice: 1.15,
            currentPriceValue: 1.20,
            isMonitoringLimitOrder: false,
            orderType: "sell"
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
