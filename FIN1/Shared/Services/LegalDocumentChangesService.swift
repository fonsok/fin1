import Foundation

// MARK: - Legal Document Changes Service

/// Service for comparing legal document versions and identifying changes
/// Used to show users what has changed when new versions are available
final class LegalDocumentChangesService {

    // MARK: - Change Types

    /// Represents a change between two document versions
    struct DocumentChange: Identifiable, Hashable {
        let id = UUID()
        let changeType: ChangeType
        let sectionTitle: String
        let description: String

        enum ChangeType: String, CaseIterable {
            case added = "added"
            case modified = "modified"
            case removed = "removed"

            var icon: String {
                switch self {
                case .added: return "plus.circle.fill"
                case .modified: return "pencil.circle.fill"
                case .removed: return "minus.circle.fill"
                }
            }

            var localizedLabel: String {
                switch self {
                case .added: return NSLocalizedString("Neu hinzugefügt", comment: "Added change type")
                case .modified: return NSLocalizedString("Geändert", comment: "Modified change type")
                case .removed: return NSLocalizedString("Entfernt", comment: "Removed change type")
                }
            }

            var localizedLabelEN: String {
                switch self {
                case .added: return "Added"
                case .modified: return "Modified"
                case .removed: return "Removed"
                }
            }
        }
    }

    /// Summary of changes between document versions
    struct ChangesSummary: Identifiable {
        let id = UUID()
        let documentType: LegalDocumentType
        let oldVersion: String
        let newVersion: String
        let oldEffectiveDate: Date?
        let newEffectiveDate: Date?
        let changes: [DocumentChange]
        let hasSignificantChanges: Bool

        var changeCount: Int { changes.count }

        var localizedSummary: String {
            let count = changes.count
            if count == 0 {
                return NSLocalizedString("Keine wesentlichen Änderungen", comment: "No changes")
            } else if count == 1 {
                return NSLocalizedString("1 Änderung", comment: "One change")
            } else {
                return String(format: NSLocalizedString("%d Änderungen", comment: "Multiple changes"), count)
            }
        }

        var localizedSummaryEN: String {
            let count = changes.count
            if count == 0 {
                return "No significant changes"
            } else if count == 1 {
                return "1 change"
            } else {
                return "\(count) changes"
            }
        }
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Change Detection

    /// Compares two versions of a legal document and returns detected changes
    /// - Parameters:
    ///   - oldContent: The previously accepted version (can be nil for first acceptance)
    ///   - newContent: The new version to be accepted
    /// - Returns: A summary of changes between versions
    func compareVersions(
        oldContent: TermsContent?,
        newContent: TermsContent
    ) -> ChangesSummary {
        var changes: [DocumentChange] = []

        guard let oldContent else {
            // First time acceptance - no comparison possible
            return ChangesSummary(
                documentType: LegalDocumentType(rawValue: newContent.documentType) ?? .terms,
                oldVersion: "–",
                newVersion: newContent.version,
                oldEffectiveDate: nil,
                newEffectiveDate: parseEffectiveDate(newContent.effectiveDate),
                changes: [],
                hasSignificantChanges: false
            )
        }

        let oldSections = oldContent.sections
        let newSections = newContent.sections

        // Create dictionaries for efficient lookup
        let oldSectionsById = Dictionary(uniqueKeysWithValues: oldSections.map { ($0.id, $0) })
        let newSectionsById = Dictionary(uniqueKeysWithValues: newSections.map { ($0.id, $0) })

        // Find added sections
        for section in newSections {
            if oldSectionsById[section.id] == nil {
                changes.append(DocumentChange(
                    changeType: .added,
                    sectionTitle: section.title,
                    description: summarizeContent(section.content, maxLength: 100)
                ))
            }
        }

        // Find removed sections
        for section in oldSections {
            if newSectionsById[section.id] == nil {
                changes.append(DocumentChange(
                    changeType: .removed,
                    sectionTitle: section.title,
                    description: summarizeContent(section.content, maxLength: 100)
                ))
            }
        }

        // Find modified sections
        for newSection in newSections {
            if let oldSection = oldSectionsById[newSection.id] {
                if hasSignificantChanges(old: oldSection, new: newSection) {
                    changes.append(DocumentChange(
                        changeType: .modified,
                        sectionTitle: newSection.title,
                        description: describeModification(old: oldSection, new: newSection)
                    ))
                }
            }
        }

        let hasSignificant = !changes.isEmpty || oldContent.version != newContent.version

        return ChangesSummary(
            documentType: LegalDocumentType(rawValue: newContent.documentType) ?? .terms,
            oldVersion: oldContent.version,
            newVersion: newContent.version,
            oldEffectiveDate: parseEffectiveDate(oldContent.effectiveDate),
            newEffectiveDate: parseEffectiveDate(newContent.effectiveDate),
            changes: changes,
            hasSignificantChanges: hasSignificant
        )
    }

