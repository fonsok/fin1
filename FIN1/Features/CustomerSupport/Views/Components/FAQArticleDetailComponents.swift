import SwiftUI

// MARK: - FAQ Article Detail Supporting Components
/// Supporting views for FAQ article detail display

// MARK: - Content Block

struct ContentBlock: Hashable {
    enum BlockType {
        case heading
        case paragraph
        case listItem
        case numberedItem
    }

    let type: BlockType
    let text: String
    var prefix: String?
}

// MARK: - Metadata Row

struct FAQMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                .frame(width: ResponsiveDesign.spacing(100), alignment: .leading)

            Text(value)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor)
                .lineLimit(2)

            Spacer()
        }
    }
}

// MARK: - Action Button

struct FAQActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.headlineFont())

                Text(title)
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .background(color.opacity(0.15))
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

