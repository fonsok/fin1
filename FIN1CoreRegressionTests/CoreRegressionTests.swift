import XCTest
import Combine
@testable import FIN1

/// Core regression coverage for high-value investor flows.
/// Mirrors current AppServices-style DI so we can grow a modern suite.
final class CoreRegressionTests: XCTestCase {
    func testInvestorCollectionBillShowsItemizedFees() {
        // Given: investor participates 50% in a trade with explicit buy/sell fees
        let investment = makeInvestment(amount: 1_000)
        let trade = makeTrade(
            id: "trade-1",
            buyQuantity: 1_000,
            buyPrice: 2,
            sellPrice: 4
        )
        let participation = PoolTradeParticipation(
            tradeId: trade.id,
            investmentId: investment.id,
            poolReservationId: "pool-1",
            poolNumber: 1,
            allocatedAmount: 1_000,
            totalTradeValue: 2_000,
            profitShare: 900 // net profit after commission (10% deducted)
        )

        let potService = MockPoolTradeParticipationService(participations: [participation])
        let tradeLifecycleService = MockTradeLifecycleService(completedTrades: [trade])
        let invoiceService = MockInvoiceService(
            invoices: [
                makeInvoice(
                    id: "INV-BUY",
                    tradeId: trade.id,
                    type: .buy,
                    items: [
                        InvoiceItem(description: "Ordergebühr Kauf", quantity: 1, unitPrice: 12, itemType: .orderFee),
                        InvoiceItem(description: "Börsenplatz Kauf", quantity: 1, unitPrice: 4, itemType: .exchangeFee)
                    ]
                ),
                makeInvoice(
                    id: "INV-SELL",
                    tradeId: trade.id,
                    type: .sell,
                    items: [
                        InvoiceItem(description: "Ordergebühr Verkauf", quantity: 1, unitPrice: 8, itemType: .orderFee),
                        InvoiceItem(description: "Börsenplatz Verkauf", quantity: 1, unitPrice: 2, itemType: .exchangeFee)
                    ]
                )
            ]
        )

        // When
        let calculationService = InvestorCollectionBillCalculationService()
        let viewModel = InvestorInvestmentStatementViewModel(
            investment: investment,
            potTradeParticipationService: potService,
            tradeService: tradeLifecycleService,
            invoiceService: invoiceService,
            calculationService: calculationService
        )

        // Then
        guard let statement = viewModel.statementItems.first else {
            return XCTFail("Expected statement item")
        }

        XCTAssertEqual(statement.buyFeeDetails.map(\.$0.label), ["Ordergebühr Kauf", "Börsenplatz Kauf"])
        XCTAssertEqual(statement.sellFeeDetails.map(\.$0.label), ["Ordergebühr Verkauf", "Börsenplatz Verkauf"])
        XCTAssertEqual(statement.buyFees, 8, accuracy: 0.0001)
        XCTAssertEqual(statement.sellFees, 5, accuracy: 0.0001)
        XCTAssertEqual(statement.grossProfit, 1_000, accuracy: 0.0001) // investor share of gross profit
    }

