import SwiftUI

struct InvestmentsView: View {
    @StateObject private var viewModel: InvestmentsViewModel
    @Environment(\.appServices) private var appServices
    @State private var showDeleteConfirmation = false
    @State private var investmentToDelete: InvestmentRow?
    @State private var showStatusInfo = false
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var selectedCompletedInvestment: Investment?
    @State private var selectedPartialSellInvestment: Investment?
    /// Server mirror P/L (aggregierte Collection Bills, inkl. Teil-Sell-Deltas).
    @State private var partialSellSheetMirrorSummary: ServerInvestmentCanonicalSummary?
    @State private var partialSellSheetCollectionBills: [BackendCollectionBill] = []
    @State private var partialSellSheetServerLoading = false

    init(
        userService: (any UserServiceProtocol)? = nil,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)? = nil,
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        guard let userSvc = userService, let invSvc = investmentService,
              let poolSvc = poolTradeParticipationService, let docSvc = documentService, let invSvc2 = invoiceService,
              let traderSvc = traderDataService, let tradeSvc = tradeLifecycleService,
              let configSvc = configurationService, let commissionSvc = commissionCalculationService else {
            fatalError("InvestmentsView must be initialized with services. Use InvestmentsViewWrapper instead.")
        }
        self._viewModel = StateObject(wrappedValue: InvestmentsViewModel(
            userService: userSvc,
            investmentService: invSvc,
            investorCashBalanceService: investorCashBalanceService,
            poolTradeParticipationService: poolSvc,
            documentService: docSvc,
            invoiceService: invSvc2,
            traderDataService: traderSvc,
            tradeLifecycleService: tradeSvc,
            configurationService: configSvc,
            commissionCalculationService: commissionSvc,
            settlementAPIService: settlementAPIService
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Header
                    InvestmentsHeaderSectionView(currentUser: self.viewModel.currentUser)

                    // Separator
                    InvestmentsSectionSeparatorView()

                    // Reserved Investments Section
                    self.reservedInvestmentsSection

                    // Separator between sections
                    InvestmentsSectionSeparatorView()

                    // Active Investments Section
                    self.activeInvestmentsSection

                    // Separator between sections
                    InvestmentsSectionSeparatorView()

                    // Active partial sell realizations
                    self.partialSellRealizationsSection

                    // Separator between sections
                    InvestmentsSectionSeparatorView()

                    // Completed Investments Section
                    self.completedInvestmentsSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Investments")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.viewModel.showNewInvestmentSheet() }, label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppTheme.accentLightBlue)
                })
                .accessibilityIdentifier("NewInvestmentButton")
            }
        }
        .sheet(isPresented: self.$viewModel.showNewInvestment) {
            // Placeholder for new investment creation
            // In a real app, this would navigate to trader selection or investment creation flow
            Text("New Investment")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding()
        }
        .sheet(item: self.$selectedCompletedInvestment) { investment in
            CompletedInvestmentDetailSheet(investment: investment)
        }
        .sheet(item: self.$selectedPartialSellInvestment) { investment in
            self.partialSellDetailSheet(for: investment)
                .task(id: investment.id) {
                    await self.refreshPartialSellSheetServerData(for: investment)
                }
                .onDisappear {
                    self.partialSellSheetMirrorSummary = nil
                    self.partialSellSheetCollectionBills = []
                }
        }
        .confirmationDialog(
            "Delete Investment",
            isPresented: self.$showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let investment = investmentToDelete {
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await self.viewModel.deleteInvestment(investment)
                            self.investmentToDelete = nil
                            self.showDeleteConfirmation = false
                        } catch {
                            let appError = error.toAppError()
                            self.viewModel.showError(appError)
                            self.investmentToDelete = nil
                            self.showDeleteConfirmation = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    self.investmentToDelete = nil
                    self.showDeleteConfirmation = false
                }
            }
        } message: {
            if let investment = investmentToDelete {
                Text("Are you sure you want to delete Investment \(investment.sequenceNumber)? This action cannot be undone.")
            }
        }
        .alert("Status Information", isPresented: self.$showStatusInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(
                "Status meanings:\n• Reserved Investments: deletable rows are shown with a trash icon\n• Active Investments: rows are non-deletable and show status text (active/completed)"
            )
        }
        .task {
            self.viewModel.reconfigure(with: self.appServices)
            self.viewModel.loadInvestmentsData()
        }
    }

    // MARK: - Reserved Investments Section

    private var reservedInvestmentsSection: some View {
        InvestmentsReservedSectionView(
            reservedInvestmentRows: self.viewModel.reservedInvestmentRows,
            sortedTraderNames: self.viewModel.sortedReservedTraderNames,
            groupedInvestments: self.viewModel.groupedReservedInvestments,
            totalReservedAmount: self.viewModel.totalReservedAmount,
            traderDataService: self.appServices.traderDataService,
            columnWidths: self.$columnWidths,
            onDeleteInvestment: { investment in
                Task { @MainActor in
                    self.investmentToDelete = investment
                    self.showDeleteConfirmation = true
                }
            },
            onShowStatusInfo: {
                self.showStatusInfo = true
            }
        )
    }

    // MARK: - Active Investments Section

    private var activeInvestmentsSection: some View {
        InvestmentsActiveSectionView(
            activeInvestmentRows: self.viewModel.activeInvestmentRows,
            sortedTraderNames: self.viewModel.sortedActiveTraderNames,
            groupedInvestments: self.viewModel.groupedActiveInvestments,
            traderDataService: self.appServices.traderDataService,
            columnWidths: self.$columnWidths,
            onDeleteInvestment: { investment in
                Task { @MainActor in
                    self.investmentToDelete = investment
                    self.showDeleteConfirmation = true
                }
            },
            onShowStatusInfo: {
                self.showStatusInfo = true
            }
        )
    }

    // MARK: - Completed Investments Section

    private var completedInvestmentsSection: some View {
        InvestmentsCompletedSectionView(
            selectedTimePeriod: self.$viewModel.selectedTimePeriod,
            allCompletedCount: self.viewModel.completedInvestments.count,
            completedInvestmentsByTimePeriod: self.viewModel.completedInvestmentsByTimePeriod,
            completedInvestmentDocRefs: self.viewModel.completedInvestmentDocRefs,
            completedTraderUsernames: self.viewModel.completedTraderUsernames,
            completedTradeNumbers: self.viewModel.completedTradeNumbers,
            completedInvestmentSummaries: self.viewModel.completedInvestmentSummaries,
            completedCanonicalSummaries: self.viewModel.completedCanonicalSummaries,
            onTimePeriodChanged: { period in
                self.viewModel.filterCompletedInvestments(by: period)
            },
            onShowDetails: { investment in
                self.selectedCompletedInvestment = investment
            }
        )
    }

    // MARK: - Partial Sell Realizations (Active)

    private var partialSellRealizationsSection: some View {
        InvestmentsPartialSellSectionView(
            partialSellRows: self.viewModel.partialSellActiveInvestmentRows,
            sortedTraderNames: self.viewModel.sortedPartialSellTraderNames,
            groupedInvestments: self.viewModel.groupedPartialSellActiveInvestments,
            traderDataService: self.appServices.traderDataService,
            onSelectInvestment: { investment in
                self.selectedPartialSellInvestment = investment
            }
        )
    }

    private func refreshPartialSellSheetServerData(for investment: Investment) async {
        guard let api = appServices.settlementAPIService else {
            await MainActor.run {
                self.partialSellSheetServerLoading = false
                self.partialSellSheetMirrorSummary = nil
                self.partialSellSheetCollectionBills = []
            }
            return
        }
        await MainActor.run { self.partialSellSheetServerLoading = true }
        do {
            let response = try await api.fetchInvestorCollectionBills(
                limit: 100,
                skip: 0,
                investmentId: investment.id,
                tradeId: nil
            )
            let summary = ServerCalculatedReturnResolver.canonicalSummary(fromCollectionBills: response.collectionBills)
            await MainActor.run {
                self.partialSellSheetMirrorSummary = summary
                self.partialSellSheetCollectionBills = response.collectionBills
                self.partialSellSheetServerLoading = false
            }
        } catch {
            await MainActor.run {
                self.partialSellSheetMirrorSummary = nil
                self.partialSellSheetCollectionBills = []
                self.partialSellSheetServerLoading = false
            }
        }
    }

    @ViewBuilder
    private func partialSellDetailSheet(for investment: Investment) -> some View {
        InvestmentsPartialSellDetailSheetView(
            investment: investment,
            appServices: self.appServices,
            partialSellSheetMirrorSummary: self.partialSellSheetMirrorSummary,
            partialSellSheetCollectionBills: self.partialSellSheetCollectionBills,
            partialSellSheetServerLoading: self.partialSellSheetServerLoading,
            onDone: { self.selectedPartialSellInvestment = nil }
        )
    }
}
