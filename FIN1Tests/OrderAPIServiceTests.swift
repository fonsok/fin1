import XCTest
@testable import FIN1

// MARK: - Order API Service Tests

final class OrderAPIServiceTests: XCTestCase {

    var sut: OrderAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockParseAPIClient()
        sut = OrderAPIService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Save Buy Order Tests

    func testSaveBuyOrder_Success() async throws {
        // Given
        let buyOrder = createSampleBuyOrder()
        mockAPIClient.mockObjectId = "server-order-id-123"

        // When
        let savedOrder = try await sut.saveBuyOrder(buyOrder)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(savedOrder.id, "server-order-id-123")
        XCTAssertEqual(savedOrder.symbol, buyOrder.symbol)
        XCTAssertEqual(savedOrder.quantity, buyOrder.quantity)
        XCTAssertEqual(savedOrder.price, buyOrder.price)
    }

    func testSaveBuyOrder_NetworkError() async {
        // Given
        let buyOrder = createSampleBuyOrder()
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await sut.saveBuyOrder(buyOrder)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Save Sell Order Tests

    func testSaveSellOrder_Success() async throws {
        // Given
        let sellOrder = createSampleSellOrder()
        mockAPIClient.mockObjectId = "server-sell-order-id-456"

        // When
        let savedOrder = try await sut.saveSellOrder(sellOrder)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(savedOrder.id, "server-sell-order-id-456")
        XCTAssertEqual(savedOrder.symbol, sellOrder.symbol)
        XCTAssertEqual(savedOrder.quantity, sellOrder.quantity)
    }

    // MARK: - Update Order Tests

    func testUpdateOrder_Success() async throws {
        // Given
        let order = createSampleOrder()

        // When
        let updatedOrder = try await sut.updateOrder(order)

        // Then
        XCTAssertTrue(mockAPIClient.updateObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(mockAPIClient.lastObjectId, order.id)
        XCTAssertEqual(updatedOrder.id, order.id)
    }

    // MARK: - Fetch Orders Tests

    func testFetchOrders_Success() async throws {
        // Given
        let traderId = "trader-123"
        let mockResponses = [
            createMockOrderResponse(objectId: "order-1", type: "buy"),
            createMockOrderResponse(objectId: "order-2", type: "sell")
        ]
        mockAPIClient.mockFetchResults = mockResponses

        // When
        let orders = try await sut.fetchOrders(for: traderId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(orders.count, 2)
    }

    func testFetchOrders_EmptyResult() async throws {
        // Given
        let traderId = "trader-no-orders"
        mockAPIClient.mockFetchResults = [MockOrderResponse]()

        // When
        let orders = try await sut.fetchOrders(for: traderId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(orders.isEmpty)
    }

    // MARK: - Fetch Active Orders Tests

    func testFetchActiveOrders_FiltersCompletedAndCancelled() async throws {
        // Given
        let traderId = "trader-123"
        let mockResponses = [
            createMockOrderResponse(objectId: "order-1", type: "buy", status: "submitted"),
            createMockOrderResponse(objectId: "order-2", type: "buy", status: "completed"),
            createMockOrderResponse(objectId: "order-3", type: "sell", status: "cancelled"),
            createMockOrderResponse(objectId: "order-4", type: "sell", status: "executed")
        ]
        mockAPIClient.mockFetchResults = mockResponses

        // When
        let activeOrders = try await sut.fetchActiveOrders(for: traderId)

        // Then
        XCTAssertEqual(activeOrders.count, 2)
        XCTAssertTrue(activeOrders.allSatisfy {
            $0.status.lowercased() != "completed" && $0.status.lowercased() != "cancelled"
        })
    }

    // MARK: - Cancel Order Tests

    func testCancelOrder_Success() async throws {
        // Given
        let orderId = "order-to-cancel-123"

        // When
        try await sut.cancelOrder(orderId)

        // Then
        XCTAssertTrue(mockAPIClient.updateObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(mockAPIClient.lastObjectId, orderId)
    }

    func testCancelOrder_NetworkError() async {
        // Given
        let orderId = "order-to-cancel-123"
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.serverError(500)

        // When/Then
        do {
            try await sut.cancelOrder(orderId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Helper Methods

    private func createSampleBuyOrder() -> OrderBuy {
        return OrderBuy(
            id: "local-buy-order-id",
            traderId: "trader-123",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: .submitted,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL",
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            subscriptionRatio: nil,
            denomination: nil
        )
    }

    private func createSampleSellOrder() -> OrderSell {
        return OrderSell(
            id: "local-sell-order-id",
            traderId: "trader-123",
            symbol: "AAPL",
            description: "Apple Inc.",
            quantity: 50,
            price: 155.0,
            totalAmount: 7750.0,
            status: .submitted,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL",
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            originalHoldingId: nil
        )
    }

    private func createSampleOrder() -> Order {
        return Order(
            id: "order-123",
            traderId: "trader-123",
            symbol: "AAPL",
            description: "Apple Inc.",
            type: .buy,
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL",
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            subscriptionRatio: nil,
            denomination: nil,
            originalHoldingId: nil,
            status: "submitted"
        )
    }

    private func createMockOrderResponse(objectId: String, type: String, status: String = "submitted") -> MockOrderResponse {
        return MockOrderResponse(
            objectId: objectId,
            traderId: "trader-123",
            symbol: "AAPL",
            description: "Apple Inc.",
            type: type,
            quantity: 100,
            price: 150.0,
            totalAmount: 15000.0,
            status: status,
            createdAt: "2026-02-04T10:00:00.000Z",
            updatedAt: "2026-02-04T10:00:00.000Z",
            executedAt: nil,
            confirmedAt: nil,
            optionDirection: nil,
            underlyingAsset: nil,
            wkn: "AAPL",
            category: nil,
            strike: nil,
            orderInstruction: "market",
            limitPrice: nil,
            subscriptionRatio: nil,
            denomination: nil,
            originalHoldingId: nil
        )
    }
}

// MARK: - Mock Order Response

/// Mock response matching ParseOrderResponse structure for testing
private struct MockOrderResponse: Codable {
    let objectId: String
    let traderId: String
    let symbol: String
    let description: String
    let type: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let updatedAt: String
    let executedAt: String?
    let confirmedAt: String?
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let subscriptionRatio: Double?
    let denomination: Int?
    let originalHoldingId: String?

    func toOrder() -> Order {
        let orderType: OrderType = type == "buy" ? .buy : .sell
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return Order(
            id: objectId,
            traderId: traderId,
            symbol: symbol,
            description: description,
            type: orderType,
            quantity: quantity,
            price: price,
            totalAmount: totalAmount,
            createdAt: dateFormatter.date(from: createdAt) ?? Date(),
            executedAt: executedAt.flatMap { dateFormatter.date(from: $0) },
            confirmedAt: confirmedAt.flatMap { dateFormatter.date(from: $0) },
            updatedAt: dateFormatter.date(from: updatedAt) ?? Date(),
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            subscriptionRatio: subscriptionRatio,
            denomination: denomination,
            originalHoldingId: originalHoldingId,
            status: status
        )
    }
}
