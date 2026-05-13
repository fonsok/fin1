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
        BuyOrderView(viewModel: self.viewModel)
    }
}

// MARK: - Buy Order View

struct BuyOrderView: View {
    @StateObject var viewModel: BuyOrderViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabRouter: TabRouter
    @State private var isShowingConfirmation = false
    @Environment(\.themeManager) private var themeManager
    @Environment(\.appServices) private var services
    @State private var legalNoticeText: String = ""
    @State private var transactionLimitWarningTitle: String = "Transaktionslimit erreicht"
    @State private var transactionLimitIntroText: String?

    private var defaultLegalNoticeText: String {
        "Mit dem Klicken auf 'Kaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(6)) {
                    self.securitiesDetailsSection

                    self.orderDetailsSection

                    self.costEstimateSection

                    self.insufficientFundsWarningSection

                    self.transactionLimitWarningSection

                    self.orderActionButton

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                        Text("Rechtliche Hinweise")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.secondaryText)
                        Text(self.legalNoticeText.isEmpty ? self.defaultLegalNoticeText : self.legalNoticeText)
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
                        self.dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Refresh investments when view appears
            print("🔍 BuyOrderView: onAppear - refreshing investments")
            self.viewModel.refreshInvestments()

            // Also refresh after a short delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔍 BuyOrderView: Delayed refresh")
                self.viewModel.refreshInvestments()
            }
        }
        .onChange(of: self.viewModel.shouldShowDepotView) { _, newValue in
            if newValue {
                // Navigate directly to Depot; overlay will be shown in Depot view
                self.viewModel.shouldShowDepotView = false
                self.tabRouter.selectedTab = 1

                // Post notification to dismiss the entire navigation stack
                NotificationCenter.default.post(name: .orderPlacedSuccessfully, object: nil)

                self.dismiss()
            }
        }
        .onChange(of: self.viewModel.orderMode) { _, newValue in
            // Stop monitoring if switching away from limit order
            if newValue != .limit {
                self.viewModel.stopLimitOrderMonitoring()
            }
        }
        .onChange(of: self.viewModel.limit) { _, _ in
            // Handle limit price changes
            self.viewModel.onLimitPriceChanged()
        }
        .dismissKeyboardOnTap()
        .task {
            let provider = LegalSnippetProvider(termsContentService: services.termsContentService)
            let language: TermsOfServiceDataProvider.Language = .german
            let text = await provider.text(
                for: .orderLegalWarningBuy,
                language: language,
                documentType: .terms,
                defaultText: self.defaultLegalNoticeText,
                placeholders: [:]
            )
            self.legalNoticeText = text
        }
        .onChange(of: self.viewModel.showLimitWarning) { _, newValue in
            guard newValue else { return }
            Task {
                let provider = LegalSnippetProvider(termsContentService: services.termsContentService)
                let language: TermsOfServiceDataProvider.Language = .german
                // Ermittele Tages-, Wochen- und Monatslimit aus den Verletzungen (falls vorhanden)
                let (dailyLimitText, weeklyLimitText, monthlyLimitText): (String?, String?, String?) = {
                    guard let result = viewModel.transactionLimitCheckResult else { return (nil, nil, nil) }
                    var dailyText: String?
                    var weeklyText: String?
                    var monthlyText: String?
                    for violation in result.violations {
                        switch violation {
                        case let .dailyLimitExceeded(limit, _, _, _):
                            if dailyText == nil {
                                dailyText = limit.formattedAsLocalizedCurrency()
                            }
                        case let .weeklyLimitExceeded(limit, _, _, _):
                            if weeklyText == nil {
                                weeklyText = limit.formattedAsLocalizedCurrency()
                            }
                        case let .monthlyLimitExceeded(limit, _, _, _):
                            if monthlyText == nil {
                                monthlyText = limit.formattedAsLocalizedCurrency()
                            }
                        }
                    }
                    return (dailyText, weeklyText, monthlyText)
                }()
                var placeholders: [String: String] = [:]
                if let daily = dailyLimitText {
                    placeholders["DAILY_LIMIT"] = daily
                }
                if let weekly = weeklyLimitText {
                    placeholders["WEEKLY_LIMIT"] = weekly
                }
                if let monthly = monthlyLimitText {
                    placeholders["MONTHLY_LIMIT"] = monthly
                }
                let snippet = await provider.snippet(
                    for: .transactionLimitWarningBuy,
                    language: language,
                    documentType: .terms,
                    defaultTitle: "Transaktionslimit erreicht",
                    defaultContent: "Ihr (tägliches) Transaktionslimit wurde erreicht oder überschritten.",
                    placeholders: placeholders
                )
                self.transactionLimitWarningTitle = snippet.title
                self.transactionLimitIntroText = snippet.content
            }
        }
    }

    // MARK: - Computed Properties for View Sections

    private var securitiesDetailsSection: some View {
        SecuritiesDetailsSection(
            direction: self.viewModel.searchResult.category == "Optionsschein" ? self.viewModel.searchResult.direction : nil,
            basiswert: self.viewModel.searchResult.category == "Optionsschein" ? self.viewModel.searchResult.underlyingAsset : nil,
            strike: formatStrikePrice(self.viewModel.searchResult.strike, self.viewModel.searchResult.underlyingAsset),
            valuationDate: self.viewModel.searchResult.valuationDate,
            wkn: self.viewModel.searchResult.wkn,
            currentPrice: self.viewModel.formattedAskPrice,
            priceLabel: "Brief-Kurs (Ask)",
            priceValidityProgress: self.viewModel.priceValidityProgress,
            onReloadPrice: {
                self.viewModel.reloadPrice()
            },
            isLimitOrder: self.viewModel.orderMode == .limit,
            limitPrice: self.viewModel.limitPrice,
            currentPriceValue: self.viewModel.currentPriceValue,
            isMonitoringLimitOrder: self.viewModel.isMonitoringLimitOrder,
            orderType: "buy"
        )
    }

    private var orderDetailsSection: some View {
        OrderDetailsSection {
            QuantityInputField(
                text: self.$viewModel.quantityText,
                placeholder: "Stück",
                accessibilityLabel: "Number of shares",
                accessibilityHint: "Enter the number of shares you want to buy",
                maxValueWarning: self.viewModel.showMaxValueWarning ?
                    QuantityInputField.MaxValueWarning(
                        enteredValue: Int(self.viewModel.quantity),
                        maxValue: 10_000_000
                    ) : nil,
                errorMessage: self.viewModel.quantityConstraintMessage
            )

            OrderTypeSelection(
                selectedOrderMode: self.$viewModel.orderMode,
                onOrderModeChanged: { newOrderMode in
                    self.viewModel.orderMode = newOrderMode
                }
            )

            LimitPriceInput(
                limitText: self.$viewModel.limit,
                isVisible: self.viewModel.orderMode == .limit,
                onChange: { newValue in
                    print("🔍 DEBUG: Limit field changed to: '\(newValue)'")
                    // Validation is now handled internally by LimitPriceInput
                    // No need for additional filtering here
                },
                validationMessage: self.getValidationMessage(),
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
            Text(self.viewModel.estimatedCost.formattedAsLocalizedCurrency())
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
        if self.viewModel.showInsufficientFundsWarning {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    Text("!")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.red)
                }

                Text(self.viewModel.insufficientFundsMessage)
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

    // MARK: - Transaction Limit Warning (MiFID II Compliance)

    @ViewBuilder
    private var transactionLimitWarningSection: some View {
        if self.viewModel.showLimitWarning {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.orange)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    Text(self.transactionLimitWarningTitle)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.orange)
                }

                if let intro = transactionLimitIntroText {
                    Text(intro)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.leading)
                }

                if let message = viewModel.limitWarningMessage {
                    Text(message)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
        } else if let remainingLimit = viewModel.remainingDailyLimit {
            // Show remaining limit info when approaching limit (< 50% remaining)
            let dailyLimit = (viewModel.transactionLimitCheckResult?.remainingDaily ?? 0) + self.viewModel.estimatedCost
            let usagePercent = dailyLimit > 0 ? (1.0 - remainingLimit / dailyLimit) : 0

            if usagePercent > 0.5 {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    Text("Verbleibendes Tageslimit: \(remainingLimit.formattedAsLocalizedCurrency())")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.horizontal)
            }
        }
    }

    private var orderActionButton: some View {
        OrderActionButton(
            title: "(Gebührenpflichtig) Kaufen",
            backgroundColor: AppTheme.buttonColor,
            isEnabled: self.viewModel.canPlaceOrder && !self.viewModel.showLimitWarning,
            action: {
                print("🔘 DEBUG: Buy button tapped in form section")
                Task {
                    await self.viewModel.placeOrder()
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
            Text(
                "Mit dem Klicken auf 'Kaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig."
            )
            .font(ResponsiveDesign.captionFont())
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    private func getValidationMessage() -> String? {
        if self.viewModel.orderMode == .limit {
            if self.viewModel.limit.isEmpty {
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
