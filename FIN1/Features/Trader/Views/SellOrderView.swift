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
        self._viewModel = StateObject(
            wrappedValue: SellOrderViewModel(holding: holding, traderService: traderService, userService: userService)
        )
    }

    var body: some View {
        SellOrderView(viewModel: self.viewModel)
    }
}

// MARK: - Sell Order View

struct SellOrderView: View {
    @StateObject var viewModel: SellOrderViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabRouter: TabRouter
    @State private var isShowingConfirmation = false
    @Environment(\.themeManager) private var themeManager
    @Environment(\.appServices) private var services
    @State private var legalNoticeText: String = ""

    private var defaultLegalNoticeText: String {
        "Mit dem Klicken auf 'Verkaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(24)) {
                    self.securitiesDetailsSection
                    self.orderDetailsSection
                    self.proceedsEstimateSection
                    self.orderActionButton

                    self.legalNoticeSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Verkauf-Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.dismiss()
                    }
                }
            }
        }
        .alert("Fehler", isPresented: self.$viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(self.viewModel.errorMessage ?? "Ein unbekannter Fehler ist aufgetreten")
        }
        .onChange(of: self.viewModel.shouldShowDepotView) { _, newValue in
            if newValue {
                // Navigate directly to Depot; overlay will be shown in Depot view
                self.viewModel.shouldShowDepotView = false
                self.tabRouter.selectedTab = 1
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
                for: .orderLegalWarningSell,
                language: language,
                documentType: .terms,
                defaultText: self.defaultLegalNoticeText,
                placeholders: [:]
            )
            self.legalNoticeText = text
        }
    }

    private func formatStrikePrice(_ strike: Double, _ underlyingAsset: String?) -> String {
        return DepotUtils.formatStrikePrice(strike, underlyingAsset)
    }

    private var securitiesDirection: String? {
        (self.viewModel.holding.direction == "Call" || self.viewModel.holding.direction == "Put") ? self.viewModel.holding.direction : nil
    }

    private var securitiesBasiswert: String? {
        (self.viewModel.holding.direction == "Call" || self.viewModel.holding.direction == "Put") ? self.viewModel.holding.underlyingAsset : nil
    }

    private var additionalSecuritiesRows: [OrderInfoRowData] {
        var rows: [OrderInfoRowData] = [
            OrderInfoRowData(label: "Verfügbar", value: "\(viewModel.formattedMaxQuantity) Stück")
        ]

        // Show partial sales info if applicable
        if self.viewModel.holding.isPartiallySold {
            rows.append(
                OrderInfoRowData(
                    label: "Bereits verkauft",
                    value: "\(self.viewModel.holding.soldQuantity.formattedAsLocalizedNumber()) Stück"
                )
            )
            rows.append(
                OrderInfoRowData(label: "Original", value: "\(self.viewModel.holding.originalQuantity.formattedAsLocalizedNumber()) Stück")
            )
        }

        return rows
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

    // MARK: - Computed Properties for View Sections

    private var securitiesDetailsSection: some View {
        SecuritiesDetailsSection(
            direction: self.securitiesDirection,
            basiswert: self.securitiesBasiswert,
            strike: self.formatStrikePrice(self.viewModel.holding.strike, self.viewModel.holding.underlyingAsset),
            valuationDate: self.viewModel.holding.valuationDate,
            wkn: self.viewModel.holding.wkn,
            currentPrice: self.viewModel.formattedCurrentPrice,
            priceLabel: "Geld-Kurs (Bid)",
            priceValidityProgress: self.viewModel.priceValidityProgress,
            onReloadPrice: {
                self.viewModel.reloadPrice()
            },
            additionalRows: self.additionalSecuritiesRows,
            isLimitOrder: self.viewModel.orderMode == .limit,
            limitPrice: self.viewModel.limitPrice,
            currentPriceValue: self.viewModel.currentPriceValue,
            isMonitoringLimitOrder: self.viewModel.isMonitoringLimitOrder,
            orderType: "sell"
        )
    }

    private var orderDetailsSection: some View {
        OrderDetailsSection {
            QuantityInputField(
                text: self.$viewModel.quantityText,
                placeholder: "max. \(self.viewModel.holding.remainingQuantity.formattedAsLocalizedNumber()) Stück",
                accessibilityLabel: "Number of shares to sell",
                accessibilityHint: "Enter the quantity of shares you want to sell",
                onSubmit: {
                    self.viewModel.validateAndCorrectQuantity()
                },
                errorMessage: self.viewModel.quantityErrorMessage
            )

            OrderTypeSelection(
                selectedOrderMode: self.$viewModel.orderMode,
                onOrderModeChanged: { newOrderMode in
                    self.viewModel.orderMode = newOrderMode
                    print("🔍 DEBUG: Order mode changed to: \(newOrderMode)")
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

    private var proceedsEstimateSection: some View {
        HStack {
            Text("Erlös (geschätzt)")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(self.viewModel.estimatedProceeds.formattedAsLocalizedCurrency())
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
            isEnabled: self.viewModel.canPlaceOrder,
            action: {
                print("🔘 DEBUG: Sell button tapped in form section")
                Task {
                    await self.viewModel.placeOrder()
                }
            }
        )
        .accessibilityIdentifier("PlaceSellOrderButton")
        .accessibilityLabel("Sell order button")
        .accessibilityHint("Place a sell order for the selected number of shares")
    }

    private var legalNoticeSection: some View {
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
}

// MARK: - Helper Views

#Preview {
    EmptyView()
}
