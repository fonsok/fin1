import SwiftUI
import Combine

// MARK: - Trades Overview View

/// Displays a comprehensive overview of trades with P/L information
struct TradesOverviewView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: TradesOverviewViewModel
    @State private var selectedTimePeriod: TradeTimePeriod = .last30Days
    @State private var showCustomizeDetails = false
    @Environment(\.themeManager) private var themeManager

    init() {
        _viewModel = StateObject(wrappedValue: TradesOverviewViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: viewModel.filteredOngoingTrades.isEmpty ? ResponsiveDesign.spacing(2) : ResponsiveDesign.spacing(16)) {
                    // Ongoing Trades Section (at the top)
                    OngoingTradesSection(ongoingTrades: viewModel.filteredOngoingTrades)

                    // Horizontal separator line below ongoing section
                    Divider()
                        .background(AppTheme.secondaryText)
                        .padding(.vertical, ResponsiveDesign.spacing(8))

                    // Divider between sections (legacy - keeping for backward compatibility)
                    if !viewModel.filteredOngoingTrades.isEmpty && !viewModel.filteredCompletedTrades.isEmpty {
                        Divider()
                            .background(Color.white.opacity(0.5))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                    }

                    // Completed Trades Section (with header inside)
                    CompletedTradesSection(
                        completedTrades: viewModel.filteredCompletedTrades,
                        tableRows: viewModel.createTableRows(from: viewModel.filteredCompletedTrades),
                        columnWidths: viewModel.columnWidths,
                        commissionPercentage: viewModel.commissionPercentage,
                        selectedTimePeriod: $selectedTimePeriod,
                        showCustomizeDetails: $showCustomizeDetails,
                        onTimePeriodChanged: { period in
                            Task {
                                await viewModel.filterTrades(by: period)
                            }
                        }
                    )
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.top, viewModel.filteredOngoingTrades.isEmpty ? ResponsiveDesign.spacing(2) : ResponsiveDesign.verticalPadding())
                .padding(.bottom, ResponsiveDesign.verticalPadding())
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Überblick Trades-Profit")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCustomizeDetails) {
                Text("Customize Details")
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
            }
            .navigationDestination(isPresented: $viewModel.showDepot) {
                TraderDepotView()
            }
            .navigationDestination(isPresented: $viewModel.showTradeDetails) {
                if let trade = viewModel.selectedTrade {
                    TradeDetailsViewWrapper(trade: trade)
                }
            }
            .overlay {
                if viewModel.isCalculatingCommission {
                    ProgressView("Provision wird berechnet...")
                        .padding()
                        .background(AppTheme.sectionBackground.opacity(0.9))
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
            }
        }
        .dismissKeyboardOnTap()
        .onAppear {
            viewModel.attach(
                orderService: services.orderManagementService,
                tradeService: services.tradeLifecycleService,
                statisticsService: services.tradingStatisticsService,
                invoiceService: services.invoiceService,
                configurationService: services.configurationService,
                poolTradeParticipationService: services.poolTradeParticipationService,
                commissionCalculationService: services.commissionCalculationService,
                investorGrossProfitService: services.investorGrossProfitService,
                userService: services.userService,
                parseLiveQueryClient: services.parseLiveQueryClient
            )
        }
    }
}

// MARK: - Preview

#Preview {
    TradesOverviewView()
}
