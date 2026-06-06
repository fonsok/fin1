@testable import FIN1
import XCTest

final class TraderPairedBuyPlacementGuardTests: XCTestCase {

    func testAllowsTraderOnlyWhenNoPoolCapitalAndBackendHealthy() async {
        let reason = await TraderPairedBuyPlacementGuard.blockReason(
            mirrorPoolQuantity: 0,
            localReservedPoolCapital: 0,
            parseAPIClient: MockParseAPIClient(),
            investmentAPIService: StubInvestmentAPIService(reservedTotal: 0),
            traderId: "trader-1",
            traderUsername: nil,
            traderName: nil
        )
        XCTAssertNil(reason)
    }

    func testBlocksTraderOnlyWhenLocalPoolCapitalPresent() async {
        let reason = await TraderPairedBuyPlacementGuard.blockReason(
            mirrorPoolQuantity: 0,
            localReservedPoolCapital: 1_000,
            parseAPIClient: MockParseAPIClient(),
            investmentAPIService: StubInvestmentAPIService(reservedTotal: 0),
            traderId: "trader-1",
            traderUsername: nil,
            traderName: nil
        )
        XCTAssertEqual(reason, .staleLocalPoolState(1_000))
    }

    func testBlocksTraderOnlyWhenServerReportsReservedPoolCapital() async {
        let reason = await TraderPairedBuyPlacementGuard.blockReason(
            mirrorPoolQuantity: 0,
            localReservedPoolCapital: 0,
            parseAPIClient: MockParseAPIClient(),
            investmentAPIService: StubInvestmentAPIService(reservedTotal: 2_500),
            traderId: "trader-1",
            traderUsername: nil,
            traderName: nil
        )
        XCTAssertEqual(reason, .serverReservedPoolCapital(2_500))
    }

    func testSkipsGuardWhenMirrorPoolQuantityPositive() async {
        let reason = await TraderPairedBuyPlacementGuard.blockReason(
            mirrorPoolQuantity: 500,
            localReservedPoolCapital: 1_000,
            parseAPIClient: MockParseAPIClient(),
            investmentAPIService: StubInvestmentAPIService(reservedTotal: 2_500),
            traderId: "trader-1",
            traderUsername: nil,
            traderName: nil
        )
        XCTAssertNil(reason)
    }
}

private final class StubInvestmentAPIService: InvestmentAPIServiceProtocol, @unchecked Sendable {
    let reservedTotal: Double

    init(reservedTotal: Double) {
        self.reservedTotal = reservedTotal
    }

    func saveInvestment(_ investment: Investment) async throws -> Investment { investment }
    func saveInvestmentSplits(_ investments: [Investment], traderUsername: String?) async throws -> [Investment] {
        investments
    }
    func updateInvestment(_ investment: Investment) async throws -> Investment { investment }
    func fetchInvestments(forInvestorIds investorIds: [String]) async throws -> [Investment] { [] }
    func fetchInvestments(for investorId: String) async throws -> [Investment] { [] }
    func fetchInvestments(forTraderIds traderIds: [String]) async throws -> [Investment] { [] }
    func createPoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation {
        participation
    }
    func updatePoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation {
        participation
    }
    func cancelReservedInvestment(investmentId: String) async throws {}
    func activateReservedInvestment(investmentId: String) async throws {}
    func bookAppServiceCharge(investmentId: String) async throws -> String { investmentId }
    func fetchPoolMirrorCapacity(
        traderId: String,
        traderUsername: String?,
        traderName: String?,
        additionalAmount: Double
    ) async throws -> PoolMirrorCapacityStatus {
        PoolMirrorCapacityStatus(
            capEnabled: false,
            maxAmount: 0,
            reservedTotal: self.reservedTotal,
            remainingCapacity: nil,
            maxInvestableAmountForNextTrade: nil,
            minInvestment: nil,
            poolUtilizationRatio: nil,
            isPoolNearlyFull: false,
            isFull: false,
            wouldExceed: false,
            alertSubscribed: false
        )
    }
    func setPoolMirrorCapacityAlert(
        traderId: String,
        traderUsername: String?,
        traderName: String?,
        enabled: Bool
    ) async throws {}
}
