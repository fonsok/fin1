import Foundation

// MARK: - Trader Collection Bill Beleg Metadata (Parse `Document.metadata` SSOT)

/// Structured GoB beleg payload from `traderCollectionBillBelegSnapshot` (backend SSOT).
struct TraderCollectionBillBelegMetadata: Codable, Equatable, Hashable, Sendable {
    let belegSchemaVersion: Int?
    let belegKind: String?
    let belegLabel: String?
    let traderId: String?
    let traderDisplayName: String?
    let traderUsername: String?
    let executionType: String?
    let symbol: String?
    let instrumentLine: String?
    let amount: BelegEURMoney?
    let quantity: Double?
    let price: Double?
    let orderId: String?
    let sellOrderId: String?
    let wkn: String?
    let fees: Fees?
    let totalWithFees: BelegEURMoney?
    let valueDate: String?
    let closingDate: String?
    let tradingVenue: String?
    let tradeNumber: Int?
    let tradeStatus: String?
    let generatedAt: String?
    let partialSell: PartialSell?
    /// Trader Gutschrift (CN-): net commission booked on Personenkonto.
    let commissionAmount: Double?
    let commissionRate: Double?
    let grossProfit: Double?
    let netProfit: Double?

    struct Fees: Codable, Equatable, Hashable, Sendable {
        let orderFee: BelegEURMoney?
        let exchangeFee: BelegEURMoney?
        let foreignCosts: BelegEURMoney?
        let totalFees: BelegEURMoney?
    }

    struct PartialSell: Codable, Equatable, Hashable, Sendable {
        let isPartialSell: Bool?
        let soldQuantity: Double?
        let remainingQuantity: Double?
        let buyQuantity: Double?
        let sellOrderId: String?
        let eventIndex: Int?
        let totalSellEvents: Int?
        let executedAt: String?
        let orderQuantity: Double?
        let cumulativeSoldQuantity: Double?
        let sellVolumeProgress: Double?

        var showsProgressSection: Bool {
            self.isPartialSell == true
        }
    }

    private enum CodingKeys: String, CodingKey {
        case belegSchemaVersion
        case belegKind
        case belegLabel
        case traderId
        case traderDisplayName
        case traderUsername
        case executionType
        case symbol
        case instrumentLine
        case amount
        case amountCents
        case quantity
        case price
        case orderId
        case sellOrderId
        case wkn
        case fees
        case totalWithFees
        case totalWithFeesCents
        case valueDate
        case closingDate
        case tradingVenue
        case tradeNumber
        case tradeStatus
        case generatedAt
        case partialSell
        case commissionAmount
        case commissionRate
        case grossProfit
        case netProfit
    }

