import SwiftUI

// MARK: - Trader Depot View
/// Main depot view displaying holdings, orders, and depot information
struct TraderDepotView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: TraderDepotViewModel
    @StateObject private var warrantDetailsViewModel: WarrantDetailsViewModel
    @State private var showTradeSuccess = false
    @State private var completedTrade: Trade?
    @State private var completedOrderType: OrderSuccessMessageOverlay.OrderType?
    @Environment(\.themeManager) private var themeManager

    init(services: AppServices? = nil) {
        let resolved = services ?? .live
        _viewModel = StateObject(wrappedValue: TraderDepotViewModel(
            traderService: resolved.traderService,
            documentService: resolved.documentService,
            testModeService: resolved.testModeService,
            userService: resolved.userService,
            parseLiveQueryClient: resolved.parseLiveQueryClient
        ))
        _warrantDetailsViewModel = StateObject(wrappedValue: WarrantDetailsViewModel())
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                        DepotHeaderView(
                            depotValue: self.viewModel.depotValue,
                            depotNumber: self.viewModel.depotNumber
                        )
                        .padding(.bottom, ResponsiveDesign.spacing(8))

                        OngoingOrdersSection(ongoingOrders: self.viewModel.ongoingOrders)

                        Divider().background(Color.white.opacity(0.5))
                            .padding(.vertical, ResponsiveDesign.spacing(8))

                        HoldingsSection(
                            holdings: self.viewModel.holdings,
                            ongoingOrders: self.viewModel.ongoingOrders,
                            warrantDetailsViewModel: self.warrantDetailsViewModel
                        )
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                }
                .background(AppTheme.screenBackground)
                .navigationTitle("Depot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Depot").foregroundColor(AppTheme.fontColor)
                    }
                }
            }
            .navigationViewStyle(.stack)
            .dismissKeyboardOnTap()
            .onReceive(NotificationCenter.default.publisher(for: .buyOrderCompleted)) { notification in
                if let trade = notification.object as? Trade {
                    self.completedTrade = trade
                    self.completedOrderType = .buy
                    self.showTradeSuccess = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sellOrderCompleted)) { notification in
                if let trade = notification.object as? Trade {
                    // Store the trade data first
                    self.completedTrade = trade
                    self.completedOrderType = .sell
                    // Delay showing the overlay to allow depot to fully update
                    // This ensures the sold position is removed before showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.showTradeSuccess = true
                    }
                }
            }

            // Success Message Overlay
            if self.showTradeSuccess, let trade = completedTrade, let orderType = completedOrderType {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        self.dismissSuccessMessage()
                    }

                OrderSuccessMessageOverlay(
                    trade: trade,
                    orderType: orderType,
                    onDismiss: {
                        self.dismissSuccessMessage()
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: self.showTradeSuccess)
        .onChange(of: self.showTradeSuccess) { _, isShowing in
            if isShowing {
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.dismissSuccessMessage()
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func dismissSuccessMessage() {
        self.showTradeSuccess = false
        // Delay clearing the trade to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.completedTrade = nil
            self.completedOrderType = nil
        }
    }
}

// MARK: - Ongoing Orders Section
/// Displays the ongoing orders section
private struct OngoingOrdersSection: View {
    let ongoingOrders: [Order]

    var body: some View {
        if self.ongoingOrders.isEmpty {
            Text("Keine laufenden Orders")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
        } else {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                Text("Laufende Orders")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentOrange)

                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(Array(self.ongoingOrders.enumerated()), id: \.offset) { index, order in
                        OrderCard(order: order, position: index + 1)
                    }
                }
            }
        }
    }
}

// MARK: - Holdings Section
/// Displays the holdings section
private struct HoldingsSection: View {
    let holdings: [DepotHolding]
    let ongoingOrders: [Order]
    let warrantDetailsViewModel: WarrantDetailsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Bestand")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            if self.holdings.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Image(systemName: "chart.pie")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))

                    Text("Kein Bestand")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text("Aktuell sind keine Positionen im Bestand")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, ResponsiveDesign.spacing(32))
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(self.holdings) { holding in
                        HoldingCard(
                            holding: holding,
                            ongoingOrders: self.ongoingOrders,
                            warrantDetailsViewModel: self.warrantDetailsViewModel
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    TraderDepotView()
}
