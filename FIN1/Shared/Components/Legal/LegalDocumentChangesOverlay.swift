import SwiftUI

// MARK: - Legal Document Changes Overlay

/// Overlay component showing what has changed between legal document versions
/// Displays a summary card with expandable list of changes
struct LegalDocumentChangesOverlay: View {
    let changesSummary: LegalDocumentChangesService.ChangesSummary
    let isEnglish: Bool
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            headerSection
            versionComparisonSection

            if !changesSummary.changes.isEmpty {
                changesListSection
            } else {
                noSignificantChangesView
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(changesBackgroundColor)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(changesBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "doc.badge.clock")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentOrange)

            Text(isEnglish ? "What's Changed?" : "Was hat sich geändert?")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            Text(isEnglish ? changesSummary.localizedSummaryEN : changesSummary.localizedSummary)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .padding(.horizontal, ResponsiveDesign.spacing(8))
                .padding(.vertical, ResponsiveDesign.spacing(4))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }

    // MARK: - Version Comparison Section

    private var versionComparisonSection: some View {
        HStack(spacing: ResponsiveDesign.spacing(16)) {
            versionBadge(
                label: isEnglish ? "Previous" : "Bisher",
                version: changesSummary.oldVersion,
                date: changesSummary.oldEffectiveDate,
                isOld: true
            )

            Image(systemName: "arrow.right")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            versionBadge(
                label: isEnglish ? "New" : "Neu",
                version: changesSummary.newVersion,
                date: changesSummary.newEffectiveDate,
                isOld: false
            )

            Spacer()
        }
    }

    private func versionBadge(label: String, version: String, date: Date?, isOld: Bool) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            Text("v\(version)")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(isOld ? AppTheme.fontColor.opacity(0.7) : AppTheme.accentLightBlue)

            if let date {
                Text(dateFormatter.string(from: date))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
        }
    }

    // MARK: - Changes List Section

    private var changesListSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(isEnglish ? "View Details" : "Details anzeigen")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(changesSummary.changes) { change in
                        changeRow(change)
                    }
                }
                .padding(.top, ResponsiveDesign.spacing(4))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func changeRow(_ change: LegalDocumentChangesService.DocumentChange) -> some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
            Image(systemName: change.changeType.icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(colorForChangeType(change.changeType))
                .frame(width: ResponsiveDesign.spacing(20))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                HStack(spacing: ResponsiveDesign.spacing(6)) {
                    Text(change.sectionTitle)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(isEnglish ? change.changeType.localizedLabelEN : change.changeType.localizedLabel)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(colorForChangeType(change.changeType))
                        .padding(.horizontal, ResponsiveDesign.spacing(6))
                        .padding(.vertical, ResponsiveDesign.spacing(2))
                        .background(colorForChangeType(change.changeType).opacity(0.15))
                        .cornerRadius(ResponsiveDesign.spacing(4))
                }

                Text(change.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(ResponsiveDesign.spacing(10))
        .background(AppTheme.sectionBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - No Significant Changes View

    private var noSignificantChangesView: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accentGreen)

            Text(isEnglish
                 ? "Minor updates and clarifications only"
                 : "Nur kleinere Aktualisierungen und Klarstellungen")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
    }

    // MARK: - Styling Helpers

    private var changesBackgroundColor: Color {
        AppTheme.accentOrange.opacity(0.08)
    }

    private var changesBorderColor: Color {
        AppTheme.accentOrange.opacity(0.3)
    }

    private func colorForChangeType(_ type: LegalDocumentChangesService.DocumentChange.ChangeType) -> Color {
        switch type {
        case .added:
            return AppTheme.accentGreen
        case .modified:
            return AppTheme.accentOrange
        case .removed:
            return AppTheme.accentRed
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: isEnglish ? "en_US" : "de_DE")
        return formatter
    }
}

// MARK: - Preview

#if DEBUG
#Preview("With Changes") {
    let changes = [
        LegalDocumentChangesService.DocumentChange(
            changeType: .modified,
            sectionTitle: "Gebührenstruktur",
            description: "Kommissionsrate wurde von 10% auf 8% reduziert"
        ),
        LegalDocumentChangesService.DocumentChange(
            changeType: .added,
            sectionTitle: "Datenschutz-Updates",
            description: "Neue Abschnitte zur DSGVO-Konformität hinzugefügt"
        ),
        LegalDocumentChangesService.DocumentChange(
            changeType: .removed,
            sectionTitle: "Beta-Bedingungen",
            description: "Beta-spezifische Klauseln entfernt"
        )
    ]

    let summary = LegalDocumentChangesService.ChangesSummary(
        documentType: .terms,
        oldVersion: "1.0",
        newVersion: "2.0",
        oldEffectiveDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
        newEffectiveDate: Date(),
        changes: changes,
        hasSignificantChanges: true
    )

    return LegalDocumentChangesOverlay(changesSummary: summary, isEnglish: false)
        .padding()
        .background(AppTheme.screenBackground)
}

#Preview("No Significant Changes") {
    let summary = LegalDocumentChangesService.ChangesSummary(
        documentType: .privacy,
        oldVersion: "1.0",
        newVersion: "1.1",
        oldEffectiveDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
        newEffectiveDate: Date(),
        changes: [],
        hasSignificantChanges: false
    )

    return LegalDocumentChangesOverlay(changesSummary: summary, isEnglish: true)
        .padding()
        .background(AppTheme.screenBackground)
}
#endif
