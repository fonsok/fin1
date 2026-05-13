@testable import FIN1
import XCTest

// MARK: - Order API Service Tests

final class OrderAPIServiceTests: XCTestCase {

    var sut: OrderAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        self.mockAPIClient = MockParseAPIClient()
        self.sut = OrderAPIService(apiClient: self.mockAPIClient)
    }

    override func tearDown() {
        self.sut = nil
        self.mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Save Buy Order Tests

    func testSaveBuyOrder_Success() async throws {
        // Given
        let buyOrder = self.createSampleBuyOrder()
        self.mockAPIClient.mockObjectId = "server-order-id-123"

        // When
        let savedOrder = try await sut.saveBuyOrder(buyOrder)

        // Then
        XCTAssertTrue(self.mockAPIClient.createObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(savedOrder.id, "server-order-id-123")
        XCTAssertEqual(savedOrder.symbol, buyOrder.symbol)
        XCTAssertEqual(savedOrder.quantity, buyOrder.quantity)
        XCTAssertEqual(savedOrder.price, buyOrder.price)
    }

    func testSaveBuyOrder_NetworkError() async {
        // Given
        let buyOrder = self.createSampleBuyOrder()
        self.mockAPIClient.shouldThrowError = true
        self.mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await self.sut.saveBuyOrder(buyOrder)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Save Sell Order Tests

    func testSaveSellOrder_Success() async throws {
        // Given
        let sellOrder = self.createSampleSellOrder()
        self.mockAPIClient.mockObjectId = "server-sell-order-id-456"

        // When
        let savedOrder = try await sut.saveSellOrder(sellOrder)

        // Then
        XCTAssertTrue(self.mockAPIClient.createObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(savedOrder.id, "server-sell-order-id-456")
        XCTAssertEqual(savedOrder.symbol, sellOrder.symbol)
        XCTAssertEqual(savedOrder.quantity, sellOrder.quantity)
    }

    // MARK: - Update Order Tests

    func testUpdateOrder_Success() async throws {
        // Given
        let order = self.createSampleOrder()

        // When
        let updatedOrder = try await sut.updateOrder(order)

        // Then
        XCTAssertTrue(self.mockAPIClient.updateObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(self.mockAPIClient.lastObjectId, order.id)
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
        self.mockAPIClient.mockFetchResults = mockResponses

        // When
        let orders = try await sut.fetchOrders(for: traderId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(orders.count, 2)
    }

    func testFetchOrders_EmptyResult() async throws {
        // Given
        let traderId = "trader-no-orders"
        self.mockAPIClient.mockFetchResults = [ParseOrderResponse]()

        // When
        let orders = try await sut.fetchOrders(for: traderId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
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
        self.mockAPIClient.mockFetchResults = mockResponses

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
        XCTAssertTrue(self.mockAPIClient.updateObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "Order")
        XCTAssertEqual(self.mockAPIClient.lastObjectId, orderId)
    }

    func testCancelOrder_NetworkError() async {
        // Given
        let orderId = "order-to-cancel-123"
        self.mockAPIClient.shouldThrowError = true
        self.mockAPIClient.errorToThrow = NetworkError.serverError(500)

        // When/Then
        do {
            try await self.sut.cancelOrder(orderId)
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
            totalAmount: 15_000.0,
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
            totalAmount: 7_750.0,
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
            totalAmount: 15_000.0,
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

    private func createMockOrderResponse(objectId: String, type: String, status: String = "submitted") -> ParseOrderResponse {
        ParseOrderResponse(
            objectId: objectId,
            traderId: "trader-123",
            symbol: "AAPL",
            description: "Apple Inc.",
            type: type,
            quantity: 100,
            price: 150.0,
            totalAmount: 15_000.0,
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
