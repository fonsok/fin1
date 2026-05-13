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
        switch self.item {
        case .notification(let notification):
            NotificationCardView(
                notification: notification,
                notificationService: self.notificationService,
                userId: self.appServices.userService.currentUser?.id ?? "",
                customerSupportService: self.appServices.customerSupportService,
                satisfactionSurveyService: self.appServices.satisfactionSurveyService,
                documentService: self.appServices.documentService
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

    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: NotificationCardViewModel

    init(
        notification: AppNotification,
        notificationService: any NotificationServiceProtocol,
        userId: String,
        customerSupportService: any CustomerSupportServiceProtocol,
        satisfactionSurveyService: any SatisfactionSurveyServiceProtocol,
        documentService: any DocumentServiceProtocol
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
                satisfactionSurveyService: satisfactionSurveyService,
                documentService: documentService
            )
        )
    }

    var body: some View {
        Button(action: {
            Task { await self.viewModel.handlePrimaryTap() }
        }) {
            ZStack {
                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    // Icon
                    Image(systemName: self.notification.type.icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(self.notificationColor)
                        .frame(width: 40, height: 40)
                        .background(self.notificationColor.opacity(0.1))
                        .clipShape(Circle())

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(self.notification.title)
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.fontColor)

                            Spacer()

                            // Unread indicator
                            if self.notification.isRead {
                                Circle()
                                    .fill(AppTheme.accentLightBlue)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Text(self.notification.message)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack {
                            Text(self.notification.createdAt, style: .date)
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                                .textCase(.uppercase)

                            Spacer()

                            if self.notification.priority == .high || self.notification.priority == .urgent {
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
                .opacity(self.notification.isRead ? 0.7 : 1.0)

                // Loading overlay
                if self.viewModel.isLoadingTicket {
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
        .disabled(self.viewModel.isLoadingTicket)
        .sheet(isPresented: self.$viewModel.showTicketDetail) {
            if let ticket = viewModel.ticket {
                UserTicketDetailView(
                    ticket: ticket,
                    userId: self.userId,
                    supportService: self.customerSupportService
                )
            }
        }
        .sheet(isPresented: self.$viewModel.showSurvey) {
            if let request = viewModel.surveyRequest {
                SatisfactionSurveyView(
                    surveyRequest: request,
                    onSubmit: { rating, issueResolved, agentHelpful, responseTimeSatisfactory, comment in
                        await self.viewModel.submitSurvey(
                            requestId: request.id,
                            rating: rating,
                            issueResolved: issueResolved,
                            agentHelpful: agentHelpful,
                            responseTimeSatisfactory: responseTimeSatisfactory,
                            comment: comment
                        )
                    },
                    onDismiss: { self.viewModel.dismissSurvey() }
                )
            }
        }
        .sheet(item: self.$viewModel.sheetDocument) { document in
            DocumentNavigationHelper.sheetView(for: document, appServices: self.appServices)
        }
        .alert("Fehler", isPresented: self.$viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(self.viewModel.errorMessage)
        }
    }

    private var notificationColor: Color {
        switch self.notification.type {
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
