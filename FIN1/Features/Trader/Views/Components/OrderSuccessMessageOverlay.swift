import SwiftUI

// MARK: - Order Success Message Overlay
/// Displays a modern success message overlay after order completion (buy/sell)
struct OrderSuccessMessageOverlay: View {
    let trade: Trade
    let orderType: OrderType
    let onDismiss: () -> Void
    @Environment(\.themeManager) private var themeManager

    @State private var animateIcon = false
    @State private var animateContent = false

    enum OrderType {
        case buy
        case sell
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            // Modern Header with Gradient
            VStack(spacing: ResponsiveDesign.spacing(4)) {
                // Removed icon and glow effect for minimal design

                // Modern Title with Subtle Animation
                Text(orderType == .buy ? "Wertpapier gekauft" : "Wertpapier verkauft")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(24), weight: .regular))
                    .foregroundColor(Color(hex: "#f5f5f5"))
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 20)
            }
            .padding(.top, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.spacing(24))
            .padding(.bottom, ResponsiveDesign.spacing(8))
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppTheme.accentGreen.opacity(0.1),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Modern Trade Details Card
            VStack(spacing: ResponsiveDesign.spacing(10)) {
                // Trade Details with Modern Layout
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    // WKN/ISIN with Modern Badge
                    if let wkn = trade.wkn, !wkn.isEmpty {
                        ModernDetailRow(
                            icon: "doc.text",
                            label: "WKN",
                            value: wkn,
                            isHighlighted: true
                        )
                    }

                    // Key Metrics in Grid Layout
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: ResponsiveDesign.spacing(16)) {
                        // Quantity
                        let quantity = orderType == .buy ? trade.totalQuantity : (trade.sellOrders.last?.quantity ?? trade.sellOrder?.quantity ?? 0)
                        ModernMetricCard(
                            icon: "number.circle",
                            label: "Stück",
                            value: "\(Int(quantity))",
                            subtitle: "Stück"
                        )

                        // Price
                        let price = orderType == .buy ? trade.entryPrice : (trade.sellOrders.last?.price ?? trade.sellOrder?.price ?? 0)
                        ModernMetricCard(
                            icon: "eurosign.circle",
                            label: orderType == .buy ? "Brief-Kurs (Ask)" : "Geldkurs (Bid)",
                            value: price.formattedAsLocalizedCurrency(),
                            subtitle: "pro Stück"
                        )
                    }

                    // Total Amount - Prominent Display
                    let totalAmount = orderType == .buy ? trade.buyOrder.totalAmount : (trade.sellOrders.last?.totalAmount ?? trade.sellOrder?.totalAmount ?? 0)
                    VStack(spacing: ResponsiveDesign.spacing(8)) {
                        Text("Betrag gesamt")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text(totalAmount.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.titleFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentGreen)
                    }
                    .padding(.vertical, ResponsiveDesign.spacing(16))
                    .padding(.horizontal, ResponsiveDesign.spacing(24))
                    .background(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                            .fill(AppTheme.accentGreen.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                                    .stroke(AppTheme.accentGreen.opacity(0.3), lineWidth: 1)
                            )
                    )

                    // Show P&L for sell orders with Modern Design
                    if orderType == .sell, let pnl = trade.finalPnL {
                        VStack(spacing: ResponsiveDesign.spacing(8)) {
                            Text("Trade Gewinn/Verlust vor Steuer")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Text(pnl.formattedAsLocalizedCurrency())
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.bold)
                                .foregroundColor(pnl >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                        }
                        .padding(.vertical, ResponsiveDesign.spacing(16))
                        .padding(.horizontal, ResponsiveDesign.spacing(24))
                        .background(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                                .fill((pnl >= 0 ? AppTheme.accentGreen : AppTheme.accentRed).opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                                        .stroke((pnl >= 0 ? AppTheme.accentGreen : AppTheme.accentRed).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(24))

                // Modern Status Indicators
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    ModernStatusRow(
                        icon: "checkmark.circle.fill",
                        text: orderType == .buy ? "Position im Bestand" : "Position verkauft",
                        color: AppTheme.accentGreen
                    )
                    ModernStatusRow(
                        icon: "doc.text.fill",
                        text: "Rechnung bei Trades verfügbar",
                        italicText: "Trades",
                        color: AppTheme.accentLightBlue)
                    ModernStatusRow(
                        icon: "bell.fill",
                        text: "Benachrichtigung erfolgt",
                        color: AppTheme.accentOrange
                    )
                }
                .padding(.horizontal, ResponsiveDesign.spacing(24))

                // Modern Dismiss Button
                Button(action: onDismiss, label: {
                    Text("weiter")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(24), weight: .regular))
                        .foregroundColor(Color(hex: "#f5f5f5"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ResponsiveDesign.spacing(16))
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.accentGreen,
                                    AppTheme.accentGreen.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(ResponsiveDesign.spacing(16))
                        .shadow(color: AppTheme.accentGreen.opacity(0.3), radius: ResponsiveDesign.spacing(8), x: 0, y: ResponsiveDesign.spacing(4))
                })
                .accessibilityIdentifier("OrderSuccessDismissButton")
                .accessibilityLabel("Bestätigung schließen")
                .accessibilityHint("Schließt die Kaufbestätigung und kehrt zum Depot zurück")
                .padding(.horizontal, ResponsiveDesign.spacing(24))
                .padding(.bottom, ResponsiveDesign.spacing(32))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(24))
                .fill(AppTheme.screenBackground)
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: ResponsiveDesign.spacing(20),
                    x: 0,
                    y: ResponsiveDesign.spacing(10)
                )
        )
        .padding(ResponsiveDesign.spacing(24))
        .accessibilityIdentifier("OrderSuccessOverlay")
        .onAppear {
            // Start animations
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animateIcon = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Modern Detail Row
private struct ModernDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(20))

            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)

            Spacer()

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(isHighlighted ? AppTheme.accentGreen : AppTheme.fontColor)
        }
        .padding(.vertical, ResponsiveDesign.spacing(12))
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.sectionBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(isHighlighted ? AppTheme.accentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Metric Card
private struct ModernMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.2))
                .foregroundColor(AppTheme.accentLightBlue)

            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(subtitle)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.tertiaryText)
        }
        .padding(.vertical, ResponsiveDesign.spacing(16))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                .fill(AppTheme.sectionBackground.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                        .stroke(AppTheme.accentLightBlue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Status Row
private struct ModernStatusRow: View {
    let icon: String
    let text: String
    let italicText: String?
    let color: Color

    init(icon: String, text: String, italicText: String? = nil, color: Color) {
        self.icon = icon
        self.text = text
        self.italicText = italicText
        self.color = color
    }

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                .foregroundColor(color)
                .frame(width: ResponsiveDesign.spacing(20))

            if let italicText = italicText {
                // Create formatted text with italic styling
                let parts = text.components(separatedBy: italicText)
                if parts.count == 2 {
                    HStack(spacing: ResponsiveDesign.spacing(0)) {
                        Text(parts[0])
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)

                        Text(italicText)
                            .font(ResponsiveDesign.bodyFont())
                            .italic()
                            .foregroundColor(AppTheme.secondaryText)

                        Text(parts[1])
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                } else {
                    Text(text)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
            } else {
                Text(text)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AppTheme.screenBackground.ignoresSafeArea()

        OrderSuccessMessageOverlay(
            trade: Trade(
                id: "test-trade",
                tradeNumber: 1,
                traderId: "test-trader",
                symbol: "AAPL",
                description: "Apple Inc.",
                buyOrder: OrderBuy(
                    id: "test-buy",
                    traderId: "test-trader",
                    symbol: "AAPL",
                    description: "Apple Inc.",
                    quantity: 100,
                    price: 150.0,
                    totalAmount: 15000.0,
                    status: .completed,
                    createdAt: Date(),
                    executedAt: Date(),
                    confirmedAt: Date(),
                    updatedAt: Date(),
                    optionDirection: "Call",
                    underlyingAsset: "Apple Inc.",
                    wkn: "AAPL123",
                    category: "Optionsschein",
                    strike: 150.0,
                    orderInstruction: "Market",
                    limitPrice: nil
                ),
                sellOrder: nil,
                sellOrders: [],
                status: .active,
                createdAt: Date(),
                completedAt: nil,
                updatedAt: Date()
            ),
            orderType: .buy,
            onDismiss: {}
        )
    }
}
