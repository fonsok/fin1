import SwiftUI

// MARK: - Document Card View
/// Card view for displaying document items in notification lists

struct DocumentCardView: View {
    let document: Document
    @Environment(\.appServices) private var appServices
    @State private var showDocumentDetail = false

    var body: some View {
        cardContent
            .sheet(isPresented: $showDocumentDetail) {
                documentDetailView
            }
    }

    @ViewBuilder
    private var documentDetailView: some View {
        DocumentNavigationHelper.sheetView(for: document, appServices: appServices)
    }

    private var cardContent: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Tappable Icon
                Button(action: {
                    showDocumentDetail = true
                    appServices.documentService.markDocumentAsRead(document)
                }) {
                    Image(systemName: document.icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(document.type.color)
                        .frame(width: 40, height: 40)
                        .background(document.type.color.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(document.title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        // Unread indicator
                        if document.readAt == nil {
                            Circle()
                                .fill(AppTheme.accentLightBlue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(document.description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(document.timestamp, style: .date)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                            .textCase(.uppercase)

                        Spacer()

                        Text("\(document.fileSize) • \(document.fileFormat)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }

                    // Expiry warning
                    expiryWarningView
                }

                Spacer()
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .opacity(document.readAt != nil ? 0.7 : 1.0)
    }

    @ViewBuilder
    private var expiryWarningView: some View {
        if let expiryDate = document.expiresAt {
            let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
            if daysUntilExpiry <= 7 && daysUntilExpiry > 0 {
                expiryBadge(
                    icon: "exclamationmark.triangle.fill",
                    text: "Expires in \(daysUntilExpiry) day\(daysUntilExpiry == 1 ? "" : "s")",
                    color: AppTheme.accentOrange
                )
            } else if daysUntilExpiry <= 0 {
                expiryBadge(
                    icon: "xmark.circle.fill",
                    text: "Expired",
                    color: AppTheme.accentRed
                )
            }
        }
    }

    private func expiryBadge(icon: String, text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(color)

            Text(text)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(color)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .background(color.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }
}

