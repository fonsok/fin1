import SwiftUI

struct InvestmentsView: View {
    @StateObject private var viewModel: InvestmentsViewModel
    @Environment(\.appServices) private var appServices
    @State private var showDeleteConfirmation = false
    @State private var investmentToDelete: InvestmentRow?
    @State private var showStatusInfo = false
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var selectedCompletedInvestment: Investment?
    @Environment(\.themeManager) private var themeManager

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
                    headerSection

                    // Separator
                    separator

                    // Ongoing Investments Section
                    ongoingInvestmentsSection

                    // Separator between sections
                    separator

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
            Text("Status meanings:\n• Status 1: Reserved (deletable) - shown with trash icon\n• Status 2: Active - trader started trade (cannot be deleted)\n• Status 3: Completed - trader completed trade (cannot be deleted)")
        }
        .task {
            viewModel.reconfigure(with: appServices)
            viewModel.loadInvestmentsData()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Investments")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(AppTheme.fontColor)

            if let user = viewModel.currentUser {
                Text("Kunden-Nr.: \(user.customerNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)

                Text("Kontoinhaber: \(user.fullName)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            } else {
                Text("Kunden-Nr.: ...")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)

                Text("Kontoinhaber: ...")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.top, ResponsiveDesign.spacing(8))
        .padding(.bottom, ResponsiveDesign.spacing(4))
    }

    // MARK: - Separator

    private var separator: some View {
        Rectangle()
            .fill(AppTheme.systemSeparator)
            .frame(height: 1)
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(4))
    }

    // MARK: - Ongoing Investments Section

    private var ongoingInvestmentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            // Section Title
            Text("Ongoing Investments")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            // Investment Group Headers (if needed)
            if !viewModel.ongoingInvestmentRows.isEmpty {
                // Use ViewModel's pre-processed grouped data (MVVM: business logic in ViewModel)
                ForEach(viewModel.sortedTraderNames, id: \.self) { traderName in
                    let sortedTraderInvestments = viewModel.groupedOngoingInvestments[traderName] ?? []
                    if let firstInvestment = sortedTraderInvestments.first {
                        // Get trader's username from TraderDataService (never show real name for security)
                        let traderUsername = appServices.traderDataService.getTrader(by: firstInvestment.investment.traderId)?.username ?? "---"
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text("\"\(traderUsername)\"")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                            Text("\(sortedTraderInvestments.count) investment\(sortedTraderInvestments.count == 1 ? "" : "s")")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        }
                        .padding(.top, ResponsiveDesign.spacing(4))

                        // Table in its own section with SectionBackground
                        VStack(spacing: ResponsiveDesign.spacing(0)) {
                            // Calculate totals for THIS trader's investments only
                            let traderTotalAmount = sortedTraderInvestments.reduce(0) { $0 + $1.amount }
                            let traderProfits = sortedTraderInvestments.compactMap { $0.profit }
                            let traderTotalProfit = traderProfits.isEmpty ? nil : traderProfits.reduce(0, +)
                            let traderTotalReturn = traderTotalProfit.map { profit in
                                traderTotalAmount > 0 ? (profit / traderTotalAmount) * 100 : nil
                            } ?? nil

                            OngoingInvestmentsTable(
                                pools: sortedTraderInvestments,
                                columnWidths: $columnWidths,
                                totalAmount: traderTotalAmount,
                                totalProfit: traderTotalProfit,
                                totalReturn: traderTotalReturn,
                                onDeleteInvestment: { investment in
                                    print("🗑️ onDeleteInvestment called for investment \(investment.investmentId)")
                                    // Set the investment first, then show the confirmation
                                    // Using Task ensures state updates happen on the main actor
                                    Task { @MainActor in
                                        print("🗑️ Setting investmentToDelete and showDeleteConfirmation")
                                        investmentToDelete = investment
                                        showDeleteConfirmation = true
                                        print("🗑️ State updated - investmentToDelete: \(investmentToDelete != nil), showDeleteConfirmation: \(showDeleteConfirmation)")
                                    }
                                },
                                onShowStatusInfo: {
                                    showStatusInfo = true
                                }
                            )
                        }
                        .background(AppTheme.sectionBackground)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                    }
                }
            } else {
                Text("No ongoing investments")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }

    // MARK: - Completed Investments Section

    private var completedInvestmentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            // Section Title
            Text("Completed Investments")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            // Time Period Header
            InvestmentsTimePeriodHeaderView(
                selectedTimePeriod: $viewModel.selectedTimePeriod,
                onTimePeriodChanged: { period in
                    viewModel.filterCompletedInvestments(by: period)
                }
            )

            // Table
            let allCompletedCount = viewModel.completedInvestments.count

            if !viewModel.completedInvestmentsByTimePeriod.isEmpty {
                CompletedInvestmentsTable(
                    investments: viewModel.completedInvestmentsByTimePeriod,
                    investmentDocRefs: viewModel.completedInvestmentDocRefs,
                    traderUsernames: viewModel.completedTraderUsernames,
                    tradeNumbers: viewModel.completedTradeNumbers,
                    investmentSummaries: viewModel.completedInvestmentSummaries,
                    tradeLedReturnPercentages: viewModel.completedTradeLedReturnPercentages,
                    onShowDetails: { investment in
                        selectedCompletedInvestment = investment
                    }
                )
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    if allCompletedCount == 0 {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "tray")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                                .foregroundColor(AppTheme.quaternaryText)

                            Text("No completed investments")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.secondaryText)

                            Text("Investments appear here when completed or cancelled.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.tertiaryText)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text("No completed investments for selected time period")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.secondaryText)

                            Text("Total completed: \(allCompletedCount)")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.tertiaryText)

                            Text("Try selecting a different time period")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.quaternaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.vertical, ResponsiveDesign.spacing(16))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }
}

// MARK: - Investments View Wrapper

struct InvestmentsViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        InvestmentsView(
            userService: services.userService,
            investmentService: services.investmentService,
            investorCashBalanceService: services.investorCashBalanceService,
            poolTradeParticipationService: services.poolTradeParticipationService,
            documentService: services.documentService,
            invoiceService: services.invoiceService,
            traderDataService: services.traderDataService,
            tradeLifecycleService: services.tradeLifecycleService,
            configurationService: services.configurationService,
            commissionCalculationService: services.commissionCalculationService,
            settlementAPIService: services.settlementAPIService
        )
    }
}

#Preview {
    InvestmentsViewWrapper()
        .environment(\.appServices, AppServices.live)
}
