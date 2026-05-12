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

    init(userService: (any UserServiceProtocol)? = nil,
         investmentService: (any InvestmentServiceProtocol)? = nil,
         investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
         poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
         documentService: (any DocumentServiceProtocol)? = nil,
         invoiceService: (any InvoiceServiceProtocol)? = nil,
         traderDataService: (any TraderDataServiceProtocol)? = nil,
         tradeLifecycleService: (any TradeLifecycleServiceProtocol)? = nil,
         configurationService: (any ConfigurationServiceProtocol)? = nil,
         commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
         settlementAPIService: (any SettlementAPIServiceProtocol)? = nil) {
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
                    InvestmentsHeaderSectionView(currentUser: viewModel.currentUser)

                    // Separator
                    InvestmentsSectionSeparatorView()

                    // Reserved Investments Section
                    reservedInvestmentsSection

                    // Separator between sections
                    InvestmentsSectionSeparatorView()

                    // Active Investments Section
                    activeInvestmentsSection

                    // Separator between sections
                    InvestmentsSectionSeparatorView()

                    // Active partial sell realizations
                    partialSellRealizationsSection

                    // Separator between sections
                    InvestmentsSectionSeparatorView()

                    // Completed Investments Section
                    completedInvestmentsSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Investments")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.showNewInvestmentSheet() }, label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppTheme.accentLightBlue)
                })
                .accessibilityIdentifier("NewInvestmentButton")
            }
        }
        .sheet(isPresented: $viewModel.showNewInvestment) {
            // Placeholder for new investment creation
            // In a real app, this would navigate to trader selection or investment creation flow
            Text("New Investment")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding()
        }
        .sheet(item: $selectedCompletedInvestment) { investment in
            CompletedInvestmentDetailSheet(investment: investment)
        }
        .sheet(item: $selectedPartialSellInvestment) { investment in
            partialSellDetailSheet(for: investment)
                .task(id: investment.id) {
                    await refreshPartialSellSheetServerData(for: investment)
                }
                .onDisappear {
                    partialSellSheetMirrorSummary = nil
                    partialSellSheetCollectionBills = []
                }
        }
        .confirmationDialog(
            "Delete Investment",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let investment = investmentToDelete {
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteInvestment(investment)
                            investmentToDelete = nil
                            showDeleteConfirmation = false
                        } catch {
                            let appError = error.toAppError()
                            viewModel.showError(appError)
                            investmentToDelete = nil
                            showDeleteConfirmation = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    investmentToDelete = nil
                    showDeleteConfirmation = false
                }
            }
        } message: {
            if let investment = investmentToDelete {
                Text("Are you sure you want to delete Investment \(investment.sequenceNumber)? This action cannot be undone.")
            }
        }
        .alert("Status Information", isPresented: $showStatusInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Status meanings:\n• Reserved Investments: deletable rows are shown with a trash icon\n• Active Investments: rows are non-deletable and show status text (active/completed)")
        }
        .task {
            viewModel.reconfigure(with: appServices)
            viewModel.loadInvestmentsData()
        }
    }

    // MARK: - Reserved Investments Section

    private var reservedInvestmentsSection: some View {
        InvestmentsReservedSectionView(
            reservedInvestmentRows: viewModel.reservedInvestmentRows,
            sortedTraderNames: viewModel.sortedReservedTraderNames,
            groupedInvestments: viewModel.groupedReservedInvestments,
            totalReservedAmount: viewModel.totalReservedAmount,
            traderDataService: appServices.traderDataService,
            columnWidths: $columnWidths,
            onDeleteInvestment: { investment in
                Task { @MainActor in
                    investmentToDelete = investment
                    showDeleteConfirmation = true
                }
            },
            onShowStatusInfo: {
                showStatusInfo = true
            }
        )
    }

    // MARK: - Active Investments Section

    private var activeInvestmentsSection: some View {
        InvestmentsActiveSectionView(
            activeInvestmentRows: viewModel.activeInvestmentRows,
            sortedTraderNames: viewModel.sortedActiveTraderNames,
            groupedInvestments: viewModel.groupedActiveInvestments,
            traderDataService: appServices.traderDataService,
            columnWidths: $columnWidths,
            onDeleteInvestment: { investment in
                Task { @MainActor in
                    investmentToDelete = investment
                    showDeleteConfirmation = true
                }
            },
            onShowStatusInfo: {
                showStatusInfo = true
            }
        )
    }

    // MARK: - Completed Investments Section

    private var completedInvestmentsSection: some View {
        InvestmentsCompletedSectionView(
            selectedTimePeriod: $viewModel.selectedTimePeriod,
            allCompletedCount: viewModel.completedInvestments.count,
            completedInvestmentsByTimePeriod: viewModel.completedInvestmentsByTimePeriod,
            completedInvestmentDocRefs: viewModel.completedInvestmentDocRefs,
            completedTraderUsernames: viewModel.completedTraderUsernames,
            completedTradeNumbers: viewModel.completedTradeNumbers,
            completedInvestmentSummaries: viewModel.completedInvestmentSummaries,
            completedCanonicalSummaries: viewModel.completedCanonicalSummaries,
            onTimePeriodChanged: { period in
                viewModel.filterCompletedInvestments(by: period)
            },
            onShowDetails: { investment in
                selectedCompletedInvestment = investment
            }
        )
    }

    // MARK: - Partial Sell Realizations (Active)

    private var partialSellRealizationsSection: some View {
        InvestmentsPartialSellSectionView(
            partialSellRows: viewModel.partialSellActiveInvestmentRows,
            sortedTraderNames: viewModel.sortedPartialSellTraderNames,
            groupedInvestments: viewModel.groupedPartialSellActiveInvestments,
            traderDataService: appServices.traderDataService,
            onSelectInvestment: { investment in
                selectedPartialSellInvestment = investment
            }
        )
    }

    private func refreshPartialSellSheetServerData(for investment: Investment) async {
        guard let api = appServices.settlementAPIService else {
            await MainActor.run {
                partialSellSheetServerLoading = false
                partialSellSheetMirrorSummary = nil
                partialSellSheetCollectionBills = []
            }
            return
        }
        await MainActor.run { partialSellSheetServerLoading = true }
        do {
            let response = try await api.fetchInvestorCollectionBills(
                limit: 100,
                skip: 0,
                investmentId: investment.id,
                tradeId: nil
            )
            let summary = ServerCalculatedReturnResolver.canonicalSummary(fromCollectionBills: response.collectionBills)
            await MainActor.run {
                partialSellSheetMirrorSummary = summary
                partialSellSheetCollectionBills = response.collectionBills
                partialSellSheetServerLoading = false
            }
        } catch {
            await MainActor.run {
                partialSellSheetMirrorSummary = nil
                partialSellSheetCollectionBills = []
                partialSellSheetServerLoading = false
            }
        }
    }

    @ViewBuilder
    private func partialSellDetailSheet(for investment: Investment) -> some View {
        InvestmentsPartialSellDetailSheetView(
            investment: investment,
            appServices: appServices,
            partialSellSheetMirrorSummary: partialSellSheetMirrorSummary,
            partialSellSheetCollectionBills: partialSellSheetCollectionBills,
            partialSellSheetServerLoading: partialSellSheetServerLoading,
            onDone: { selectedPartialSellInvestment = nil }
        )
    }
}
