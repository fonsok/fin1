import SwiftUI

// MARK: - Buy Order View Wrapper

struct BuyOrderViewWrapper: View {
    let searchResult: SearchResult
    let traderService: any TraderServiceProtocol
    let cashBalanceService: any CashBalanceServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let userService: any UserServiceProtocol
    let traderDataService: (any TraderDataServiceProtocol)?
    @StateObject private var viewModel: BuyOrderViewModel

    init(
        searchResult: SearchResult,
        traderService: any TraderServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil
    ) {
        self.searchResult = searchResult
        self.traderService = traderService
        self.cashBalanceService = cashBalanceService
        self.configurationService = configurationService
        self.investmentQuantityCalculationService = investmentQuantityCalculationService
        self.investmentService = investmentService
        self.userService = userService
        self.traderDataService = traderDataService
        self._viewModel = StateObject(wrappedValue: BuyOrderViewModel(
            searchResult: searchResult,
            traderService: traderService,
            cashBalanceService: cashBalanceService,
            configurationService: configurationService,
            investmentQuantityCalculationService: investmentQuantityCalculationService,
            investmentService: investmentService,
            userService: userService,
            traderDataService: traderDataService,
            auditLoggingService: auditLoggingService,
            transactionLimitService: transactionLimitService
        ))
    }

    var body: some View {
        BuyOrderView(viewModel: viewModel)
    }
}

// MARK: - Buy Order View

struct BuyOrderView: View {
    @StateObject var viewModel: BuyOrderViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabRouter: TabRouter
    @State private var isShowingConfirmation = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(6)) {
                    securitiesDetailsSection

                    orderDetailsSection

                    costEstimateSection

                    insufficientFundsWarningSection

                    orderActionButton

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text("Rechtliche Hinweise")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.secondaryText)
                    Text("Mit dem Klicken auf 'Kaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtlich.")
                        .font(ResponsiveDesign.captionFont())
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Kauf-Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Refresh investments when view appears
            print("🔍 BuyOrderView: onAppear - refreshing investments")
            viewModel.refreshInvestments()

            // Also refresh after a short delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔍 BuyOrderView: Delayed refresh")
                viewModel.refreshInvestments()
            }
        }
        .onChange(of: viewModel.shouldShowDepotView) { _, newValue in
            if newValue {
                // Navigate directly to Depot; overlay will be shown in Depot view
                viewModel.shouldShowDepotView = false
                tabRouter.selectedTab = 1

                // Post notification to dismiss the entire navigation stack
                NotificationCenter.default.post(name: .orderPlacedSuccessfully, object: nil)

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

    // MARK: - Computed Properties for View Sections

    private var securitiesDetailsSection: some View {
        SecuritiesDetailsSection(
            direction: viewModel.searchResult.category == "Optionsschein" ? viewModel.searchResult.direction : nil,
            basiswert: viewModel.searchResult.category == "Optionsschein" ? viewModel.searchResult.underlyingAsset : nil,
            strike: formatStrikePrice(viewModel.searchResult.strike, viewModel.searchResult.underlyingAsset),
            valuationDate: viewModel.searchResult.valuationDate,
            wkn: viewModel.searchResult.wkn,
            currentPrice: viewModel.formattedAskPrice,
            priceLabel: "Brief-Kurs (Ask)",
            priceValidityProgress: viewModel.priceValidityProgress,
            onReloadPrice: {
                viewModel.reloadPrice()
            },
            isLimitOrder: viewModel.orderMode == .limit,
            limitPrice: viewModel.limitPrice,
            currentPriceValue: viewModel.currentPriceValue,
            isMonitoringLimitOrder: viewModel.isMonitoringLimitOrder,
            orderType: "buy"
        )
    }

    private var orderDetailsSection: some View {
        OrderDetailsSection {
            QuantityInputField(
                text: $viewModel.quantityText,
                placeholder: "Stück",
                accessibilityLabel: "Number of shares",
                accessibilityHint: "Enter the number of shares you want to buy",
                maxValueWarning: viewModel.showMaxValueWarning ?
                    QuantityInputField.MaxValueWarning(
                        enteredValue: Int(viewModel.quantity),
                        maxValue: 10_000_000
                    ) : nil,
                errorMessage: viewModel.quantityConstraintMessage
            )

            OrderTypeSelection(
                selectedOrderMode: $viewModel.orderMode,
                onOrderModeChanged: { newOrderMode in
                    viewModel.orderMode = newOrderMode
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

    private var costEstimateSection: some View {
        HStack {
            Text("Kosten (geschätzt)")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(viewModel.estimatedCost.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentOrange.opacity(0.8))
                .fontWeight(.medium)
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    @ViewBuilder
    private var insufficientFundsWarningSection: some View {
        if viewModel.showInsufficientFundsWarning {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: ResponsiveDesign.iconSize()))
                    Text("!")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.red)
                }

                Text(viewModel.insufficientFundsMessage)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }

    private var orderActionButton: some View {
        OrderActionButton(
            title: "(Gebührenpflichtig) Kaufen",
            backgroundColor: AppTheme.buttonColor,
            isEnabled: viewModel.canPlaceOrder && viewModel.orderMode == .market,
            action: {
                print("🔘 DEBUG: Buy button tapped in form section")
                Task {
                    await viewModel.placeOrder()
                }
            }
        )
        .accessibilityIdentifier("PlaceOrderButton")
        .accessibilityLabel("Buy order button")
        .accessibilityHint("Place a buy order for the selected number of shares")
    }

    private var legalNoticeSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Rechtliche Hinweise")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.secondaryText)
            Text("Mit dem Klicken auf 'Kaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig.")
                .font(ResponsiveDesign.captionFont())
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
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

    }

// MARK: - Helper Functions

private func formatStrikePrice(_ strike: String, _ underlyingAsset: String?) -> String {
    return DepotUtils.formatStrikePrice(strike, underlyingAsset)
}

#if DEBUG
struct BuyOrderView_Previews: PreviewProvider {
    static var previews: some View {
        // TODO: Fix preview with proper mock service
        // BuyOrderView(viewModel: BuyOrderViewModel(searchResult: mockSearchResults.first ?? SearchResult(valuationDate: "2023-01-01", wkn: "TEST123", strike: "100", askPrice: "1.0", direction: "Call", category: "Optionsschein", underlyingType: "Index", isin: "DE000TEST123"), traderService: MockTraderService()))
    }
}
#endif
