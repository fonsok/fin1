import Foundation

struct Investment: Identifiable, Codable, Sendable {
    let id: String
    let investmentNumber: String?
    let batchId: String? // Optional: groups investments created together
    let investorId: String
    let investorName: String // Investor's username for display in trader views
    let traderId: String
    let traderName: String
    let amount: Double // Capital allocated to this investment (pool)
    let currentValue: Double // Current value including profit
    let date: Date
    let status: InvestmentStatus
    let performance: Double // Return percentage
    let numberOfTrades: Int
    let sequenceNumber: Int? // Optional: sequence number within batch (for display, e.g., "Investment #1")
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let specialization: String
    // Investment reservation status tracking
    var reservationStatus: InvestmentReservationStatus // Status of this individual investment
    let partialSellCount: Int
    let realizedSellQuantity: Double
    let realizedSellAmount: Double
    let lastPartialSellAt: Date?
    /// Kumulativ verkaufte Stückzahl / Kaufstück am Trade (0…1), vom Server; identisch für alle Pool-Investoren eines Trades.
    let tradeSellVolumeProgress: Double?

    // Computed properties
    var investedAmount: Double {
        amount
    }

    var isActive: Bool {
        status == .active
    }

    var isCompleted: Bool {
        status == .completed
    }

    /// Checks if this investment is completed
    var isInvestmentCompleted: Bool {
        reservationStatus == .completed
    }

    /// Checks if this investment is active
    var isInvestmentActive: Bool {
        reservationStatus == .active || reservationStatus == .executing || reservationStatus == .closed
    }

    /// Trash/delete allowed only while reserved (not yet committed to an ongoing trade path).
    /// App service charge for the batch is never refunded when deleting a split.
    var canBeDeleted: Bool {
        reservationStatus == .reserved
    }

    /// Mindestens ein Teil-Verkauf am laufenden Trade (serverseitig in `trade.js` gesetzt).
    /// `tradeSellVolumeProgress` ziehen wir mit ein, falls ältere/konkurrierende Payloads Zähler/Erlös noch 0 liefern.
    var hasPartialSellRealization: Bool {
        let progress = tradeSellVolumeProgress ?? 0
        return partialSellCount > 0
            || realizedSellQuantity > 0
            || realizedSellAmount > 0
            || progress > 0.000_000_1
    }

    /// Anteil des auf den Investor umgelegten **Brutto-Verkaufserlöses** am **gebundenen Einlagekapital**
    /// (`realizedSellAmount / amount`). Bei Gewinn im Teilverkauf oft **höher** als der reine Stück-Anteil am Trade,
    /// weil der Erlös über Kostenbasis und Gewinnanteil läuft — vergleiche `tradeSellVolumeProgressPercent`.
    var realizedSellSharePercentage: Double {
        guard amount > 0 else { return 0 }
        return (realizedSellAmount / amount) * 100
    }

    /// Kumulativ: verkaufte Stück / Kaufstück am Trade in Prozent (z. B. 20 bei 200/1000), wenn vom Server gesetzt.
    var tradeSellVolumeProgressPercent: Double? {
        guard let tradeSellVolumeProgress else { return nil }
        return tradeSellVolumeProgress * 100
    }

    init(
        id: String,
        investmentNumber: String? = nil,
        batchId: String?,
        investorId: String,
        investorName: String,
        traderId: String,
        traderName: String,
        amount: Double,
        currentValue: Double,
        date: Date,
        status: InvestmentStatus,
        performance: Double,
        numberOfTrades: Int,
        sequenceNumber: Int?,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?,
        specialization: String,
        reservationStatus: InvestmentReservationStatus,
        partialSellCount: Int = 0,
        realizedSellQuantity: Double = 0,
        realizedSellAmount: Double = 0,
        lastPartialSellAt: Date? = nil,
        tradeSellVolumeProgress: Double? = nil
    ) {
        self.id = id
        self.investmentNumber = investmentNumber
        self.batchId = batchId
        self.investorId = investorId
        self.investorName = investorName
        self.traderId = traderId
        self.traderName = traderName
        self.amount = amount
        self.currentValue = currentValue
        self.date = date
        self.status = status
        self.performance = performance
        self.numberOfTrades = numberOfTrades
        self.sequenceNumber = sequenceNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.specialization = specialization
        self.reservationStatus = reservationStatus
        self.partialSellCount = partialSellCount
        self.realizedSellQuantity = realizedSellQuantity
        self.realizedSellAmount = realizedSellAmount
        self.lastPartialSellAt = lastPartialSellAt
        self.tradeSellVolumeProgress = tradeSellVolumeProgress
    }