    // MARK: - Helper Methods

    private func parseEffectiveDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    private func summarizeContent(_ content: String, maxLength: Int) -> String {
        let cleaned = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= maxLength {
            return cleaned
        }

        let truncated = String(cleaned.prefix(maxLength))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "…"
        }
        return truncated + "…"
    }

    private func hasSignificantChanges(old: TermsContentSection, new: TermsContentSection) -> Bool {
        // Compare content after normalizing whitespace
        let oldNormalized = normalizeForComparison(old.content)
        let newNormalized = normalizeForComparison(new.content)

        // Title change counts as significant
        if old.title != new.title {
            return true
        }

        // Calculate similarity - if less than 95% similar, consider it changed
        let similarity = calculateSimilarity(oldNormalized, newNormalized)
        return similarity < 0.95
    }

    private func normalizeForComparison(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }

        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1

        let longerLength = Double(longer.count)
        if longerLength == 0 { return 1.0 }

        // Simple character-based similarity (Levenshtein would be more accurate but slower)
        let commonPrefix = longer.commonPrefix(with: shorter).count
        let commonSuffix = String(longer.reversed()).commonPrefix(with: String(shorter.reversed())).count

        return Double(commonPrefix + commonSuffix) / (longerLength * 2)
    }

    private func describeModification(old: TermsContentSection, new: TermsContentSection) -> String {
        let oldWords = Set(old.content.split(separator: " ").map { String($0).lowercased() })
        let newWords = Set(new.content.split(separator: " ").map { String($0).lowercased() })

        let addedWords = newWords.subtracting(oldWords).count
        let removedWords = oldWords.subtracting(newWords).count

        if addedWords > 0 && removedWords > 0 {
            return NSLocalizedString("Text wurde überarbeitet", comment: "Content revised")
        } else if addedWords > removedWords {
            return NSLocalizedString("Inhalt wurde erweitert", comment: "Content expanded")
        } else if removedWords > addedWords {
            return NSLocalizedString("Inhalt wurde gekürzt", comment: "Content shortened")
        } else {
            return NSLocalizedString("Formulierungen wurden angepasst", comment: "Wording adjusted")
        }
    }
}

// MARK: - User Defaults Extension for Storing Previous Accepted Content

extension LegalDocumentChangesService {

    private static let previousTermsKey = "FIN1.previous_accepted_terms"
    private static let previousPrivacyKey = "FIN1.previous_accepted_privacy"

    /// Stores the accepted content for future comparison
    func storeAcceptedContent(_ content: TermsContent, userDefaults: UserDefaults = .standard) {
        let key: String
        switch LegalDocumentType(rawValue: content.documentType) {
        case .terms:
            key = Self.previousTermsKey
        case .privacy:
            key = Self.previousPrivacyKey
        default:
            return
        }

        if let data = try? JSONEncoder().encode(content) {
            userDefaults.set(data, forKey: key)
        }
    }

    /// Retrieves the previously accepted content for comparison
    func getPreviouslyAcceptedContent(
        documentType: LegalDocumentType,
        userDefaults: UserDefaults = .standard
    ) -> TermsContent? {
        let key: String
        switch documentType {
        case .terms:
            key = Self.previousTermsKey
        case .privacy:
            key = Self.previousPrivacyKey
        default:
            return nil
        }

        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TermsContent.self, from: data)
    }
}
