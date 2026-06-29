import SwiftUI

// MARK: - Buy Order View

struct BuyOrderView: View {
    @ObservedObject var viewModel: BuyOrderViewModel
    var onOrderPlaced: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabRouter: TabRouter
    @Environment(\.themeManager) private var themeManager
    @Environment(\.appServices) private var services
    @State var legalNoticeText: String = ""
    @State var transactionLimitWarningTitle: String = "Transaktionslimit erreicht"
    @State var transactionLimitIntroText: String?
    @FocusState var quantityFieldFocused: Bool

    var isPlacingOrder: Bool { self.viewModel.isPlacingOrder }

    var defaultLegalNoticeText: String {
        "Mit dem Klicken auf 'Kaufen' stimmen Sie den allgemeinen Geschäftsbedingungen zu und bestätigen, dass Sie die Risiken des Wertpapierhandels verstanden haben. Diese Transaktion ist gebührenpflichtig."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(6)) {
                    self.securitiesDetailsSection
                    self.orderDetailsSection
                    self.costEstimateSection
                    self.priceValidityWarningSection
                    self.insufficientFundsWarningSection
                    self.transactionLimitWarningSection
                    BuyOrderFailureSection(viewModel: self.viewModel)
                    self.orderActionButton
                    self.orderPlacementStatusSection

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
            .disabled(self.isPlacingOrder)
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
        .interactiveDismissDisabled(self.isPlacingOrder)
        .accessibilityIdentifier("BuyOrderSheetRoot")
        .onDisappear {
            self.viewModel.priceValidityTimerManager.cleanup()
        }
        .task(id: self.viewModel.searchResult.wkn) {
            #if DEBUG
            print("🔍 BuyOrderView: loading trader pool investments from backend")
            #endif
            await self.viewModel.loadPoolInvestmentsIfNeeded()
        }
        .onChange(of: self.viewModel.shouldShowDepotView) { _, newValue in
            if newValue {
                self.viewModel.shouldShowDepotView = false
                self.tabRouter.selectedTab = 1
                self.onOrderPlaced?()
                self.dismiss()
            }
        }
        .onChange(of: self.viewModel.orderMode) { _, newValue in
            if newValue != .limit {
                self.viewModel.stopLimitOrderMonitoring()
            }
        }
        .onChange(of: self.viewModel.limit) { _, _ in
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
                await self.refreshTransactionLimitSnippet(termsContentService: self.services.termsContentService)
            }
        }
    }
}

#if DEBUG
struct BuyOrderView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
#endif