    /// Canonical human-readable reference for a split investment.
    /// Format keeps labels readable while collision-safe across batches.
    /// Preferred: "INV-<BATCH12>-<SPLIT>-<UNIQ4>", fallback: "INV-<SHORT-ID>-<SPLIT>".
    var canonicalDisplayReference: String {
        if let investmentNumber, !investmentNumber.isEmpty {
            return investmentNumber
        }
        let split = String(format: "%02d", sequenceNumber ?? 1)
        if let batchId, !batchId.isEmpty {
            let normalizedBatch = batchId.uppercased()
            let batchPrefix = String(normalizedBatch.prefix(12))
            let uniqueSuffix = String(normalizedBatch.suffix(4))
            return "INV-\(batchPrefix)-\(split)-\(uniqueSuffix)"
        }
        return "INV-\(id.extractInvestmentNumber().uppercased())-\(split)"
    }

    /// Creates a new Investment with updated status and completedAt date
    /// Optionally updates currentValue and performance if provided
    func markAsCompleted(
        calculatedProfit: Double? = nil,
        calculatedReturn: Double? = nil
    ) -> Investment {
        // Calculate profit and return if not provided
        let profit: Double
        let returnPercentage: Double

        if let calculatedProfit = calculatedProfit, let calculatedReturn = calculatedReturn {
            // Use provided values
            profit = calculatedProfit
            // calculatedReturn is already a percentage (e.g., 98.10) from calculateReturnPercentage()
            // No need to multiply by 100 again
            returnPercentage = calculatedReturn
        } else {
            // Fallback: use a reasonable return rate
            let baseReturnRate = 0.05 // 5% base return (as decimal)
            returnPercentage = baseReturnRate * 100 // Convert to percentage for storage
            profit = amount * baseReturnRate
        }

        // Calculate new current value (original amount + profit)
        let newCurrentValue = amount + profit

        return Investment(
            id: id,
            investmentNumber: investmentNumber,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: newCurrentValue,
            date: date,
            status: .completed,
            performance: returnPercentage, // Already a percentage value (e.g., 98.10)
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: Date(),
            specialization: specialization,
            reservationStatus: .completed,
            partialSellCount: partialSellCount,
            realizedSellQuantity: realizedSellQuantity,
            realizedSellAmount: realizedSellAmount,
            lastPartialSellAt: lastPartialSellAt,
            tradeSellVolumeProgress: tradeSellVolumeProgress
        )
    }

    /// Creates a new Investment marked as cancelled (no profit/return)
    func markAsCancelled() -> Investment {
        return Investment(
            id: id,
            investmentNumber: investmentNumber,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: amount, // no profit impact
            date: date,
            status: .cancelled,
            performance: 0.0, // will be displayed as '---'
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: Date(),
            specialization: specialization,
            reservationStatus: .cancelled,
            partialSellCount: partialSellCount,
            realizedSellQuantity: realizedSellQuantity,
            realizedSellAmount: realizedSellAmount,
            lastPartialSellAt: lastPartialSellAt,
            tradeSellVolumeProgress: tradeSellVolumeProgress
        )
    }

    /// Marks this investment as active
    func markInvestmentAsActive() -> Investment {
        return Investment(
            id: id,
            investmentNumber: investmentNumber,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: currentValue,
            date: date,
            status: .active,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: completedAt,
            specialization: specialization,
            reservationStatus: .active,
            partialSellCount: partialSellCount,
            realizedSellQuantity: realizedSellQuantity,
            realizedSellAmount: realizedSellAmount,
            lastPartialSellAt: lastPartialSellAt,
            tradeSellVolumeProgress: tradeSellVolumeProgress
        )
    }

