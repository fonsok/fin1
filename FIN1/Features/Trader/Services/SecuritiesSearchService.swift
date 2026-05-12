import Foundation
import Combine

// MARK: - Search Service Protocol
@MainActor
protocol SecuritiesSearchServiceProtocol: ObservableObject {
    var searchResults: [SearchResult] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    var searchResultsPublisher: AnyPublisher<[SearchResult], Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var errorMessagePublisher: AnyPublisher<String?, Never> { get }

    func performSearch(with filters: SearchFilters) async
}

// MARK: - Search Filters Model
// CRITICAL: This struct defines ALL filter parameters for securities search
// Any changes to this struct must be thoroughly tested to ensure filter logic remains intact
struct SearchFilters: Equatable {
    // Core filters that determine search results
    let category: String                           // Warrant, KO, Inline, etc.
    let underlyingAsset: String                    // FTSE 100, CAC 40, DAX, etc.
    let direction: SecuritiesSearchView.Direction // Call, Put

    // Advanced filters for refined search
    let strikePriceGap: String?                // At the Money, Out of the Money, etc.
    let remainingTerm: String?                     // < 4 Wo., > 1 Jahr, etc.
    let issuer: String?                         // Société Générale, Goldman Sachs, etc.
    let omega: String?                            // > 10, < 5, etc.
}

// MARK: - Search Service Implementation
@MainActor
final class SecuritiesSearchService: SecuritiesSearchServiceProtocol {
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var searchResultsPublisher: AnyPublisher<[SearchResult], Never> { $searchResults.eraseToAnyPublisher() }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }
    var errorMessagePublisher: AnyPublisher<String?, Never> { $errorMessage.eraseToAnyPublisher() }

    nonisolated(unsafe) private let mockDataGenerator: any MockDataGeneratorProtocol

    init(mockDataGenerator: any MockDataGeneratorProtocol) {
        self.mockDataGenerator = mockDataGenerator
    }

    deinit {
        print("🧹 SecuritiesSearchService deallocated")
    }

    // MARK: - Public Interface

    func performSearch(with filters: SearchFilters) async {
        print("🔍 DEBUG: SecuritiesSearchService.performSearch() called")
        print("🔍 DEBUG: filters.underlyingAsset = '\(filters.underlyingAsset)'")
        print("🔍 DEBUG: filters.direction = \(filters.direction)")
        print("🔍 DEBUG: filters.direction.rawValue = \(filters.direction.rawValue)")

        isLoading = true
        errorMessage = nil
        // Clear previous results to prevent showing stale data
        searchResults = []

        do {
            // Validate filters
            try validateFilters(filters)

            // Generate search results based on filters
            let results = try await generateSearchResults(for: filters)
            print("🔍 DEBUG: Generated \(results.count) results")

            // Apply additional filtering
            let filteredResults = applyAdditionalFilters(to: results, filters: filters)
            print("🔍 DEBUG: After filtering: \(filteredResults.count) results")

            // Apply sorting: first by Bewertungstag (earliest first), then by Strike Price (lowest first)
            let sortedResults = sortSearchResults(filteredResults)
            print("🔍 DEBUG: After sorting: \(sortedResults.count) results")

            // Update results
            print("🔍 DEBUG: SecuritiesSearchService updating searchResults with \(sortedResults.count) results")
            if let firstResult = sortedResults.first {
                print("🔍 DEBUG: First result direction: \(firstResult.direction ?? "nil")")
                print("🔍 DEBUG: First result Bewertungstag: \(firstResult.valuationDate)")
                print("🔍 DEBUG: First result Strike Price: \(firstResult.strike)")
            }
            searchResults = sortedResults

        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
            searchResults = []
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func validateFilters(_ filters: SearchFilters) throws {
        guard !filters.category.isEmpty else {
            throw AppError.validationError("Derivate-Kategorie ist erforderlich")
        }

        guard !filters.underlyingAsset.isEmpty else {
            throw AppError.validationError("Underlying asset is required")
        }
    }

    private func generateSearchResults(for filters: SearchFilters) async throws -> [SearchResult] {
        // Use mock data generator to create results
        return try await mockDataGenerator.generateSearchResults(for: filters)
    }

    private func applyAdditionalFilters(to results: [SearchResult], filters: SearchFilters) -> [SearchResult] {
        var filteredResults = results

        // Filter by Remaining Term
        if let selectedTerm = filters.remainingTerm {
            switch selectedTerm {
            case "< 4 Wo.":
                filteredResults = Array(filteredResults.prefix(2))
            case "< 1 Jahr":
                filteredResults = Array(filteredResults.prefix(4))
            default:
                filteredResults = Array(filteredResults.dropLast(1))
            }
        }

        // Filter by Strike Price Gap
        if let selectedGap = filters.strikePriceGap {
            if selectedGap.contains("10%") {
                if !filteredResults.isEmpty {
                    filteredResults = Array(filteredResults.prefix(1))
                }
            }
        }

        // Determine max results based on issuer for better testing
        let maxResults: Int
        if let issuer = filters.issuer {
            // For Vontobel and DZ Bank, allow up to 8 results for better testing
            if issuer == "Vontobel" || issuer == "DZ Bank" {
                maxResults = 8
            } else {
                maxResults = 6
            }
        } else {
            maxResults = 8  // Default to 8 when no specific issuer is selected
        }

        if filteredResults.count > maxResults {
            filteredResults = Array(filteredResults.prefix(maxResults))
        }

        return filteredResults
    }

    private func sortSearchResults(_ results: [SearchResult]) -> [SearchResult] {
        return results.sorted { first, second in
            // Primary sort: By Bewertungstag (valuation date) - earliest first
            let firstDate = parseValuationDate(first.valuationDate)
            let secondDate = parseValuationDate(second.valuationDate)

            if firstDate != secondDate {
                return firstDate < secondDate
            }

            // Secondary sort: By Strike Price - lowest first
            let firstStrike = parseStrikePrice(first.strike)
            let secondStrike = parseStrikePrice(second.strike)

            return firstStrike < secondStrike
        }
    }

    private func parseValuationDate(_ dateString: String) -> Date {
        // Parse German date format "dd.MM.yyyy" (e.g., "31.12.2025")
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.date(from: dateString) ?? Date.distantFuture
    }

    private func parseStrikePrice(_ priceString: String) -> Double {
        // Parse German decimal format (comma as decimal separator) and handle "Pkt." suffix
        var cleanString = priceString.replacingOccurrences(of: " Pkt.", with: "")
        cleanString = cleanString.replacingOccurrences(of: ",", with: ".")
        return Double(cleanString) ?? Double.greatestFiniteMagnitude
    }
}
