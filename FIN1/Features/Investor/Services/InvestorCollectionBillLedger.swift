import Foundation
import os

// MARK: - Collection Bill Ledger (single accounting identity)

/// Canonical buy/sell/profit identity for investor collection bills.
/// All displayed amounts must come from one ledger instance per trade line.
struct InvestorCollectionBillLedger: Equatable, Sendable {

    /// Securities buy amount (excluding fees).
    let buyAmount: Double
    /// Buy-side fees (non-negative cash outflow magnitude stored as positive addend to cost).
    let buyFees: Double
    /// Securities sell amount (excluding fees).
    let sellAmount: Double
    /// Sell-side fees as **signed cash flow** (zero or negative).
    let sellFeesSigned: Double

    var totalBuyCost: Double { self.buyAmount + self.buyFees }

    var netSellAmount: Double { self.sellAmount + self.sellFeesSigned }

    var grossProfit: Double { self.netSellAmount - self.totalBuyCost }

    /// Builds a ledger from backend leg magnitudes (fees stored as positive `totalFees`).
    static func fromBackendLegs(
        buyAmount: Double,
        buyFees: Double,
        sellAmount: Double,
        sellFeesMagnitude: Double
    ) -> InvestorCollectionBillLedger {
        InvestorCollectionBillLedger(
            buyAmount: buyAmount,
            buyFees: max(0, buyFees),
            sellAmount: sellAmount,
            sellFeesSigned: Self.signedSellFeesCashFlow(sellFeesMagnitude)
        )
    }

    /// Builds a ledger from local invoice-derived amounts (sell fees may be unsigned).
    static func fromLocalAmounts(
        buyAmount: Double,
        buyFees: Double,
        sellAmount: Double,
        sellFees: Double
    ) -> InvestorCollectionBillLedger {
        InvestorCollectionBillLedger(
            buyAmount: buyAmount,
            buyFees: max(0, buyFees),
            sellAmount: sellAmount,
            sellFeesSigned: Self.signedSellFeesCashFlow(sellFees)
        )
    }

    static func signedSellFeesCashFlow(_ raw: Double) -> Double {
        if abs(raw) < 0.000_000_1 { return 0 }
        return raw > 0 ? -raw : raw
    }

    /// Magnitude shown in the „Sell Fees“ total row.
    var sellFeesDisplayMagnitude: Double { abs(self.sellFeesSigned) }
}

// MARK: - Data source

enum InvestorCollectionBillDataSource: String, Sendable {
    /// Parsed from archived `investorCollectionBill` metadata (booked amounts).
    case backendBeleg
    /// Same as backendBeleg but summary totals diverge from legs (defective Beleg).
    case backendBelegInconsistent
    /// ADR-009: Beleg exists but `buyLeg` / `sellLeg` await server backfill.
    case serverLegsPending
    /// Local invoice + capital solver (no bill on server).
    case localInvoices
    /// Local solver after backend fetch failed (no bill could be loaded).
    case localFallbackAfterBackendError
}

// MARK: - GoB Beleg reconciliation

/// Summary fields stored on the investor collection bill (`Document.metadata`).
struct InvestorCollectionBillBelegTotals: Equatable, Sendable {
    let grossProfit: Double?
    let commission: Double?
    let netProfit: Double?
    let totalBuyCost: Double?
    let netSellAmount: Double?
    let transferAmount: Double?
    let residualAmount: Double?

    static func from(metadata: BackendCollectionBillMetadata) -> InvestorCollectionBillBelegTotals {
        InvestorCollectionBillBelegTotals(
            grossProfit: metadata.grossProfit?.doubleValue,
            commission: metadata.commission?.doubleValue,
            netProfit: metadata.netProfit?.doubleValue,
            totalBuyCost: metadata.totalBuyCost?.doubleValue,
            netSellAmount: metadata.netSellAmount?.doubleValue,
            transferAmount: metadata.transferAmount?.doubleValue,
            residualAmount: metadata.residualAmount?.doubleValue
                ?? metadata.buyLeg?.residualAmount?.doubleValue
        )
    }
}

/// Reconciles leg detail with booked summary on the same Beleg (GoB: „keine Buchung ohne Beleg“).
struct InvestorCollectionBillBelegReconciliation: Equatable, Sendable {
    static let amountTolerance: Double = 0.02

    let ledgerFromLegs: InvestorCollectionBillLedger
    let beleg: InvestorCollectionBillBelegTotals
    let isConsistent: Bool
    /// German user-facing hint when `isConsistent` is false.
    let inconsistencyMessage: String?