    /// Marks this investment as completed
    func markInvestmentAsCompleted() -> Investment {
        return Investment(
            id: id,
            investmentNumber: investmentNumber,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: currentValue,
            date: date,
            status: .completed,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: completedAt ?? Date(),
            specialization: specialization,
            reservationStatus: .completed,
            partialSellCount: partialSellCount,
            realizedSellQuantity: realizedSellQuantity,
            realizedSellAmount: realizedSellAmount,
            lastPartialSellAt: lastPartialSellAt,
            tradeSellVolumeProgress: tradeSellVolumeProgress
        )
    }

    // MARK: - Static Methods

    static func validateInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        minimumInvestmentPerSlot: Double,
        maximumInvestmentPerSlot: Double
    ) -> InvestmentValidationError? {
        // 1. Prevent traders from investing in other traders
        if investor.role == .trader {
            return .traderCannotInvestInTrader
        }

        // 2. Validate amount
        if amountPerInvestment <= 0 {
            return .invalidAmount
        }

        // 3. Validate number of investments
        if numberOfInvestments <= 0 {
            return .invalidNumberOfInvestments
        }

        // 4. Per-slot limits from admin configuration (getConfig limits)
        let minSlot = min(minimumInvestmentPerSlot, maximumInvestmentPerSlot)
        let maxSlot = max(minimumInvestmentPerSlot, maximumInvestmentPerSlot)
        if amountPerInvestment < minSlot {
            return .minimumAmountNotMet
        }
        if amountPerInvestment > maxSlot {
            return .maximumAmountExceeded
        }

        return nil
    }

    /// Creates a single investment - each investment is a first-class entity
    static func createInvestment(
        investor: User,
        trader: MockTrader,
        amount: Double,
        batchId: String?,
        sequenceNumber: Int?,
        specialization: String,
        minimumInvestmentPerSlot: Double,
        maximumInvestmentPerSlot: Double
    ) throws -> Investment {
        // Validate the investment
        if let error = validateInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amount,
            numberOfInvestments: 1, // Each investment is a single investment
            minimumInvestmentPerSlot: minimumInvestmentPerSlot,
            maximumInvestmentPerSlot: maximumInvestmentPerSlot
        ) {
            throw error
        }

        return Investment(
            id: UUID().uuidString,
            investmentNumber: nil,
            batchId: batchId,
            investorId: investor.id,
            investorName: investor.username,
            traderId: trader.id.uuidString,
            traderName: trader.name,
            amount: amount,
            currentValue: amount,
            date: Date(),
            status: .active,
            performance: 0.0,
            numberOfTrades: 0,
            sequenceNumber: sequenceNumber,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: specialization,
            reservationStatus: .reserved
        )
    }

    /// Creates multiple investments from a batch
    static func createInvestmentsFromBatch(
        investor: User,
        trader: MockTrader,
        batchId: String,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        minimumInvestmentPerSlot: Double,
        maximumInvestmentPerSlot: Double
    ) throws -> [Investment] {
        // Validate the batch
        if let error = validateInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            minimumInvestmentPerSlot: minimumInvestmentPerSlot,
            maximumInvestmentPerSlot: maximumInvestmentPerSlot
        ) {
            throw error
        }

        // Create one investment per requested amount
        var investments: [Investment] = []
        for sequenceNumber in 1...numberOfInvestments {
            let investment = try createInvestment(
                investor: investor,
                trader: trader,
                amount: amountPerInvestment,
                batchId: batchId,
                sequenceNumber: sequenceNumber,
                specialization: specialization,
                minimumInvestmentPerSlot: minimumInvestmentPerSlot,
                maximumInvestmentPerSlot: maximumInvestmentPerSlot
            )
            investments.append(investment)
        }

        return investments
    }
}
