import SwiftUI

/// Displays the current KYB review status to company users after submission.
struct CompanyKybStatusView: View {
    let status: CompanyKybReviewStatus
    let onDismiss: (() -> Void)?
    var onResubmit: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(32)) {
                    Spacer()
                    self.statusIcon
                    self.statusTitle
                    self.statusDescription
                    Spacer()
                    self.actionButton
                }
                .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
                .padding(.bottom, ResponsiveDesign.spacing(24))
            }
            .navigationTitle("KYB-Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews

    private var statusIcon: some View {
        Image(systemName: self.status.iconName)
            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(64)))
            .foregroundColor(self.status.iconColor)
            .accessibilityHidden(true)
    }

    private var statusTitle: some View {
        Text(self.status.title)
            .font(ResponsiveDesign.largeTitleFont())
            .foregroundColor(AppTheme.fontColor)
            .multilineTextAlignment(.center)
    }

    private var statusDescription: some View {
        Text(self.status.description)
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, ResponsiveDesign.spacing(16))
    }

    private var actionButton: some View {
        Button(action: {
            if self.status == .moreInfoRequested, let onResubmit {
                onResubmit()
            } else {
                self.onDismiss?()
                self.dismiss()
            }
        }) {
            Text(self.status.buttonLabel)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(AppTheme.accentLightBlue)
                .cornerRadius(ResponsiveDesign.spacing(12))
        }
    }
}

// MARK: - Review Status

enum CompanyKybReviewStatus: Equatable {
    case pendingReview
    case approved
    case rejected
    case moreInfoRequested

    init?(from statusString: String?) {
        switch statusString {
        case "pending_review": self = .pendingReview
        case "approved": self = .approved
        case "rejected": self = .rejected
        case "more_info_requested": self = .moreInfoRequested
        default: return nil
        }
    }

    var iconName: String {
        switch self {
        case .pendingReview: return "clock.badge.checkmark"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        case .moreInfoRequested: return "exclamationmark.triangle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .pendingReview: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .moreInfoRequested: return .orange
        }
    }

    var title: String {
        switch self {
        case .pendingReview: return "Ihre Unterlagen werden geprüft"
        case .approved: return "KYB genehmigt"
        case .rejected: return "KYB abgelehnt"
        case .moreInfoRequested: return "Zusätzliche Informationen benötigt"
        }
    }

    var description: String {
        switch self {
        case .pendingReview:
            return "Ihre Unternehmensunterlagen wurden eingereicht und werden nun geprüft. Dieser Vorgang kann einige Werktage dauern. Sie erhalten eine Benachrichtigung, sobald die Prüfung abgeschlossen ist."
        case .approved:
            return "Die Identitätsprüfung Ihres Unternehmens wurde erfolgreich abgeschlossen. Ihr Firmenkonto ist nun freigeschaltet."
        case .rejected:
            return "Die Identitätsprüfung Ihres Unternehmens konnte nicht abgeschlossen werden. Bitte prüfen Sie die Hinweise in Ihren Benachrichtigungen oder kontaktieren Sie den Support."
        case .moreInfoRequested:
            return "Bei der Prüfung Ihrer Unternehmensunterlagen wurden Rückfragen festgestellt. Bitte überarbeiten Sie die fehlenden oder fehlerhaften Angaben und reichen Sie den KYB-Vorgang erneut ein."
        }
    }

    var buttonLabel: String {
        switch self {
        case .pendingReview: return "Verstanden"
        case .approved: return "Zum Dashboard"
        case .rejected: return "Support kontaktieren"
        case .moreInfoRequested: return "KYB überarbeiten"
        }
    }
}

// MARK: - Preview

#Preview("Pending Review") {
    CompanyKybStatusView(status: .pendingReview, onDismiss: nil)
}

#Preview("Approved") {
    CompanyKybStatusView(status: .approved, onDismiss: nil)
}

#Preview("Rejected") {
    CompanyKybStatusView(status: .rejected, onDismiss: nil)
}

#Preview("More Info Requested") {
    CompanyKybStatusView(status: .moreInfoRequested, onDismiss: nil, onResubmit: {})
}
