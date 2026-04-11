import SwiftUI

// Extension to make Int Identifiable for sheet presentation
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Unified Item Card
struct UnifiedItemCard: View {
    let item: NotificationItem
    let notificationService: any NotificationServiceProtocol
    @Environment(\.appServices) private var appServices

    var body: some View {
        switch item {
        case .notification(let notification):
            NotificationCardView(
                notification: notification,
                notificationService: notificationService,
                userId: appServices.userService.currentUser?.id ?? "",
                customerSupportService: appServices.customerSupportService,
                satisfactionSurveyService: appServices.satisfactionSurveyService
            )
        case .document(let document):
            DocumentCardView(document: document)
        }
    }
}

// MARK: - Notification Card View
struct NotificationCardView: View {
    let notification: AppNotification
    let notificationService: any NotificationServiceProtocol
    let userId: String
    let customerSupportService: any CustomerSupportServiceProtocol
    let satisfactionSurveyService: any SatisfactionSurveyServiceProtocol

    @StateObject private var viewModel: NotificationCardViewModel

    init(
        notification: AppNotification,
        notificationService: any NotificationServiceProtocol,
        userId: String,
        customerSupportService: any CustomerSupportServiceProtocol,
        satisfactionSurveyService: any SatisfactionSurveyServiceProtocol
    ) {
        self.notification = notification
        self.notificationService = notificationService
        self.userId = userId
        self.customerSupportService = customerSupportService
        self.satisfactionSurveyService = satisfactionSurveyService
        _viewModel = StateObject(
            wrappedValue: NotificationCardViewModel(
                notification: notification,
                notificationService: notificationService,
                customerSupportService: customerSupportService,
                satisfactionSurveyService: satisfactionSurveyService
            )
        )
    }

    var body: some View {
        Button(action: {
            Task { await viewModel.handlePrimaryTap() }
        }) {
            ZStack {
                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    // Icon
                    Image(systemName: notification.type.icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(notificationColor)
                        .frame(width: 40, height: 40)
                        .background(notificationColor.opacity(0.1))
                        .clipShape(Circle())

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(notification.title)
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.fontColor)

                            Spacer()

                            // Unread indicator
                            if notification.isRead {
                                Circle()
                                    .fill(AppTheme.accentLightBlue)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Text(notification.message)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack {
                            Text(notification.createdAt, style: .date)
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                                .textCase(.uppercase)

                            Spacer()

                            if notification.priority == .high || notification.priority == .urgent {
                                Text("Tap to view")
                                    .font(ResponsiveDesign.captionFont())
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.accentLightBlue)
                                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                                    .padding(.vertical, ResponsiveDesign.spacing(4))
                                    .background(AppTheme.accentLightBlue.opacity(0.1))
                                    .cornerRadius(ResponsiveDesign.spacing(6))
                            }
                        }
                    }
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .opacity(notification.isRead ? 0.7 : 1.0)

                // Loading overlay
                if viewModel.isLoadingTicket {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.sectionBackground.opacity(0.8))
                        .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isLoadingTicket)
        .sheet(isPresented: $viewModel.showTicketDetail) {
            if let ticket = viewModel.ticket {
                UserTicketDetailView(
                    ticket: ticket,
                    userId: userId,
                    supportService: customerSupportService
                )
            }
        }
        .sheet(isPresented: $viewModel.showSurvey) {
            if let request = viewModel.surveyRequest {
                SatisfactionSurveyView(
                    surveyRequest: request,
                    onSubmit: { rating, issueResolved, agentHelpful, responseTimeSatisfactory, comment in
                        await viewModel.submitSurvey(
                            requestId: request.id,
                            rating: rating,
                            issueResolved: issueResolved,
                            agentHelpful: agentHelpful,
                            responseTimeSatisfactory: responseTimeSatisfactory,
                            comment: comment
                        )
                    },
                    onDismiss: { viewModel.dismissSurvey() }
                )
            }
        }
        .alert("Fehler", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var notificationColor: Color {
        switch notification.type {
        case .investment:
            return AppTheme.accentGreen
        case .trader:
            return AppTheme.accentLightBlue
        case .system:
            return AppTheme.accentOrange
        case .document:
            return AppTheme.accentOrange
        case .security:
            return AppTheme.accentRed
        case .marketing:
            return AppTheme.accentLightBlue
        }
    }
}

// MARK: - Document Card View
// Extracted to DocumentCardView.swift for file size compliance
