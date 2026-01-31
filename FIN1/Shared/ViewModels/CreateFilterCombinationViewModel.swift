import Foundation

// MARK: - Create Filter Combination View Model
/// Shared ViewModel for creating filter combinations following MVVM architecture
@MainActor
final class CreateFilterCombinationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var combinationName: String = "" {
        didSet {
            // Sanitize input: limit to 20 characters and only alphanumeric
            let sanitized = sanitizeInput(combinationName)
            if sanitized != combinationName {
                combinationName = sanitized
            }
        }
    }

    // MARK: - Computed Properties

    var canSave: Bool {
        let trimmedName = combinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty &&
               trimmedName.count <= 20 &&
               trimmedName.allSatisfy { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }

    var characterCount: Int {
        combinationName.count
    }

    var isNameTooLong: Bool {
        combinationName.count > 20
    }

    var hasInvalidCharacters: Bool {
        let trimmedName = combinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedName.allSatisfy { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }

    // MARK: - Private Methods

    /// Sanitizes input to only allow letters, numbers, and spaces, max 20 characters
    private func sanitizeInput(_ input: String) -> String {
        String(input.prefix(20).filter { $0.isLetter || $0.isNumber || $0.isWhitespace })
    }
}
