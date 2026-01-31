import SwiftUI

// MARK: - Mock Data Models

struct MockActiveInvestment: Identifiable {
    let id = UUID()
    let traderUsername: String // Changed from traderName to traderUsername
    let specialization: String
    let amount: Double
    let numberOfTrades: Int
    let completedTrades: Int
    let status: InvestmentStatus
    let pnl: Double
}

struct MockCompletedInvestment: Identifiable {
    let id = UUID()
    let traderUsername: String // Changed from traderName to traderUsername
    let specialization: String
    let initialAmount: Double
    let totalTrades: Int
    let finalPnl: Double
    let roi: Double
    let completedDate: Date
}

struct MockInvestmentHistory: Identifiable {
    let id = UUID()
    let traderUsername: String // Changed from traderName to traderUsername
    let action: String
    let amount: Double
    let date: Date
}

// MARK: - Mock Data (Empty for clean testing)

let mockActiveInvestments: [MockActiveInvestment] = [] // Empty array for clean testing

let mockCompletedInvestments: [MockCompletedInvestment] = [] // Empty array for clean testing

let mockInvestmentHistory: [MockInvestmentHistory] = [] // Empty array for clean testing