    func testInvestmentCompletionMatchesStatementGrossReturn() {
        // Scenario from log: investor allocates €2,000 (36.36% ownership), sells for €4,199.48
        let investment = makeInvestment(amount: 2_000)
        let trade = makeTrade(
            id: "trade-42",
            buyQuantity: 524.93,
            buyPrice: 3.81,
            sellPrice: 8.0
        )

        let participation = PoolTradeParticipation(
            tradeId: trade.id,
            investmentId: investment.id,
            poolReservationId: "pool-42",
            poolNumber: 1,
            allocatedAmount: 2_000,
            totalTradeValue: 5_500, // ~36.36% ownership
            profitShare: 1_347.10 // net profit distributed to investor
        )

        let potService = MockPoolTradeParticipationService(participations: [participation])
        let tradeLifecycleService = MockTradeLifecycleService(completedTrades: [trade])
        let invoiceService = MockInvoiceService(
            invoices: [
                makeInvoice(
                    id: "INV-BUY-42",
                    tradeId: trade.id,
                    type: .buy,
                    items: [
                        InvoiceItem(description: "Ordergebühr Kauf", quantity: 1, unitPrice: 8.86, itemType: .orderFee),
                        InvoiceItem(description: "Börsenplatzgebühr (XETRA)", quantity: 1, unitPrice: 6.93, itemType: .exchangeFee),
                        InvoiceItem(description: "Fremdkostenpauschale", quantity: 1, unitPrice: 1.39, itemType: .foreignCosts),
                        InvoiceItem(description: "Clearingkosten", quantity: 1, unitPrice: 0.55, itemType: .other)
                    ]
                ),
                makeInvoice(
                    id: "INV-SELL-42",
                    tradeId: trade.id,
                    type: .sell,
                    items: [
                        InvoiceItem(description: "Ordergebühr Verkauf", quantity: 1, unitPrice: 25.98, itemType: .orderFee),
                        InvoiceItem(description: "Börsenplatzgebühr (XETRA)", quantity: 1, unitPrice: 21.0, itemType: .exchangeFee),
                        InvoiceItem(description: "Fremdkostenpauschale", quantity: 1, unitPrice: 4.20, itemType: .foreignCosts),
                        InvoiceItem(description: "Clearingkosten", quantity: 1, unitPrice: 0.79, itemType: .other)
                    ]
                )
            ]
        )

        let completionService = InvestmentCompletionService(
            potTradeParticipationService: potService,
            telemetryService: nil,
            investorCashBalanceService: nil,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService
        )

        let updated = completionService.updateInvestmentProfitsFromTrades(in: [investment])
        guard let updatedInvestment = updated.first else {
            return XCTFail("Expected updated investment")
        }

        XCTAssertEqual(updatedInvestment.performance, 108.0, accuracy: 0.5, "Return should match Collection Bill gross percentage (~108%)")
    }
}

// MARK: - Local Mocks

private final class MockPoolTradeParticipationService: PoolTradeParticipationServiceProtocol {
    var participations: [PoolTradeParticipation]

    init(participations: [PoolTradeParticipation]) {
        self.participations = participations
    }

    func recordPoolParticipation(tradeId: String, investmentId: String, poolReservationId: String, poolNumber: Int, allocatedAmount: Double, totalTradeValue: Double) async { }
    func getParticipations(forTradeId tradeId: String) -> [PoolTradeParticipation] { participations.filter { $0.tradeId == tradeId } }
    func getParticipations(forInvestmentId investmentId: String) -> [PoolTradeParticipation] { participations.filter { $0.investmentId == investmentId } }
    func getParticipations(forPoolReservationId poolReservationId: String) -> [PoolTradeParticipation] { participations.filter { $0.poolReservationId == poolReservationId } }
    func distributeTradeProfit(tradeId: String, totalProfit: Double) async -> Double { 0 }
    func getAccumulatedProfit(for investmentId: String) -> Double { getParticipations(forInvestmentId: investmentId).compactMap(\.$0.profitShare).reduce(0, +) }
    func getAccumulatedProfit(forPoolReservationId poolReservationId: String) -> Double { getParticipations(forPoolReservationId: poolReservationId).compactMap(\.$0.profitShare).reduce(0, +) }
    func getAccumulatedProfit(forInvestmentReservationId investmentReservationId: String) -> Double { getAccumulatedProfit(forPoolReservationId: investmentReservationId) }
}

private final class MockTradeLifecycleService: TradeLifecycleServiceProtocol {
    var completedTrades: [Trade]
    var isLoading: Bool = false
    var errorMessage: String?

    init(completedTrades: [Trade]) {
        self.completedTrades = completedTrades
    }

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        Just(completedTrades).eraseToAnyPublisher()
    }

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade { fatalError("Not implemented") }
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws { fatalError("Not implemented") }
    func addPartialSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws { fatalError("Not implemented") }
    func cancelTrade(_ tradeId: String) async throws { fatalError("Not implemented") }
    func completeTrade(_ tradeId: String) async throws { fatalError("Not implemented") }
    func loadCompletedTrades() async throws { }
    func refreshCompletedTrades() async throws { }
}

private final class MockInvoiceService: InvoiceServiceProtocol {
    @Published var invoices: [Invoice]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    init(invoices: [Invoice]) {
        self.invoices = invoices
    }

