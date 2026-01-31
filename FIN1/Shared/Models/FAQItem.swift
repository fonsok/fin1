import Foundation

/// Represents a single FAQ item with question and answer
struct FAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
    let category: FAQCategory
}









