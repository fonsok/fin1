import SwiftUI

// MARK: - Sell Order View Wrapper

struct SellOrderViewWrapper: View {
    let holding: DepotHolding
    let traderService: any TraderServiceProtocol
    let userService: (any UserServiceProtocol)?
    @StateObject private var viewModel: SellOrderViewModel

    init(holding: DepotHolding, traderService: any TraderServiceProtocol, userService: (any UserServiceProtocol)? = nil) {
        self.holding = holding
        self.traderService = traderService
        self.userService = userService
        self._viewModel = StateObject(wrappedValue: SellOrderViewModel(holding: holding, traderService: traderService, userService: userService))
    }

    var body: some View {
        SellOrderView(viewModel: viewModel)
    }
}

// MARK: - Sell Order View

struct SellOrderView: View {
    @StateObject var viewModel: SellOrderViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabRouter: TabRouter
    @State private var isShowingConfirmation = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(24)) {
                    securitiesDetailsSection
                    orderDetailsSection
                    proceedsEstimateSection
                    orderActionButton

                    legalNoticeSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Verkauf-Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten")
        }
        .onChange(of: viewModel.shouldShowDepotView) { _, newValue in
            if newValue {
                // Navigate directly to Depot; overlay will be shown in Depot view
                viewModel.shouldShowDepotView = false
                tabRouter.selectedTab = 1
                dismiss()
            }
        }
        .onChange(of: viewModel.orderMode) { _, newValue in
            // Stop monitoring if switching away from limit order
            if newValue != .limit {
                viewModel.stopLimitOrderMonitoring()
            }
        }
        .onChange(of: viewModel.limit) { _, _ in
            // Handle limit price changes
            viewModel.onLimitPriceChanged()
        }
        .dismissKeyboardOnTap()
    }

    private func formatStrikePrice(_ strike: Double, _ underlyingAsset: String?) -> String {
        return DepotUtils.formatStrikePrice(strike, underlyingAsset)
    }

    private var securitiesDirection: String? {
        (viewModel.holding.direction == "Call" || viewModel.holding.direction == "Put") ? viewModel.holding.direction : nil
    }

    private var securitiesBasiswert: String? {
        (viewModel.holding.direction == "Call" || viewModel.holding.direction == "Put") ? viewModel.holding.underlyingAsset : nil
    }

    private var additionalSecuritiesRows: [OrderInfoRowData] {
        var rows: [OrderInfoRowData] = [
            OrderInfoRowData(label: "Verfügbar", value: "\(viewModel.formattedMaxQuantity) Stück")
        ]

        // Show partial sales info if applicable
        if viewModel.holding.isPartiallySold {
            rows.append(OrderInfoRowData(label: "Bereits verkauft", value: "\(viewModel.holding.soldQuantity.formattedAsLocalizedNumber()) Stück"))
            rows.append(OrderInfoRowData(label: "Original", value: "\(viewModel.holding.originalQuantity.formattedAsLocalizedNumber()) Stück"))
        }

        return rows
    }

    private func getValidationMessage() -> String? {
        if viewModel.orderMode == .limit {
            if viewModel.limit.isEmpty {
                return "⚠️ Bitte geben Sie einen Limitpreis ein"
            } else if let limitPrice = viewModel.limitPrice, limitPrice > 0 {
                return "✓ Limitpreis gesetzt: \(String(format: "%.2f", limitPrice).replacingOccurrences(of: ".", with: ","))"
            } else {
                return "⚠️ Ungültiges Format - nur Zahlen und ein Komma erlaubt (z.B. 1,23)"
            }
        }
        return nil
    }

    // MARK: - Computed Properties for View Sections

    private var securitiesDetailsSection: some View {
        SecuritiesDetailsSection(
            direction: securitiesDirection,
            basiswert: securitiesBasiswert,
            strike: formatStrikePrice(viewModel.holding.strike, viewModel.holding.underlyingAsset),
            valuationDate: viewModel.holding.valuationDate,
            wkn: viewModel.holding.wkn,
            currentPrice: viewModel.formattedCurrentPrice,
            priceLabel: "Geld-Kurs (Bid)",
            priceValidityProgress: viewModel.priceValidityProgress,
            onReloadPrice: {
                viewModel.reloadPrice()
            },
            additionalRows: additionalSecuritiesRows,
            isLimitOrder: viewModel.orderMode == .limit,
            limitPrice: viewModel.limitPrice,
            currentPriceValue: viewModel.currentPriceValue,
            isMonitoringLimitOrder: viewModel.isMonitoringLimitOrder,
            orderType: "sell"
        )
    }

    private var orderDetailsSection: some View {
        OrderDetailsSection {
            QuantityInputField(
                text: $viewModel.quantityText,
                placeholder: "max. \(viewModel.holding.remainingQuantity.formattedAsLocalizedNumber()) Stück",
                accessibilityLabel: "Number of shares to sell",
                accessibilityHint: "Enter the quantity of shares you want to sell",
                onSubmit: {
                    viewModel.validateAndCorrectQuantity()
                },
                errorMessage: viewModel.quantityErrorMessage
            )

            OrderTypeSelection(
                selectedOrderMode: $viewModel.orderMode,
                onOrderModeChanged: { newOrderMode in
                    viewModel.orderMode = newOrderMode
                    print("🔍 DEBUG: Order mode changed to: \(newOrderMode)")
                }
            )

            LimitPriceInput(
                limitText: $viewModel.limit,
                isVisible: viewModel.orderMode == .limit,
                onChange: { newValue in
                    print("🔍 DEBUG: Limit field changed to: '\(newValue)'")
                    // Validation is now handled internally by LimitPriceInput
                    // No need for additional filtering here
                },
                validationMessage: getValidationMessage(),
                placeholder: "Beispiel: 1,23"
            )
        }
    }

    private var proceedsEstimateSection: some View {
        HStack {
            Text("Erlös (geschätzt)")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(viewModel.estimatedProceeds.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentGreen.opacity(0.8))
                .fontWeight(.medium)
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    private var orderActionButton: some View {
        OrderActionButton(
            title: "(Gebührenpflichtig) Verkaufen",
            backgroundColor: AppTheme.buttonColor,
            isEnabled: viewModel.canPlaceOrder && viewModel.orderMode == .market,
            action: {
                print("🔘 DEBUG: Sell button tapped in form section")
                Task {
                    await viewModel.placeOrder()
                }
            }
        )
        .accessibilityLabel("Sell order button")
        .accessibilityHint("Place a sell order for the selected number of shares")
    }

    private var legalNoticeSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Rechtliche Hinweise")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.secondaryText)
            Text("Mit dem Klicken auf 'Verkaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.")
                .font(ResponsiveDesign.captionFont())
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Helper Views

#Preview {
    EmptyView()
}
