import SwiftUI

/// Card for a single local canned response (expandable preview, placeholders).
struct CannedResponseCard: View {
    let response: CannedResponse
    let placeholderValues: [String: String]
    let onSelect: () -> Void

    @State private var isExpanded = false

    private var previewContent: String {
        let filled = response.fillPlaceholders(placeholderValues)
        if filled.count > 100 {
            return String(filled.prefix(100)) + "..."
        }
        return filled
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: response.category.icon)
                        .foregroundColor(AppTheme.accentLightBlue)
                        .font(ResponsiveDesign.captionFont())

                    Text(response.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()

                    if let shortcut = response.shortcut {
                        Text(shortcut)
                            .font(ResponsiveDesign.monospacedFont(size: 11, weight: .regular))
                            .foregroundColor(AppTheme.accentOrange)
                            .padding(.horizontal, ResponsiveDesign.spacing(6))
                            .padding(.vertical, ResponsiveDesign.spacing(2))
                            .background(AppTheme.accentOrange.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(4))
                    }
                }

                Text(isExpanded ? response.fillPlaceholders(placeholderValues) : previewContent)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .lineLimit(isExpanded ? nil : 3)
                    .multilineTextAlignment(.leading)

                if !response.placeholders.isEmpty {
                    let missingPlaceholders = response.placeholders.filter { placeholderValues[$0] == nil }
                    if !missingPlaceholders.isEmpty {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(ResponsiveDesign.captionFont())
                            Text("Platzhalter: \(missingPlaceholders.joined(separator: ", "))")
                                .font(ResponsiveDesign.captionFont())
                        }
                        .foregroundColor(AppTheme.accentOrange)
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text(isExpanded ? "Weniger" : "Mehr anzeigen")
                                .font(ResponsiveDesign.captionFont())
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(ResponsiveDesign.captionFont())
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
