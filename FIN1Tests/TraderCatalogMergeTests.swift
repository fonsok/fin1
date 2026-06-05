@testable import FIN1
import XCTest

final class TraderCatalogMergeTests: XCTestCase {
    func testHydratesMockTraderByUsername() {
        let mock = mockTraders[0]
        let server = [
            DiscoverTraderRecord(
                traderId: "Ab12Cd34Ef",
                username: mock.username,
                displayName: "Server Name",
                riskClass: 4,
                investorCount: 3,
                totalAUM: 1_000,
                acceptingInvestments: true
            )
        ]
        let merged = TraderCatalogMerge.merge(mockCatalog: [mock], serverRows: server)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].parseUserId, "Ab12Cd34Ef")
        XCTAssertEqual(merged[0].backendTraderId, "Ab12Cd34Ef")
        XCTAssertEqual(merged[0].name, "Server Name")
        XCTAssertEqual(merged[0].catalogId, mock.id.uuidString)
        XCTAssertTrue(merged[0].isFromMockCatalog)
        XCTAssertNotNil(merged[0].demoMetrics)
    }

    func testAppendsServerOnlyTraderForDiscover() {
        let merged = TraderCatalogMerge.merge(
            mockCatalog: Array(mockTraders.prefix(1)),
            serverRows: [
                DiscoverTraderRecord(
                    traderId: "Xy98Zw76Vu",
                    username: "onlyserver",
                    displayName: "Only Server",
                    riskClass: 2,
                    investorCount: 1,
                    totalAUM: 500,
                    acceptingInvestments: true
                )
            ]
        )
        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.contains { $0.username == "onlyserver" && $0.parseUserId == "Xy98Zw76Vu" })
        XCTAssertTrue(merged.contains { $0.username == "onlyserver" && $0.demoMetrics == nil })
    }

    func testMockCatalogFlag() {
        XCTAssertTrue(InvestorTrader(mock: mockTraders[0]).isFromMockCatalog)
        let synthetic = TraderCatalogMerge.merge(
            mockCatalog: [],
            serverRows: [
                DiscoverTraderRecord(
                    traderId: "Ab12Cd34Ef",
                    username: "newone",
                    displayName: nil,
                    riskClass: nil,
                    investorCount: nil,
                    totalAUM: nil,
                    acceptingInvestments: nil
                )
            ]
        )[0]
        XCTAssertFalse(synthetic.isFromMockCatalog)
    }
}
