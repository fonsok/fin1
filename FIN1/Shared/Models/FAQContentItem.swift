import Foundation

/// Server-driven FAQ item; references its category by `categoryId` (Parse objectId or fallback slug).
struct FAQContentItem: Identifiable, Hashable, Codable {
    let id: String
    let question: String
    let answer: String
    let categoryId: String
    let sortOrder: Int
}

