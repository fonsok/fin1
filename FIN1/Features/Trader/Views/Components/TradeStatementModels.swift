import Foundation

// MARK: - Trade Statement Models
/// Shared models for trade statement components

// MARK: - Fee Item Model
struct FeeItem {
    let name: String
    let amount: String
}

// MARK: - Tax Item Model
struct TaxItem {
    let name: String
    let basis: String
    let rate: String
    let amount: String
}