    func loadInvoices(for userId: String) async throws { }
    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice { fatalError("Not implemented") }
    func createInvoice(from sellOrder: OrderSell, customerInfo: CustomerInfo) async throws -> Invoice { fatalError("Not implemented") }
    func addInvoice(_ invoice: Invoice) async { }
    func updateInvoiceStatus(_ invoice: Invoice, status: InvoiceStatus) async throws { }
    func deleteInvoice(_ invoice: Invoice) async throws { }
    func generateInvoicesForCompletedTrades(_ trades: [Trade]) async { }
    func generatePDF(for invoice: Invoice) async throws -> Data { Data() }
    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage { UIImage() }
    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL { FileManager.default.temporaryDirectory }
    func getInvoices(for userId: String) -> [Invoice] { invoices }
    func getInvoicesByType(_ type: InvoiceType, for userId: String) -> [Invoice] { invoices }
    func getInvoice(by id: String) -> Invoice? { invoices.first { $0.id == id } }
    func getInvoicesForTrade(_ tradeId: String) -> [Invoice] { invoices.filter { $0.tradeId == tradeId } }
    func validateInvoice(_ invoice: Invoice) -> Bool { true }
    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool { true }
    func start() {}
    func stop() {}
    func reset() {}
}

// MARK: - Sample builders

private func makeInvestment(id: String = UUID().uuidString, amount: Double) -> Investment {
    Investment(
        id: id,
        batchId: nil,
        investorId: "investor-1",
        traderId: "trader-1",
        traderName: "Trader",
        amount: amount,
        currentValue: amount,
        date: Date(),
        status: .active,
        performance: 0,
        numberOfTrades: 1,
        sequenceNumber: 1,
        createdAt: Date(),
        updatedAt: Date(),
        completedAt: nil,
        specialization: "Tech",
        reservationStatus: .completed
    )
}

private func makeTrade(id: String, buyQuantity: Double, buyPrice: Double, sellPrice: Double) -> Trade {
    let now = Date()
    let buyOrder = OrderBuy(
        id: "buy-\(id)",
        traderId: "trader-1",
        symbol: "ABC",
        description: "Sample",
        quantity: buyQuantity,
        price: buyPrice,
        totalAmount: buyQuantity * buyPrice,
        status: .completed,
        createdAt: now.addingTimeInterval(-3600),
        executedAt: nil,
        confirmedAt: nil,
        updatedAt: now.addingTimeInterval(-3500),
        optionDirection: nil,
        underlyingAsset: nil,
        wkn: nil,
        category: nil,
        strike: nil,
        orderInstruction: nil,
        limitPrice: nil
    )

    let sellOrder = OrderSell(
        id: "sell-\(id)",
        traderId: "trader-1",
        symbol: "ABC",
        description: "Sample",
        quantity: buyQuantity,
        price: sellPrice,
        totalAmount: buyQuantity * sellPrice,
        status: .confirmed,
        createdAt: now.addingTimeInterval(-3400),
        executedAt: nil,
        confirmedAt: nil,
        updatedAt: now.addingTimeInterval(-3300),
        optionDirection: nil,
        underlyingAsset: nil,
        wkn: nil,
        category: nil,
        strike: nil,
        orderInstruction: nil,
        limitPrice: nil,
        originalHoldingId: nil
    )

    return Trade(
        id: id,
        tradeNumber: 1,
        traderId: "trader-1",
        symbol: "ABC",
        description: "Sample trade",
        buyOrder: buyOrder,
        sellOrder: nil,
        sellOrders: [sellOrder],
        status: .completed,
        createdAt: now.addingTimeInterval(-4000),
        completedAt: now.addingTimeInterval(-1000),
        updatedAt: now.addingTimeInterval(-900),
        calculatedProfit: (sellPrice - buyPrice) * buyQuantity
    )
}

private func makeInvoice(id: String, tradeId: String, type: TransactionType, items: [InvoiceItem]) -> Invoice {
    Invoice(
        invoiceNumber: id,
        type: .securitiesSettlement,
        status: .generated,
        customerInfo: CustomerInfo(
            name: "Max Mustermann",
            address: "Musterstraße 1",
            city: "Berlin",
            postalCode: "10115",
            taxNumber: "12/345/67890",
            depotNumber: "DEPOT-1",
            bank: "Bank AG",
            customerNumber: "investor-1"
        ),
        items: items,
        tradeId: tradeId,
        transactionType: type
    )
}
