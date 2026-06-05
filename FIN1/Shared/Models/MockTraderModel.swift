import Foundation
import SwiftUI

// MARK: - Mock Trader Model
/// Core model representing a mock trader with basic properties and risk level
struct MockTrader: Identifiable {
    let id: UUID
    /// Backing storage for `parseUserId` (see `MockTrader+ParseIdentity.swift`).
    let _parseUserId: String?
    let name: String
    let username: String
    let specialization: String
    let experienceYears: Int
    let isVerified: Bool
    let performance: Double
    let totalTrades: Int
    let winRate: Double
    let averageReturn: Double
    let totalReturn: Double
    let riskLevel: RiskLevel
    let recentTrades: [MockTradePerformance]
    let lastNTrades: Int
    let successfulTradesInLastN: Int
    let averageReturnLastNTrades: Double
    let consecutiveWinningTrades: Int
    let maxDrawdown: Double
    let sharpeRatio: Double

    // Default initializer with random UUID
    init(
        parseUserId: String? = nil,
        name: String,
        username: String,
        specialization: String,
        experienceYears: Int,
        isVerified: Bool,
        performance: Double,
        totalTrades: Int,
        winRate: Double,
        averageReturn: Double,
        totalReturn: Double,
        riskLevel: RiskLevel,
        recentTrades: [MockTradePerformance],
        lastNTrades: Int,
        successfulTradesInLastN: Int,
        averageReturnLastNTrades: Double,
        consecutiveWinningTrades: Int,
        maxDrawdown: Double,
        sharpeRatio: Double
    ) {
        self.id = UUID()
        self._parseUserId = parseUserId
        self.name = name
        self.username = username
        self.specialization = specialization
        self.experienceYears = experienceYears
        self.isVerified = isVerified
        self.performance = performance
        self.totalTrades = totalTrades
        self.winRate = winRate
        self.averageReturn = averageReturn
        self.totalReturn = totalReturn
        self.riskLevel = riskLevel
        self.recentTrades = recentTrades
        self.lastNTrades = lastNTrades
        self.successfulTradesInLastN = successfulTradesInLastN
        self.averageReturnLastNTrades = averageReturnLastNTrades
        self.consecutiveWinningTrades = consecutiveWinningTrades
        self.maxDrawdown = maxDrawdown
        self.sharpeRatio = sharpeRatio
    }

    // Custom initializer with specific ID
    init(
        id: UUID,
        parseUserId: String? = nil,
        name: String,
        username: String,
        specialization: String,
        experienceYears: Int,
        isVerified: Bool,
        performance: Double,
        totalTrades: Int,
        winRate: Double,
        averageReturn: Double,
        totalReturn: Double,
        riskLevel: RiskLevel,
        recentTrades: [MockTradePerformance],
        lastNTrades: Int,
        successfulTradesInLastN: Int,
        averageReturnLastNTrades: Double,
        consecutiveWinningTrades: Int,
        maxDrawdown: Double,
        sharpeRatio: Double
    ) {
        self.id = id
        self._parseUserId = parseUserId
        self.name = name
        self.username = username
        self.specialization = specialization
        self.experienceYears = experienceYears
        self.isVerified = isVerified
        self.performance = performance
        self.totalTrades = totalTrades
        self.winRate = winRate
        self.averageReturn = averageReturn
        self.totalReturn = totalReturn
        self.riskLevel = riskLevel
        self.recentTrades = recentTrades
        self.lastNTrades = lastNTrades
        self.successfulTradesInLastN = successfulTradesInLastN
        self.averageReturnLastNTrades = averageReturnLastNTrades
        self.consecutiveWinningTrades = consecutiveWinningTrades
        self.maxDrawdown = maxDrawdown
        self.sharpeRatio = sharpeRatio
    }
}

// MARK: - Risk Level (shared with InvestorTrader)
extension MockTrader {
    typealias RiskLevel = TraderRiskLevel
}

// MARK: - Mock Instrument Model
/// Model representing a mock financial instrument
struct MockInstrument: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let currentPrice: Double
    let changePercent: Double
    let volume: Int
    let isFavorite: Bool
}
