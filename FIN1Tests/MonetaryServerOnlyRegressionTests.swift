import Combine
@testable import FIN1
import XCTest

/// Guards prod monetary SSOT policy defaults (ADR-019 roadmap).
final class MonetaryServerOnlyRegressionTests: XCTestCase {

    func testAppConfigurationDefaultsPreferServerOnlyMonetaryPaths() {
        let config = AppConfiguration.default
        XCTAssertTrue(config.effectiveInvestorMonetaryServerOnly)
        XCTAssertTrue(config.effectiveCollectionBillServerLegs)
        XCTAssertTrue(config.effectiveTraderMonetaryServerOnly)
    }

    func testMonetaryServerOnlyPolicyBlocksLocalInvoiceSynthesisInProdDefaults() {
        let config = ProdMonetaryConfigurationStub()
        XCTAssertTrue(config.traderStatementServerOnly)
        XCTAssertTrue(config.blocksLocalInvoiceGeneration)
        XCTAssertTrue(config.investorStatementServerOnly)
    }

    func testInvestorCollectionBillBackendPathRejectsLocalRecomputeWhenServerOnly() async {
        let service = InvestorCollectionBillCalculationService()
        let input = InvestorCollectionBillInput(
            investmentCapital: 1_000,
            buyPrice: 10,
            tradeTotalQuantity: 100,
            ownershipPercentage: 0.1,
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 100
        )

        do {
            _ = try await service.calculateCollectionBillWithBackend(
                input: input,
                settlementAPIService: nil,
                tradeId: "trade-1",
                investmentId: "inv-1",
                preloadedBill: nil,
                monetaryServerOnly: true,
                collectionBillServerLegs: true,
                billResolvedFromPrefetchIndex: false
            )
            XCTFail("Expected server-only rejection")
        } catch is InvestorMonetaryServerOnlyError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvestorCollectionBillBackendPathReturnsPendingWhenServerLegsIncomplete() async throws {
        let service = InvestorCollectionBillCalculationService()
        let input = InvestorCollectionBillInput(
            investmentCapital: 1_000,
            buyPrice: 10,
            tradeTotalQuantity: 100,
            ownershipPercentage: 0.1,
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 100
        )
        let json = """
        {
          "objectId": "doc-1",
          "accountingDocumentNumber": "CB-TEST",
          "metadata": {
            "buyLeg": { "quantity": 10, "price": 10, "amount": 100 },
            "sellLeg": null
          }
        }
        """.data(using: .utf8)!
        let bill = try JSONDecoder().decode(BackendCollectionBill.self, from: json)

        let output = try await service.calculateCollectionBillWithBackend(
            input: input,
            settlementAPIService: nil,
            tradeId: "trade-1",
            investmentId: "inv-1",
            preloadedBill: bill,
            monetaryServerOnly: true,
            collectionBillServerLegs: true,
            billResolvedFromPrefetchIndex: false
        )

        XCTAssertTrue(output.isServerLegsPending)
        XCTAssertEqual(output.accountingDocumentNumber, "CB-TEST")
    }

    func testInvoiceLocalSynthesisGateBlocksProductionSynthesis() {
        XCTAssertFalse(InvoiceLocalSynthesisGate.isPermitted)
    }

    func testInvestorCollectionBillLocalCalculationGateBlocksProductionSynthesis() {
        XCTAssertFalse(InvestorCollectionBillLocalCalculationGate.isPermitted)
    }
}

// MARK: - Prod defaults stub (mirrors Parse `defaultConfig.display`)

private final class ProdMonetaryConfigurationStub: ObservableObject, ConfigurationServiceProtocol, @unchecked Sendable {
    var configurationChanged: AnyPublisher<Void, Never> {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    var minimumCashReserve: Double { 20 }
    var initialAccountBalance: Double { 0 }
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy { .immediateDistribution }
    var poolBalanceDistributionThreshold: Double { 5 }
    var traderCommissionRate: Double { 0.05 }
    var appCommissionRate: Double { 0.05 }
    var investorCommissionRateTotal: Double { 0.1 }
    var appServiceChargeRate: Double { 0.02 }
    var showCommissionBreakdownInCreditNote: Bool { false }
    var maximumRiskExposurePercent: Double { 2 }
    var walletFeatureEnabled: Bool { false }
    var investorMonetaryServerOnly: Bool { true }
    var collectionBillServerLegs: Bool { true }
    var traderMonetaryServerOnly: Bool { true }
    var frontendReadonlyMode: Bool { false }
    var serviceChargeInvoiceFromBackend: Bool { true }
    var serviceChargeLegacyClientFallbackEnabled: Bool { false }
    var slaMonitoringInterval: TimeInterval { 300 }
    var parseServerURL: String? { nil }
    var parseApplicationId: String? { nil }
    var parseLiveQueryURL: String? { nil }

    func updateMinimumCashReserve(_ value: Double) async throws {}
    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws {}
    func getMinimumCashReserve(for userId: String) -> Double { self.minimumCashReserve }
    func updateInitialAccountBalance(_ value: Double) async throws {}
    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws {}
    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws {}
    func updateTraderCommissionRate(_ rate: Double) async throws {}
    func updateShowCommissionBreakdownInCreditNote(_ value: Bool) async throws {}
    func updateMaximumRiskExposurePercent(_ value: Double) async throws {}
    func updateAppServiceChargeRate(_ rate: Double) async throws {}
    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws {}
    func resetToDefaults() async throws {}
    func getPendingConfigurationChanges() async throws -> [PendingConfigurationChange] { [] }

    func validateMinimumCashReserve(_ value: Double) -> Bool { true }
    func validateInitialAccountBalance(_ value: Double) -> Bool { true }
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool { true }
    func validateTraderCommissionRate(_ rate: Double) -> Bool { true }
    func validateMaximumRiskExposurePercent(_ value: Double) -> Bool { true }
    func validateAppServiceChargeRate(_ rate: Double) -> Bool { true }
    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool { true }
}