    var displayTotalBuyCost: Double { self.beleg.totalBuyCost ?? self.ledgerFromLegs.totalBuyCost }
    var displayNetSellAmount: Double { self.beleg.netSellAmount ?? self.ledgerFromLegs.netSellAmount }
    /// Booked gross profit on the Beleg (not client-derived when metadata present).
    var displayGrossProfit: Double { self.beleg.grossProfit ?? self.ledgerFromLegs.grossProfit }
    var displayTransferAmount: Double? { self.beleg.transferAmount }
    var displayResidualAmount: Double? { self.beleg.residualAmount }

    static func reconcile(
        ledgerFromLegs: InvestorCollectionBillLedger,
        metadata: BackendCollectionBillMetadata
    ) -> InvestorCollectionBillBelegReconciliation {
        let beleg = InvestorCollectionBillBelegTotals.from(metadata: metadata)
        var driftParts: [String] = []
        let tol = Self.amountTolerance

        if let booked = beleg.grossProfit, abs(booked - ledgerFromLegs.grossProfit) > tol {
            driftParts.append(
                String(format: "Gross Profit Beleg %.2f ≠ Legs %.2f", booked, ledgerFromLegs.grossProfit)
            )
        }
        if let booked = beleg.totalBuyCost, abs(booked - ledgerFromLegs.totalBuyCost) > tol {
            driftParts.append(
                String(format: "Total Buy Cost Beleg %.2f ≠ Legs %.2f", booked, ledgerFromLegs.totalBuyCost)
            )
        }
        if let booked = beleg.netSellAmount, abs(booked - ledgerFromLegs.netSellAmount) > tol {
            driftParts.append(
                String(format: "Net Sell Amount Beleg %.2f ≠ Legs %.2f", booked, ledgerFromLegs.netSellAmount)
            )
        }
        if let bookedGross = beleg.grossProfit {
            let implied = beleg.netSellAmount ?? ledgerFromLegs.netSellAmount
            let impliedBuy = beleg.totalBuyCost ?? ledgerFromLegs.totalBuyCost
            if abs(bookedGross - (implied - impliedBuy)) > tol {
                driftParts.append("Beleg-Identität Gross ≠ Net Sell − Total Buy Cost")
            }
        }
        if let transfer = beleg.transferAmount,
           let netSell = beleg.netSellAmount,
           let comm = beleg.commission {
            if abs(transfer - (netSell - comm)) > tol {
                driftParts.append(
                    String(format: "Überweisungsbetrag Beleg %.2f ≠ Net Sell − Commission", transfer)
                )
            }
        }
        if let residual = beleg.residualAmount,
           let buyCost = beleg.totalBuyCost,
           let nominal = metadata.investmentNominal?.doubleValue, nominal > 0 {
            if abs(nominal - (buyCost + residual)) > tol {
                driftParts.append(
                    String(format: "Nominal %.2f ≠ Total Buy Cost + Residual (Beleg)", nominal)
                )
            }
        }

        let isConsistent = driftParts.isEmpty
        let message: String? = isConsistent
            ? nil
            : "Beleg inkonsistent (Buchungsbeleg prüfen): \(driftParts.joined(separator: "; "))"

        if !isConsistent {
            InvestorCollectionBillLog.warning(message ?? "Beleg inconsistent")
        }

        return InvestorCollectionBillBelegReconciliation(
            ledgerFromLegs: ledgerFromLegs,
            beleg: beleg,
            isConsistent: isConsistent,
            inconsistencyMessage: message
        )
    }
}

enum InvestorCollectionBillBelegError: Error, LocalizedError {
    case serverBelegUnmappable(documentNumber: String?)

    var errorDescription: String? {
        switch self {
        case .serverBelegUnmappable(let number):
            if let number {
                return "Collection Bill \(number) auf dem Server ist unvollständig (fehlende Belegpositionen)."
            }
            return "Collection Bill auf dem Server ist unvollständig (fehlende Belegpositionen)."
        }
    }
}

// MARK: - Backend bill index

enum InvestorCollectionBillBackendIndex {
    /// Newest bill per `tradeId` (API returns `createdAt` descending).
    static func billsByTradeId(_ bills: [BackendCollectionBill]) -> [String: BackendCollectionBill] {
        var index: [String: BackendCollectionBill] = [:]
        for bill in bills {
            guard let tradeId = bill.tradeId, !tradeId.isEmpty, index[tradeId] == nil else { continue }
            index[tradeId] = bill
        }
        return index
    }
}

// MARK: - Logging

enum InvestorCollectionBillLog {
    private static let log = Logger(subsystem: "com.fin1.app", category: "InvestorCollectionBill")

    static func debug(_ message: String) {
        #if DEBUG
        self.log.debug("\(message, privacy: .public)")
        #endif
    }

    static func warning(_ message: String) {
        self.log.warning("\(message, privacy: .public)")
    }
}
