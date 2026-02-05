import SwiftUI

struct CompletedInvestmentsView: View {
    @StateObject private var viewModel: CompletedInvestmentsViewModel
    @Environment(\.appServices) private var appServices
    @State private var selectedCompletedInvestment: Investment?

    init(userService: (any UserServiceProtocol)? = nil,
         investmentService: (any InvestmentServiceProtocol)? = nil,
         documentService: (any DocumentServiceProtocol)? = nil,
         invoiceService: (any InvoiceServiceProtocol)? = nil,
         traderDataService: (any TraderDataServiceProtocol)? = nil,
         poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
         tradeLifecycleService: (any TradeLifecycleServiceProtocol)? = nil,
         configurationService: (any ConfigurationServiceProtocol)? = nil,
         commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil) {
        // Services must be provided - wrapper handles injection
        guard let userSvc = userService, let invSvc = investmentService,
              let docSvc = documentService, let invoiceSvc = invoiceService,
              let traderSvc = traderDataService, let poolSvc = poolTradeParticipationService,
              let tradeSvc = tradeLifecycleService, let configSvc = configurationService,
              let commissionSvc = commissionCalculationService else {
            fatalError("CompletedInvestmentsView must be initialized with services. Use CompletedInvestmentsViewWrapper instead.")
        }
        self._viewModel = StateObject(wrappedValue: CompletedInvestmentsViewModel(
            userService: userSvc,
            investmentService: invSvc,
            documentService: docSvc,
            invoiceService: invoiceSvc,
            traderDataService: traderSvc,
            poolTradeParticipationService: poolSvc,
            tradeLifecycleService: tradeSvc,
            configurationService: configSvc,
            commissionCalculationService: commissionSvc
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

                    // Completed Investments Section
                    completedInvestmentsSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("(Partially) Completed Investments")
        .sheet(item: $selectedCompletedInvestment) { investment in
            CompletedInvestmentDetailSheet(investment: investment)
        }
        .task {
            viewModel.reconfigure(with: appServices)
            viewModel.loadCompletedInvestments()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("(Partially) Completed Investments")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(AppTheme.fontColor)

            if let user = viewModel.currentUser {
                Text("Portfolio-Nr.: \(user.customerId)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))

                Text("Portfolio owner: \(user.fullName)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
            } else {
                Text("Portfolio-Nr.: ...")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))

                Text("Portfolio owner: ...")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
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
            .fill(AppTheme.fontColor.opacity(0.2))
            .frame(height: 1)
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(4))
    }

    // MARK: - Completed Investments Section

    private var completedInvestmentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            // Section Title
            Text("(Partially) Completed Investments")
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
                    investmentDocRefs: viewModel.investmentDocRefs,
                    traderUsernames: viewModel.traderUsernames,
                    tradeNumbers: viewModel.tradeNumbers,
                    investmentSummaries: viewModel.investmentSummaries,
                    onShowDetails: { investment in
                        selectedCompletedInvestment = investment
                    }
                )
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    if allCompletedCount == 0 {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "tray")
                                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                                .foregroundColor(AppTheme.fontColor.opacity(0.4))

                            Text("No (partially) completed investments")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))

                            Text("Investments appear here when at least one pool is completed, or when cancelled.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text("No completed investments for selected time period")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))

                            Text("Total completed: \(allCompletedCount)")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))

                            Text("Try selecting a different time period")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.5))
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

// MARK: - Completed Investments View Wrapper

struct CompletedInvestmentsViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        CompletedInvestmentsView(
            userService: services.userService,
            investmentService: services.investmentService,
            documentService: services.documentService,
            invoiceService: services.invoiceService,
            traderDataService: services.traderDataService,
            poolTradeParticipationService: services.poolTradeParticipationService,
            tradeLifecycleService: services.tradeLifecycleService,
            configurationService: services.configurationService,
            commissionCalculationService: services.commissionCalculationService
        )
    }
}

#Preview {
    CompletedInvestmentsViewWrapper()
        .environment(\.appServices, AppServices.live)
}
