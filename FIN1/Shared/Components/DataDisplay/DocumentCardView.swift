import SwiftUI

// MARK: - Document Card View
/// Card view for displaying document items in notification lists

struct DocumentCardView: View {
    let document: Document
    @Environment(\.appServices) private var appServices
    @State private var showDocumentDetail = false

    var body: some View {
        self.cardContent
            .sheet(isPresented: self.$showDocumentDetail) {
                self.documentDetailView
            }
    }

    @ViewBuilder
    private var documentDetailView: some View {
        DocumentNavigationHelper.sheetView(for: self.document, appServices: self.appServices)
    }

    private var cardContent: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Tappable Icon
                Button(action: {
                    self.showDocumentDetail = true
                    self.appServices.documentService.markDocumentAsRead(self.document)
                }) {
                    Image(systemName: self.document.icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(self.document.type.color)
                        .frame(width: 40, height: 40)
                        .background(self.document.type.color.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(self.document.title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        // Unread indicator
                        if self.document.readAt == nil {
                            Circle()
                                .fill(AppTheme.accentLightBlue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(self.document.description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(self.document.timestamp, style: .date)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                            .textCase(.uppercase)

                        Spacer()

                        Text("\(self.document.fileSize) • \(self.document.fileFormat)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }

                    // Expiry warning
                    self.expiryWarningView
                }

                Spacer()
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .opacity(self.document.readAt != nil ? 0.7 : 1.0)
    }

    @ViewBuilder
    private var expiryWarningView: some View {
        if let expiryDate = document.expiresAt {
            let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
            if daysUntilExpiry <= 7 && daysUntilExpiry > 0 {
                self.expiryBadge(
                    icon: "exclamationmark.triangle.fill",
                    text: "Expires in \(daysUntilExpiry) day\(daysUntilExpiry == 1 ? "" : "s")",
                    color: AppTheme.accentOrange
                )
            } else if daysUntilExpiry <= 0 {
                self.expiryBadge(
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

