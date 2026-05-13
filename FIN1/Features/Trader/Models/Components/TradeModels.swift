import Foundation
import SwiftUI

// MARK: - Mock Data Models

struct MockActiveOrder: Identifiable {
    let id = UUID()
    let symbol: String
    let type: String // Simplified to String
    let quantity: Int
    let price: Double
    let totalAmount: Double
    let status: String // Simplified to String
    let currentPnl: Double
    let durationDays: Int
}

struct MockCompletedTrade: Identifiable {
    let id = UUID()
    let symbol: String
    let buyOrder: MockOrderBuy // Use simplified mock type
    let sellOrder: MockOrderSell? // Use simplified mock type
    let entryPrice: Double
    let exitPrice: Double
    let quantity: Int
    let finalPnl: Double
    let roi: Double
    let completedDate: Date
}

struct MockOrder: Identifiable {
    let id = UUID()
    let symbol: String
    let type: String // Simplified to String
    let quantity: Int
    let price: Double
    let totalAmount: Double
    let status: String // Simplified to String
    let timestamp: Date
}

// MARK: - Simplified Mock Order Types

struct MockOrderBuy: Identifiable {
    let id = UUID()
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: Date
    let executedAt: Date?
    let confirmedAt: Date?
    let updatedAt: Date
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
}

struct MockOrderSell: Identifiable {
    let id = UUID()
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: Date
    let executedAt: Date?
    let confirmedAt: Date?
    let updatedAt: Date
}

// MARK: - Mock Data

let mockActiveOrders: [MockActiveOrder] = []

let mockCompletedTrades: [MockCompletedTrade] = []

let mockOrders: [MockOrder] = []
