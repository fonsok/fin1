import Foundation

extension AppServicesBuilder {

    enum Remaining {
        static func build(_ ctx: inout AppServicesBuildContext) {
            guard let serviceFactory = ctx.serviceFactory,
                  let documentService = ctx.documentService,
                  let pushTokenAPIService = ctx.pushTokenAPIService,
                  let investorWatchlistAPIService = ctx.investorWatchlistAPIService,
                  let userService = ctx.userService,
                  let cashBalanceService = ctx.cashBalanceService,
                  let parseAPIClient = ctx.parseAPIClient,
                  let configurationService = ctx.configurationService,
                  let tradeLifecycleService = ctx.tradeLifecycleService,
                  let tradingNotificationService = ctx.tradingNotificationService,
                  let tradeAPIService = ctx.tradeAPIService,
                  let auditLoggingService = ctx.auditLoggingService,
                  let orderStatusSimulationService = ctx.orderStatusSimulationService,
                  let investmentService = ctx.investmentService,
                  let investorCashBalanceService = ctx.investorCashBalanceService,
                  let telemetryService = ctx.telemetryService else { return }

            let notificationService = NotificationService(
                documentService: documentService,
                pushTokenAPIService: pushTokenAPIService
            )
            notificationService.configure(pushTokenAPIService: pushTokenAPIService)
            print("🔔 AppServicesBuilder: Created NotificationService instance \(ObjectIdentifier(notificationService))")
            ctx.notificationService = notificationService

            let watchlistService = InvestorWatchlistService(
                investorWatchlistAPIService: investorWatchlistAPIService,
                userService: userService
            )
            watchlistService.configure(
                investorWatchlistAPIService: investorWatchlistAPIService,
                userService: userService
            )
            ctx.watchlistService = watchlistService

            ctx.dashboardService = DashboardService()
            ctx.testModeService = TestModeService()
            ctx.roundingDifferencesService = RoundingDifferencesService(telemetryService: telemetryService)
            ctx.holdingsConversionService = HoldingsConversionService.shared
            ctx.termsAcceptanceService = TermsAcceptanceService()
            ctx.termsContentService = TermsContentService(parseAPIClient: parseAPIClient)
            ctx.riskClassCalculationService = RiskClassCalculationService()
            ctx.investmentExperienceCalculationService = InvestmentExperienceCalculationService()
            ctx.addressChangeService = AddressChangeRequestService()
            ctx.nameChangeService = NameChangeRequestService()

            tradeLifecycleService.attach(
                tradeNumberService: serviceFactory.coreTradeNumberService,
                tradingNotificationService: tradingNotificationService,
                invoiceService: serviceFactory.coreInvoiceService,
                tradeAPIService: tradeAPIService,
                userService: userService,
                auditLoggingService: auditLoggingService
            )

            ctx.mainTradingStateStore = MainActor.assumeIsolated { TradingStateStore() }
            ctx.unifiedOrderService = MainActor.assumeIsolated {
                UnifiedOrderService(
                    transactionIdService: serviceFactory.coreTransactionIdService,
                    orderStatusSimulationService: orderStatusSimulationService,
                    tradingNotificationService: tradingNotificationService,
                    cashBalanceService: cashBalanceService,
                    tradeNumberService: serviceFactory.coreTradeNumberService,
                    invoiceService: serviceFactory.coreInvoiceService,
                    userService: userService,
                    auditLoggingService: auditLoggingService,
                    tradeAPIService: tradeAPIService
                )
            }

            ctx.satisfactionSurveyService = SatisfactionSurveyService(notificationService: notificationService)
            ctx.ticketAPIService = TicketAPIService(apiClient: parseAPIClient)

            let customerSupportService = CustomerSupportService(
                auditService: auditLoggingService,
                userService: userService,
                notificationService: notificationService,
                satisfactionSurveyService: ctx.satisfactionSurveyService!,
                investmentService: investmentService,
                tradeLifecycleService: tradeLifecycleService
            )
            customerSupportService.configure(ticketAPIService: ctx.ticketAPIService!)
            ctx.customerSupportService = customerSupportService

            ctx.faqKnowledgeBaseService = FAQKnowledgeBaseService(auditService: auditLoggingService)

            ctx.templateAPIService = serviceFactory.createTemplateAPIService(
                parseAPIClient: parseAPIClient,
                preferredLanguage: "de"
            )

            ctx.slaMonitoringService = SLAMonitoringService(
                supportService: customerSupportService,
                auditService: auditLoggingService,
                notificationService: notificationService,
                configurationService: configurationService
            )

            ctx.fourEyesApprovalService = FourEyesApprovalService(auditService: auditLoggingService)

            let tokenStorage: TokenStorageProtocol = {
                #if DEBUG
                return InMemoryTokenStorage()
                #else
                return KeychainTokenStorage()
                #endif
            }()
            let authProvider: AuthProviderProtocol = {
                #if DEBUG
                return MockAuthProvider(tokenStorage: tokenStorage)
                #else
                return MockAuthProvider(tokenStorage: tokenStorage)
                #endif
            }()
            ctx.tokenStorage = tokenStorage
            ctx.authService = AuthService(authProvider: authProvider, tokenStorage: tokenStorage)

            ctx.paymentService = MockPaymentService(
                cashBalanceService: cashBalanceService,
                userService: userService,
                investorCashBalanceService: investorCashBalanceService,
                auditLoggingService: auditLoggingService,
                parseAPIClient: parseAPIClient
            )

            ctx.transactionLimitService = TransactionLimitService(
                userService: userService,
                auditLoggingService: auditLoggingService
            )
        }
    }
}
