import SwiftUI

// MARK: - Custom View Modifiers
extension View {
    func tradeDetailsValueStyle() -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.light)
            .foregroundColor(AppTheme.inputFieldText)
    }

    func tradeDetailsLabelStyle() -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.bold)
            .foregroundColor(.secondary)
    }

    func tradeDetailsSectionHeaderStyle() -> some View {
        self
            .font(ResponsiveDesign.headlineFont())
            .fontWeight(.light)
            .foregroundColor(AppTheme.inputFieldText)
    }

    func tradeDetailsButtonTextStyle() -> some View {
        self
            .fontWeight(.light)
            .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96)) // #f5f5f5
    }

    func tradeDetailsDescriptionStyle() -> some View {
        self
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.light)
            .foregroundColor(.secondary)
    }

    func tradeDetailsColoredValueStyle(color: Color) -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.light)
            .foregroundColor(color)
    }

    func tradeDetailsColoredCaptionStyle(color: Color) -> some View {
        self
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.light)
            .foregroundColor(color)
    }
}

// MARK: - Helper Views
struct TradeDetailsRow: View {
    let label: String
    let value: String
    let valueColor: Color = AppTheme.inputFieldText

    var body: some View {
        HStack {
            Text(label).tradeDetailsLabelStyle()
            Spacer()
            Text(value).tradeDetailsValueStyle()
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
    }
}

struct TradeDetailsColoredRow: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(label).tradeDetailsLabelStyle()
            Spacer()
            Text(value).tradeDetailsColoredValueStyle(color: valueColor)
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
    }
}

struct TradeDetailsSection: View {
    let title: String
    let content: () -> AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(title).tradeDetailsSectionHeaderStyle()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ResponsiveDesign.spacing(16))
    }
}

struct TradeDetailsCard: View {
    let content: () -> AnyView

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            content()
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Trade Details View
struct TradeDetailsView: View {
    @Environment(\.appServices) private var services
    @ObservedObject var viewModel: TradeDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Text("Trade-Details")
                    .font(ResponsiveDesign.headlineFont()).bold()

                // Trade Summary Card
                TradeDetailsCard {
                    AnyView(
                        VStack(spacing: ResponsiveDesign.spacing(0)) {
                            HStack {
                                Text("Trade Nr.").tradeDetailsLabelStyle()
                                Spacer()
                                Text(viewModel.tradeNumberText)
                                    .font(ResponsiveDesign.bodyFont())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.fontColor)
                            }
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            Divider()

                            HStack(alignment: .firstTextBaseline) {
                                Text("Profit").tradeDetailsLabelStyle()
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(viewModel.gvCurrencyText)
                                        .tradeDetailsColoredValueStyle(color: viewModel.trade.profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                                    HStack(spacing: 4) {
                                        Text(viewModel.roiCalculationLabel)
                                            .tradeDetailsDescriptionStyle()
                                        Text(viewModel.gvPercentText)
                                            .tradeDetailsColoredCaptionStyle(color: viewModel.trade.profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                                    }
                                }
                            }
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                        }
                    )
                }

                // Detailed Calculation Table
                if let calculationBreakdown = viewModel.calculationBreakdown {
                    TradeCalculationTable(breakdown: calculationBreakdown)
                }

                // Transactions Section
                TradeDetailsSection(title: "Transaktionen") {
                    AnyView(
                        Text("Hier fügen wir alle relevanten Kauf- und Verkaufsposten hinzu (wie in den Rechnungen).")
                            .tradeDetailsDescriptionStyle()
                    )
                }

                // Invoices Section
                TradeDetailsSection(title: "Rechnungen") {
                    AnyView(
                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            // Buy Invoice Button
                            if viewModel.buyInvoice != nil {
                                Button(action: {
                                    viewModel.showBuyInvoice = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96)) // #f5f5f5
                                        Text("Rechnung Kauf")
                                            .tradeDetailsButtonTextStyle()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ResponsiveDesign.spacing(12))
                                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                                    .background(AppTheme.sectionBackground.opacity(0.8))
                                    .cornerRadius(ResponsiveDesign.spacing(8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            // Individual Sell Invoice Buttons
                            ForEach(Array(viewModel.sellInvoices.enumerated()), id: \.element.id) { index, sellInvoice in
                                Button(action: {
                                    viewModel.selectedSellInvoice = sellInvoice
                                    viewModel.showSellInvoice = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96)) // #f5f5f5
                                        Text(viewModel.sellInvoices.count == 1 ? "Rechnung Verkauf" : "Rechnung Verkauf \(index + 1)")
                                            .tradeDetailsButtonTextStyle()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ResponsiveDesign.spacing(12))
                                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                                    .background(AppTheme.sectionBackground.opacity(0.8))
                                    .cornerRadius(ResponsiveDesign.spacing(8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            // Collection Bill Button
                            Button(action: {
                                viewModel.showCollectionBill = true
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96)) // #f5f5f5
                                    Text("Collection Bill")
                                        .tradeDetailsButtonTextStyle()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ResponsiveDesign.spacing(12))
                                .padding(.horizontal, ResponsiveDesign.spacing(16))
                                .background(AppTheme.sectionBackground.opacity(0.8))
                                .cornerRadius(ResponsiveDesign.spacing(8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    )
                }
            }
            .padding(.horizontal, ResponsiveDesign.spacing(16))
        }
        .background(AppTheme.systemTertiaryBackground)
        .navigationTitle("Trade Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.attach(invoiceService: services.invoiceService, tradeService: services.tradeLifecycleService)
        }
        .sheet(isPresented: $viewModel.showCollectionBill) {
            TradeNavigationHelper.collectionBillSheet(for: viewModel.trade)
        }
        .sheet(isPresented: $viewModel.showBuyInvoice) {
            if let buyInvoice = viewModel.buyInvoice {
                TradeNavigationHelper.invoiceSheet(for: buyInvoice, appServices: services)
            }
        }
        .sheet(isPresented: $viewModel.showSellInvoice) {
            if let sellInvoice = viewModel.selectedSellInvoice {
                TradeNavigationHelper.invoiceSheet(for: sellInvoice, appServices: services)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TradeDetailsView(viewModel: TradeDetailsViewModel(trade: TradeOverviewItem(
            tradeId: "test-id",
            tradeNumber: 12345,
            startDate: Date(),
            endDate: Date(),
            profitLoss: 150.0,
            returnPercentage: 12.5,
            commission: 25.0,
            isActive: false,
            statusText: "Completed",
            statusDetail: "Successfully completed",
            onDetailsTapped: {},
            grossProfit: 175.0,
            totalFees: 25.0
        )))
    }
    .environment(\.appServices, AppServices.live)
}
