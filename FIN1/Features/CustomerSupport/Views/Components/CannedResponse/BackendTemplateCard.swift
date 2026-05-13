import SwiftUI

/// Card for a backend response template (expandable preview, placeholders).
struct BackendTemplateCard: View {
    let template: ResponseTemplate
    let placeholderValues: [String: String]
    let onSelect: () -> Void

    @State private var isExpanded = false

    private func fillPlaceholders(in text: String) -> String {
        var result = text
        for (key, value) in self.placeholderValues {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
            result = result.replacingOccurrences(of: "{{\(key.uppercased())}}", with: value)
        }
        return result
    }

    private var previewContent: String {
        let filled = self.fillPlaceholders(in: self.template.body)
        if filled.count > 100 {
            return String(filled.prefix(100)) + "..."
        }
        return filled
    }

    var body: some View {
        Button(action: self.onSelect) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: self.template.category.icon)
                        .foregroundColor(AppTheme.accentLightBlue)
                        .font(ResponsiveDesign.captionFont())

                    Text(self.template.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()

                    if self.template.isEmail {
                        Label("E-Mail", systemImage: "envelope.fill")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white)
                            .padding(.horizontal, ResponsiveDesign.spacing(6))
                            .padding(.vertical, ResponsiveDesign.spacing(2))
                            .background(AppTheme.accentLightBlue)
                            .cornerRadius(ResponsiveDesign.spacing(4))
                    }

                    Image(systemName: "cloud.fill")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.4))
                }

                Text(self.isExpanded ? self.fillPlaceholders(in: self.template.body) : self.previewContent)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .lineLimit(self.isExpanded ? nil : 3)
                    .multilineTextAlignment(.leading)

                if !self.template.placeholders.isEmpty {
                    let missingPlaceholders = self.template.placeholders.filter { placeholder in
                        let key = placeholder.replacingOccurrences(of: "{{", with: "")
                            .replacingOccurrences(of: "}}", with: "")
                        return self.placeholderValues[key] == nil && self.placeholderValues[key.lowercased()] == nil
                    }
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
                            self.isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text(self.isExpanded ? "Weniger" : "Mehr anzeigen")
                                .font(ResponsiveDesign.captionFont())
                            Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
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