    init(
        belegSchemaVersion: Int?,
        belegKind: String?,
        belegLabel: String?,
        traderId: String?,
        traderDisplayName: String?,
        traderUsername: String?,
        executionType: String?,
        symbol: String?,
        instrumentLine: String?,
        amount: BelegEURMoney?,
        quantity: Double?,
        price: Double?,
        orderId: String?,
        sellOrderId: String?,
        wkn: String?,
        fees: Fees?,
        totalWithFees: BelegEURMoney?,
        valueDate: String?,
        closingDate: String?,
        tradingVenue: String?,
        tradeNumber: Int?,
        tradeStatus: String?,
        generatedAt: String?,
        partialSell: PartialSell?,
        commissionAmount: Double? = nil,
        commissionRate: Double? = nil,
        grossProfit: Double? = nil,
        netProfit: Double? = nil
    ) {
        self.belegSchemaVersion = belegSchemaVersion
        self.belegKind = belegKind
        self.belegLabel = belegLabel
        self.traderId = traderId
        self.traderDisplayName = traderDisplayName
        self.traderUsername = traderUsername
        self.executionType = executionType
        self.symbol = symbol
        self.instrumentLine = instrumentLine
        self.amount = amount
        self.quantity = quantity
        self.price = price
        self.orderId = orderId
        self.sellOrderId = sellOrderId
        self.wkn = wkn
        self.fees = fees
        self.totalWithFees = totalWithFees
        self.valueDate = valueDate
        self.closingDate = closingDate
        self.tradingVenue = tradingVenue
        self.tradeNumber = tradeNumber
        self.tradeStatus = tradeStatus
        self.generatedAt = generatedAt
        self.partialSell = partialSell
        self.commissionAmount = commissionAmount
        self.commissionRate = commissionRate
        self.grossProfit = grossProfit
        self.netProfit = netProfit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.belegSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .belegSchemaVersion)
        self.belegKind = try container.decodeIfPresent(String.self, forKey: .belegKind)
        self.belegLabel = try container.decodeIfPresent(String.self, forKey: .belegLabel)
        self.traderId = try container.decodeIfPresent(String.self, forKey: .traderId)
        self.traderDisplayName = try container.decodeIfPresent(String.self, forKey: .traderDisplayName)
        self.traderUsername = try container.decodeIfPresent(String.self, forKey: .traderUsername)
        self.executionType = try container.decodeIfPresent(String.self, forKey: .executionType)
        self.symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        self.instrumentLine = try container.decodeIfPresent(String.self, forKey: .instrumentLine)
        self.amount = BelegEURMoney.resolving(
            cents: try container.decodeIfPresent(Int.self, forKey: .amountCents),
            euro: try container.decodeIfPresent(BelegEURMoney.self, forKey: .amount)
        )
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
        self.price = try container.decodeIfPresent(Double.self, forKey: .price)
        self.orderId = try container.decodeIfPresent(String.self, forKey: .orderId)
        self.sellOrderId = try container.decodeIfPresent(String.self, forKey: .sellOrderId)
        self.wkn = try container.decodeIfPresent(String.self, forKey: .wkn)
        self.fees = try container.decodeIfPresent(Fees.self, forKey: .fees)
        self.totalWithFees = BelegEURMoney.resolving(
            cents: try container.decodeIfPresent(Int.self, forKey: .totalWithFeesCents),
            euro: try container.decodeIfPresent(BelegEURMoney.self, forKey: .totalWithFees)
        )
        self.valueDate = try container.decodeIfPresent(String.self, forKey: .valueDate)
        self.closingDate = try container.decodeIfPresent(String.self, forKey: .closingDate)
        self.tradingVenue = try container.decodeIfPresent(String.self, forKey: .tradingVenue)
        self.tradeNumber = try container.decodeIfPresent(Int.self, forKey: .tradeNumber)
        self.tradeStatus = try container.decodeIfPresent(String.self, forKey: .tradeStatus)
        self.generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        self.partialSell = try container.decodeIfPresent(PartialSell.self, forKey: .partialSell)
        self.commissionAmount = try container.decodeIfPresent(Double.self, forKey: .commissionAmount)
        self.commissionRate = try container.decodeIfPresent(Double.self, forKey: .commissionRate)
        self.grossProfit = try container.decodeIfPresent(Double.self, forKey: .grossProfit)
        self.netProfit = try container.decodeIfPresent(Double.self, forKey: .netProfit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.belegSchemaVersion, forKey: .belegSchemaVersion)
        try container.encodeIfPresent(self.belegKind, forKey: .belegKind)
        try container.encodeIfPresent(self.belegLabel, forKey: .belegLabel)
        try container.encodeIfPresent(self.traderId, forKey: .traderId)
        try container.encodeIfPresent(self.traderDisplayName, forKey: .traderDisplayName)
        try container.encodeIfPresent(self.traderUsername, forKey: .traderUsername)
        try container.encodeIfPresent(self.executionType, forKey: .executionType)
        try container.encodeIfPresent(self.symbol, forKey: .symbol)
        try container.encodeIfPresent(self.instrumentLine, forKey: .instrumentLine)
        try container.encodeIfPresent(self.amount, forKey: .amount)
        try container.encodeIfPresent(self.quantity, forKey: .quantity)
        try container.encodeIfPresent(self.price, forKey: .price)
        try container.encodeIfPresent(self.orderId, forKey: .orderId)
        try container.encodeIfPresent(self.sellOrderId, forKey: .sellOrderId)
        try container.encodeIfPresent(self.wkn, forKey: .wkn)
        try container.encodeIfPresent(self.fees, forKey: .fees)
        try container.encodeIfPresent(self.totalWithFees, forKey: .totalWithFees)
        try container.encodeIfPresent(self.valueDate, forKey: .valueDate)
        try container.encodeIfPresent(self.closingDate, forKey: .closingDate)
        try container.encodeIfPresent(self.tradingVenue, forKey: .tradingVenue)
        try container.encodeIfPresent(self.tradeNumber, forKey: .tradeNumber)
        try container.encodeIfPresent(self.tradeStatus, forKey: .tradeStatus)
        try container.encodeIfPresent(self.generatedAt, forKey: .generatedAt)
        try container.encodeIfPresent(self.partialSell, forKey: .partialSell)
        try container.encodeIfPresent(self.commissionAmount, forKey: .commissionAmount)
        try container.encodeIfPresent(self.commissionRate, forKey: .commissionRate)
        try container.encodeIfPresent(self.grossProfit, forKey: .grossProfit)
        try container.encodeIfPresent(self.netProfit, forKey: .netProfit)
    }

    var normalizedExecutionType: String? {
        self.executionType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSell: Bool { self.normalizedExecutionType == "sell" }
    var isBuy: Bool { self.normalizedExecutionType == "buy" }

    /// Minimum fields required to render structured detail without invoice synthesis.
    var isUsableForDisplay: Bool {
        guard self.isBuy || self.isSell else { return false }
        guard let qty = quantity, qty > 0 else { return false }
        guard let amt = amount?.decimal, amt > 0 else { return false }
        return true
    }

    var securityIdentifier: String {
        let line = self.instrumentLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !line.isEmpty { return line }
        let sym = self.symbol?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sym.isEmpty { return sym }
        let w = self.wkn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return w.isEmpty ? "—" : w
    }
}
