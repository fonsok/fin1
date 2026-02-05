import SwiftUI

/// Shared component for formatting legal document content (Privacy Policy, Terms of Service)
/// Handles markdown-style formatting: **bold**, - bullets, and paragraphs consistently
/// Uses FAQ styling for consistency across all legal/help documents
struct LegalDocumentFormatter: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            ForEach(Array(formattedLines.enumerated()), id: \.element.id) { index, line in
                lineView(for: line, isFirst: index == 0)
            }
        }
    }

    @ViewBuilder
    private func lineView(for line: FormattedLine, isFirst: Bool) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            if line.isBoldHeading && !isFirst {
                Spacer().frame(height: ResponsiveDesign.spacing(8))
            }

            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(4)) {
                leadingSpace(for: line)
                lineText(for: line)
            }
        }
    }

    @ViewBuilder
    private func leadingSpace(for line: FormattedLine) -> some View {
        if line.isBulletPoint {
            Text("-")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.9))
                .padding(.top, 2)
                .frame(width: ResponsiveDesign.spacing(12))
        } else if line.isContinuation {
            Spacer().frame(width: ResponsiveDesign.spacing(16))
        } else {
            Spacer().frame(width: 0)
        }
    }

    private func lineText(for line: FormattedLine) -> some View {
        Text(line.text)
            .expandableContentTextStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Line Parsing

    private struct FormattedLine: Identifiable {
        let id = UUID()
        let text: String
        let isBulletPoint: Bool
        let isContinuation: Bool

        var isBoldHeading: Bool {
            text.hasPrefix("**") && text.hasSuffix("**") && !text.contains("-")
        }
    }

    private var formattedLines: [FormattedLine] {
        var result: [FormattedLine] = []
        var previousWasBullet = false

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                previousWasBullet = false
                continue
            }

            if trimmed.hasPrefix("- ") {
                previousWasBullet = true
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                result.append(FormattedLine(text: content, isBulletPoint: true, isContinuation: false))
            } else if trimmed.hasPrefix("**- ") {
                previousWasBullet = true
                let content = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                result.append(FormattedLine(text: content, isBulletPoint: true, isContinuation: false))
            } else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && !trimmed.contains("-") {
                previousWasBullet = false
                result.append(FormattedLine(text: trimmed, isBulletPoint: false, isContinuation: false))
            } else if previousWasBullet {
                result.append(FormattedLine(text: trimmed, isBulletPoint: false, isContinuation: true))
            } else {
                previousWasBullet = false
                result.append(FormattedLine(text: trimmed, isBulletPoint: false, isContinuation: false))
            }
        }
        return result
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LegalDocumentFormatter(
        text: """
        **Introduction:**
        This is a sample legal document with formatting.

        - First bullet point
        - Second bullet point
        - Third bullet point

        **Another Section:**
        More content here with regular paragraphs.
        """
    )
    .padding()
    .background(AppTheme.screenBackground)
}
#endif

