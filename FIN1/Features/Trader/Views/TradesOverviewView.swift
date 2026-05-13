import Combine
import SwiftUI

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
                VStack(
                    alignment: .leading,
                    spacing: self.viewModel.filteredOngoingTrades.isEmpty ? ResponsiveDesign.spacing(2) : ResponsiveDesign.spacing(16)
                ) {
                    // Ongoing Trades Section (at the top)
                    OngoingTradesSection(ongoingTrades: self.viewModel.filteredOngoingTrades)

                    // Horizontal separator line below ongoing section
                    Divider()
                        .background(AppTheme.secondaryText)
                        .padding(.vertical, ResponsiveDesign.spacing(8))

                    // Divider between sections (legacy - keeping for backward compatibility)
                    if !self.viewModel.filteredOngoingTrades.isEmpty && !self.viewModel.filteredCompletedTrades.isEmpty {
                        Divider()
                            .background(Color.white.opacity(0.5))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                    }

                    // Completed Trades Section (with header inside)
                    CompletedTradesSection(
                        completedTrades: self.viewModel.filteredCompletedTrades,
                        tableRows: self.viewModel.createTableRows(from: self.viewModel.filteredCompletedTrades),
                        columnWidths: self.viewModel.columnWidths,
                        commissionPercentage: self.viewModel.commissionPercentage,
                        selectedTimePeriod: self.$selectedTimePeriod,
                        showCustomizeDetails: self.$showCustomizeDetails,
                        onTimePeriodChanged: { period in
                            Task {
                                await self.viewModel.filterTrades(by: period)
                            }
                        }
                    )
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(
                    .top,
                    self.viewModel.filteredOngoingTrades.isEmpty ? ResponsiveDesign.spacing(2) : ResponsiveDesign.verticalPadding()
                )
                .padding(.bottom, ResponsiveDesign.verticalPadding())
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Überblick Trades-Profit")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: self.$showCustomizeDetails) {
                Text("Customize Details")
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
            }
            .navigationDestination(isPresented: self.$viewModel.showDepot) {
                TraderDepotView()
            }
            .navigationDestination(isPresented: self.$viewModel.showTradeDetails) {
                if let trade = viewModel.selectedTrade {
                    TradeDetailsViewWrapper(trade: trade)
                }
            }
            .overlay {
                if self.viewModel.isCalculatingCommission {
                    ProgressView("Provision wird berechnet...")
                        .padding()
                        .background(AppTheme.sectionBackground.opacity(0.9))
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") {
                    self.viewModel.clearError()
                }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten.")
            }
        }
        .dismissKeyboardOnTap()
        .onAppear {
            self.viewModel.attach(
                orderService: self.services.orderManagementService,
                tradeService: self.services.tradeLifecycleService,
                statisticsService: self.services.tradingStatisticsService,
                invoiceService: self.services.invoiceService,
                configurationService: self.services.configurationService,
                poolTradeParticipationService: self.services.poolTradeParticipationService,
                commissionCalculationService: self.services.commissionCalculationService,
                investorGrossProfitService: self.services.investorGrossProfitService,
                userService: self.services.userService,
                parseLiveQueryClient: self.services.parseLiveQueryClient
            )
        }
    }
}

// MARK: - Preview

#Preview {
    TradesOverviewView()
}
