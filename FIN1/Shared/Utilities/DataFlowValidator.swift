import Foundation

// MARK: - Data Flow Validation System
// This system helps catch data flow issues early in development

struct DataFlowValidator {

    // MARK: - Validation Results

    enum ValidationResult {
        case valid
        case warning(String)
        case error(String)
    }

    // MARK: - Search Result Validation

    static func validateSearchResult(_ result: SearchResult, context: String = "") -> ValidationResult {
        var issues: [String] = []

        // Check for required fields
        if result.wkn.isEmpty {
            issues.append("WKN is empty")
        }

        if let direction = result.direction, direction.isEmpty {
            issues.append("Direction is empty")
        }

        // Check for options-specific validation
        if result.category == "Optionsschein" {
            if result.underlyingAsset == nil || (result.underlyingAsset?.isEmpty ?? true) {
                issues.append("Optionsschein missing underlying asset")
            }
        }

        // Check for suspicious defaults
        if result.underlyingAsset == "DAX" && context.contains("non-dax") {
            issues.append("Suspicious DAX default detected")
        }

        if issues.isEmpty {
            return .valid
        } else {
            let message = "SearchResult validation failed\(context.isEmpty ? "" : " in \(context)"): \(issues.joined(separator: ", "))"
            return issues.contains { $0.contains("Suspicious") } ? .warning(message) : .error(message)
        }
    }

    // MARK: - Order Creation Validation

    static func validateOrderCreation(
        searchResult: SearchResult,
        optionDirection: String?,
        underlyingAsset: String?,
        context: String = ""
    ) -> ValidationResult {
        var issues: [String] = []

        // Check if this should be an options order
        let shouldBeOptions = searchResult.category == "Optionsschein"

        if shouldBeOptions {
            // Validate option type consistency
            if let searchDirection = searchResult.direction, optionDirection != searchDirection {
                issues.append("Option type mismatch: expected \(searchDirection), got \(optionDirection ?? "nil")")
            }

            // Validate underlying asset consistency
            if underlyingAsset != searchResult.underlyingAsset {
                issues.append("Underlying asset mismatch: expected \(searchResult.underlyingAsset ?? "nil"), got \(underlyingAsset ?? "nil")")
            }

            // Check for suspicious defaults
            if underlyingAsset == "DAX" && searchResult.underlyingAsset != "DAX" {
                issues.append("Suspicious DAX default in underlying asset")
            }
        }

        if issues.isEmpty {
            return .valid
        } else {
            let message = "Order creation validation failed\(context.isEmpty ? "" : " in \(context)"): \(issues.joined(separator: ", "))"
            return issues.contains { $0.contains("Suspicious") } ? .warning(message) : .error(message)
        }
    }

    // MARK: - Debug Logging

    static func logDataFlow(
        step: String,
        searchResult: SearchResult? = nil,
        optionDirection: String? = nil,
        underlyingAsset: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("🔄 DATA FLOW [\(fileName):\(line)] \(step)")

        if let result = searchResult {
            print("   📊 SearchResult: direction=\(result.direction ?? "nil"), category=\(result.category ?? "nil"), underlyingType=\(result.underlyingType ?? "nil"), underlyingAsset=\(result.underlyingAsset ?? "nil"), wkn=\(result.wkn)")
        }

        if let optionDirection = optionDirection {
            print("   🎯 OptionType: \(optionDirection)")
        }

        if let underlyingAsset = underlyingAsset {
            print("   🏢 UnderlyingAsset: \(underlyingAsset)")
        }
    }

    // MARK: - Integration Test Helpers

    static func testBasiswertFlow(
        selectedBasiswert: String,
        expectedUnderlyingAsset: String
    ) -> ValidationResult {
        // This would be used in integration tests
        // For now, just return a placeholder
        return .valid
    }
}

// MARK: - Validation Extensions

extension SearchResult {
    func validate(context: String = "") -> DataFlowValidator.ValidationResult {
        return DataFlowValidator.validateSearchResult(self, context: context)
    }
}
